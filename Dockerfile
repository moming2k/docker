FROM java:8-jdk

RUN apt-get update && apt-get install -y python git curl zip nano lib32stdc++6 lib32z1 python-software-properties software-properties-common
RUN apt-get install -y patch gawk g++ gcc make libc6-dev patch libreadline6-dev zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 autoconf libgdbm-dev libncurses5-dev automake libtool bison pkg-config libffi-dev libgmp-dev

ENV RVM_HOME /var/rvm
ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT 50000

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container, 
# ensure you use the same uid
RUN groupadd -g ${gid} ${group} \
    && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

# Jenkins home directory is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /var/jenkins_home

# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

ENV TINI_VERSION 0.9.0
ENV TINI_SHA fa23d1e20732501c3bb8eeeca423c89ac80ed452

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fsSL https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static -o /bin/tini && chmod +x /bin/tini \
  && echo "$TINI_SHA  /bin/tini" | sha1sum -c -

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.7.2}

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=4c05175677825a0c311ef3001bbb0a767dad0e8d

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=http://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum 
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
  && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha1sum -c -

ENV JENKINS_UC https://updates.jenkins.io
RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

RUN mkdir -p $JENKINS_HOME/.gnupg && chmod 777 $JENKINS_HOME/.gnupg



# install rvm with ruby 1.9.3
# RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3 && \
# gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 && \
# \curl -L get.rvm.io | bash -s -- --autolibs=read-fail && \
# /bin/bash -l -c "export rvm_path=/var/rvm" && \
# /bin/bash -l -c "cp -R /var/jenkins_home/.rvm/* /var/rvm/" && \
# /bin/bash -l -c "source /var/rvm/scripts/rvm " && \
# /bin/bash -l -c "echo 'print PATH'" && \
# /bin/bash -l -c "echo $PATH" && \
# /bin/bash -l -c "export PATH=/var/rvm/bin:$PATH" && \
# /bin/bash -l -c "PATH=/var/rvm/bin:$PATH echo $PATH" && \
# /bin/bash -l -c 'source /var/rvm/scripts/rvm' && \
# /bin/bash -l -c "echo '/var/rvm/bin/rvm repair all'" && \
# /bin/bash -l -c "/var/rvm/bin/rvm repair all" && \
# /bin/bash -l -c "echo /var/rvm/bin/rvm reload" && \
# /bin/bash -l -c "/var/rvm/bin/rvm reload" && \
# /bin/bash -l -c "rm -rf /var/jenkins_home/.rvm" && \
# /bin/bash -l -c "echo 'print PATH'" && \
# /bin/bash -l -c "echo $PATH" && \
# # /bin/bash -l -c "echo 'rvm install ruby-1.9.3-p547'" && \
# # /bin/bash -l -c "PATH=/var/rvm/bin:$PATH rvm install ruby-1.9.3-p547" && \
# /bin/bash -l -c "echo 'rvm install ruby-2.2'" && \
# /bin/bash -l -c "PATH=/var/rvm/bin:$PATH rvm install ruby-2.2" && \
# /bin/bash -l -c "echo 'rvm --default use 2.2'" && \
# /bin/bash -l -c "PATH=/var/rvm/bin:$PATH rvm --default use 2.2" && \
# /bin/bash -l -c "echo 'gem: --no-ri --no-rdoc' > ~/.gemrc" && \
# /bin/bash -l -c "PATH=/var/rvm/bin:$PATH gem install bundler --no-ri --no-rdoc" 

# create share program
RUN mkdir -p /usr/support
RUN chmod -R 777 /usr/support

# prepare rvm
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
RUN \curl -sSL https://get.rvm.io | bash -s stable --ruby=2.2
RUN /bin/bash -l -c "source /usr/local/rvm/scripts/rvm && gem install bundler --no-ri --no-rdoc" 
RUN chmod -R 777 /usr/local/rvm
# prepare rvm ( temp dislabe ) END

# prepare plugin ( temp disable )
RUN curl -L https://raw.githubusercontent.com/hgomez/devops-incubator/master/forge-tricks/batch-install-jenkins-plugins.sh -o /tmp/batch-install-jenkins-plugins.sh
RUN chmod 777 /tmp/batch-install-jenkins-plugins.sh
RUN curl -L https://gist.githubusercontent.com/anonymous/d133713dd3d47c953db0747078de9dbf/raw/e54bbd7d5d4b4dde5221d39351082c1ff8303634/gistfile1.txt -o /tmp/plugins.txt

# temp disable for jenkins support library
# RUN mkdir -p /usr/support/plugins
# RUN /tmp/batch-install-jenkins-plugins.sh --plugins /tmp/plugins.txt --plugindir /usr/support/plugins
# prepare plugin ( temp disable ) END

# prepare android sdk
# RUN mkdir -p /usr/support/plugins

ENV ANDROID_SDK_HOME /usr/support/android_sdk
ENV ANDROID_HOME /usr/support/android_sdk

# prepare android sdk 
RUN mkdir /usr/support/android_sdk
RUN cd /tmp && curl -O https://dl.google.com/android/android-sdk_r24.4.1-linux.tgz && \
cd /usr/support/android_sdk && \
tar zxvf /tmp/android-sdk_r24.4.1-linux.tgz && mv android-sdk-linux/* . && \
mkdir licenses && \
echo -e "\n8933bad161af4178b1185d1a37fbf41ea5269c55" > licenses/android-sdk-license && \
echo -e "\n84831b9409646a918e30573bab4c9c91346d8abd" > licenses/android-sdk-preview-license 
# prepare android sdk ( temp dislabe ) END
# RUN cd /tmp && curl -O http://172.16.3.222:7000/android-sdk_r24.4.1-linux.tgz && \
#  && \ tools/android update sdk --no-ui

# prepare jruby 
RUN curl -L https://s3.amazonaws.com/jruby.org/downloads/9.1.2.0/jruby-bin-9.1.2.0.tar.gz -o /tmp/jruby-bin-9.1.2.0.tar.gz && \
cd /usr/support/ && tar -zxvf /tmp/jruby-bin-9.1.2.0.tar.gz && mv jruby-9.1.2.0 jruby
# RUN curl -L http://172.16.3.222:7000/jruby-bin-9.1.2.0.tar.gz -o /tmp/jruby-bin-9.1.2.0.tar.gz && \
# prepare jruby 

# prepare aws 
RUN mkdir -p /usr/support/aws && mkdir -p /usr/support/bin 
RUN curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "/tmp/awscli-bundle.zip" 
# RUN curl "http://172.16.3.222:7000/awscli-bundle.zip" -o "/tmp/awscli-bundle.zip" 
RUN cd /tmp && unzip awscli-bundle.zip && cd awscli-bundle && ./install -i /usr/support/aws -b /usr/support/bin/aws
# prepare aws 


ENV PATH ${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools
# ------------------------------------------------------
# --- Install Android SDKs and other build packages

# Other tools and resources of Android SDK
#  you should only install the packages you need!
# To get a full list of available options you can use:
#  android list sdk --no-ui --all --extended
RUN echo y | android update sdk --no-ui --all --filter \
  platform-tools,extra-android-support

# google apis
# Please keep these in descending order!
RUN echo y | android update sdk --no-ui --all --filter \
  addon-google_apis-google-23,addon-google_apis-google-22,addon-google_apis-google-21

# SDKs
# Please keep these in descending order!
RUN echo y | android update sdk --no-ui --all --filter \
  android-N,android-23,android-22,android-21,android-20,android-19,android-17,android-16,android-15,android-10
# build tools
# Please keep these in descending order!
# RUN echo y | android update sdk --no-ui --all --filter \
  # build-tools-24.0.0-preview,build-tools-23.0.3,build-tools-23.0.2,build-tools-23.0.1,build-tools-22.0.1,build-tools-21.1.2,build-tools-20.0.0,build-tools-19.1.0,build-tools-17.0.0

# Android System Images, for emulators
# Please keep these in descending order!
# RUN echo y | android update sdk --no-ui --all --filter \
  # sys-img-armeabi-v7a-android-23,sys-img-armeabi-v7a-android-22,sys-img-armeabi-v7a-android-21,sys-img-armeabi-v7a-android-19,sys-img-armeabi-v7a-android-17,sys-img-armeabi-v7a-android-16,sys-img-armeabi-v7a-android-15

# Extras
RUN echo y | android update sdk --no-ui --all --filter \
  extra-android-m2repository,extra-google-m2repository,extra-google-google_play_services

# RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
# RUN \curl -sSL https://get.rvm.io | bash -s stable
# RUN /usr/local/rvm/bin/rvm install 2.2
# RUN /usr/local/rvm/bin/rvm alias create default 2.0.0-p247
# RUN /usr/local/rvm/bin/rvm system 2.0.0-p247

# for nano text editor use
ENV TERM xterm

# setup NTP to prevent time shift
RUN apt-get install -y ntp ntpdate

# RUN service ntp stop && \
# ntpdate -s time.nist.gov && \
# service ntp start

# RUN chmod 777 -R /usr/support/android_sdk

# clean up
RUN rm -rf /var/lib/apt/lists/*

# enable android sdk .android to writeable
RUN mkdir -p /usr/support/android_sdk/.android
RUN chmod 777 -R /usr/support/android_sdk/.android

RUN cd /usr/support/ && curl -L https://gist.githubusercontent.com/anonymous/ade536b5c445a3bccfc47988fb632a2c/raw/8f79353a022b572e95bccd85167361eff3ebab17/Gemfile -o Gemfile && \
export PATH=/usr/support/jruby/bin:$PATH && gem install bundle && bundle install 

# Install Gradle
RUN cd /usr/support && \
    curl -L https://services.gradle.org/distributions/gradle-2.14.1-bin.zip -o gradle-2.14.1-bin.zip && \
    unzip gradle-2.14.1-bin.zip

ENV GRADLE_HOME /usr/support/gradle-2.14.1

RUN chown -R ${user} /usr/support
RUN chgrp -R ${user} /usr/support

USER ${user}

ENV PATH $GRADLE_HOME/bin:/usr/support/jruby/bin:/usr/support/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# RUN curl -sSL https://rvm.io/mpapis.asc | gpg --import - && \
# gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3 && \
# gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 && \
# /bin/bash -l -c "curl -L get.rvm.io | bash -s stable --rails --autolibs=read-fail" && \
# /bin/bash -l -c "rvm autolibs disable" && \
# /bin/bash -l -c "rvm install 2.2" && \
# /bin/bash -l -c "echo 'gem: --no-ri --no-rdoc' > ~/.gemrc" && \
# /bin/bash -l -c "gem install bundler --no-ri --no-rdoc"

COPY jenkins-support /usr/local/bin/jenkins-support
COPY jenkins.sh /usr/local/bin/jenkins.sh
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh
COPY install-plugins.sh /usr/local/bin/install-plugins.sh

# make sure rvm is available in our shell when we run the container
ONBUILD ENV USER ${user}
# ONBUILD RUN /bin/bash -l -c "source /usr/local/rvm/scripts/rvm"
