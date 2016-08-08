FROM java:8-jdk

RUN apt-get update && apt-get install -y python git curl zip nano lib32stdc++6 lib32z1 python-software-properties software-properties-common
RUN apt-get install -y patch gawk g++ gcc make libc6-dev patch libreadline6-dev zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 autoconf libgdbm-dev libncurses5-dev automake libtool bison pkg-config libffi-dev libgmp-dev
RUN rm -rf /var/lib/apt/lists/*

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

RUN mkdir -p /var/rvm
RUN chmod -R 777 /var/rvm

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
# RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
#   && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha1sum -c -

# ENV JENKINS_UC https://updates.jenkins.io
# RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

RUN mkdir -p $JENKINS_HOME/.gnupg && chmod 777 $JENKINS_HOME/.gnupg

USER ${user}

# install rvm with ruby 1.9.3
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3 && \
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 && \
\curl -L get.rvm.io | bash -s stable --autolibs=read-fail && \
/bin/bash -l -c "export rvm_path=/var/rvm" && \
/bin/bash -l -c "cp -R /var/jenkins_home/.rvm/* /var/rvm/" && \
/bin/bash -l -c "source /var/rvm/scripts/rvm " && \
/bin/bash -l -c "/var/rvm/bin/rvm repair all" && \
/bin/bash -l -c "/var/rvm/bin/rvm reload" && \
/bin/bash -l -c "rm -rf /var/jenkins_home/.rvm" && \
/bin/bash -l -c "rvm install ruby-1.9.3-p547" && \
/bin/bash -l -c "rvm install ruby-2.2" && \
/bin/bash -l -c "rvm --default use 2.2" && \
/bin/bash -l -c "echo 'gem: --no-ri --no-rdoc' > ~/.gemrc" && \
/bin/bash -l -c "gem install bundler --no-ri --no-rdoc" 

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
ONBUILD RUN /bin/bash -l -c "source /var/rvm/scripts/rvm"
