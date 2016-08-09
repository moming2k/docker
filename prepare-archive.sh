mkdir -p ./file-archive/tmp/script/
export CURRENT_FOLDER=`pwd`

curl -L https://raw.githubusercontent.com/hgomez/devops-incubator/master/forge-tricks/batch-install-jenkins-plugins.sh -o ./file-archive/tmp/script/batch-install-jenkins-plugins.sh


/bin/bash -l -c "cd $CURRENT_FOLDER/file-archive/tmp/script/ && patch < $CURRENT_FOLDER/patch_batch-install-jenkins-plugins.txt"

curl -L https://gist.githubusercontent.com/anonymous/d133713dd3d47c953db0747078de9dbf/raw/e54bbd7d5d4b4dde5221d39351082c1ff8303634/gistfile1.txt -o ./file-archive/tmp/script/plugins.txt
chmod 777 ./file-archive/tmp/script/batch-install-jenkins-plugins.sh

mkdir -p ./file-archive/tmp/jenkins/plugins
./file-archive/tmp/script/batch-install-jenkins-plugins.sh --plugins ./file-archive/tmp/script/plugins.txt --plugindir ./file-archive/tmp/jenkins/plugins