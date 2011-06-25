#!/bin/bash
set -e # error if any errors
if [ $# -ne 1 ]; then
    echo "Usage `basename $0` EBS_VOLUME_ID (/vol that you will backup and which stores mysql data)"
    exit 1
fi
EBS_VOLUME_ID=$1
# then monitoring: monit, nagios?, mumin, newrelic

echo "** Installing emacs for my sanity **"
sudo apt-get install -y emacs

echo "** Install scm **"
sudo apt-get install -y git
# because we deploy from github, set up http://help.github.com/deploy-keys/
read -p "******* Manual step: set up github keys so this machine can pull from github"

# apache serves out of this directory
sudo mkdir -p /srv
sudo chown -R www-data:www-data /srv/
sudo chmod -R g+w /srv/
# rails logging goes into this directory
sudo mkdir -p /vol/log/sv-lla-ecommerce
sudo chgrp -R  www-data /vol/log/sv-lla-ecommerce/
sudo chmod -R g+w /vol/log/sv-lla-ecommerce/

# we do not yet deploy under a different user
#echo "** Get ready for capistrano deployers **"
#sudo useradd -d /home/deployer -m deployer
#echo "   Set password for new user"
#sudo passwd deployer
#sudo usermod -g www-data deployer  #change primary group to www-data, so new files will be in that group

# setup logrotate for the application log files (not newrelic though)
cat <<EOF | sudo tee /etc/logrotate.d/passenger
/vol/log/sv-lla-ecommerce/*.log {
        weekly
        missingok
        rotate 30
        compress
        delaycompress
        sharedscripts
        postrotate
                touch /srv/com.landlordaccounting-rails/sv-lla-ecommerce/current/tmp/restart.txt
        endscript
}

/vol/log/backups/ebs-backup.log {
        weekly
        missingok
        rotate 30
        compress
        delaycompress
        sharedscripts
}
EOF

echo "** Installing apache **"
sudo apt-get install -y apache2

echo "** Installing php5 **"
sudo apt-get install -y php5
sudo apt-get install -y php5-mysql

echo "** Installing phusian passenger, and dependencies **"
sudo apt-get install -y build-essential
sudo apt-get install -y libcurl4-openssl-dev
sudo apt-get install -y libssl-dev
sudo apt-get install -y zlib1g-dev
sudo apt-get install -y apache2-prefork-dev
sudo apt-get install -y libapr1-dev
sudo apt-get install -y libaprutil1-dev
sudo /usr/local/bin/passenger-install-apache2-module -a
echo    " ******** YOU MUST Enter the settings specified in the above instructions. ********"
read -p "          Press any key to continue" # TODO this prompts and is not fully automated.

sudo a2enmod rewrite
sudo /etc/init.d/apache2 restart

#echo "******* Install ec2 tools ************"
#sudo apt-get install -y unzip
#wget "http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip"
#unzip ec2-api-tools.zip
#mv ec2-api-tools-1.4.3.0/lib .ec2/
#mv ec2-api-tools-1.4.3.0/bin .ec2/
#mkdir ~/.ec2
#if [  "`lsb_release -sd`" !=  'Ubuntu 11.04' ]; then
#    echo "Warning - this was written for Ubuntu 10.04 Lucid, but you are running something else"
#   read -p "We Cannot install Java, ec2 tools, or backups. Press any key to continue. Manually configure sun-java6-jre later"
#fi
#sudo sed -i -E "s|# (deb http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ natty parnter)|\1|" /etc/apt/sources.list
#sudo sed -i -E "s|# (deb-src http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ natty multiverse)|\1|" /etc/apt/sources.list
#sudo sed -i -E "s|# (deb http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ natty-updates multiverse)|\1|" /etc/apt/sources.list
#sudo sed -i -E "s|# (deb-src http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ natty-updates multiverse)|\1|" /etc/apt/sources.list
#sudo apt-get install -y sun-java6-jdk
#sudo apt-get install -y openjdk-6-jre-headless
#cat <<EOF | tee .ec2/set_credentials
#export
#EOF

# TODO
#echo " ******** Munin performance monitoring *********"
#sudo apt-get install -y munin munin-node apache2

echo "You need to create and authorize your GitHub keys to be able to deploy"