#!/bin/bash

# ruby gems, rvm?
# then do deployment with bundler to push out the deps

# then monitoring: monit, nagios?, mumin, newrelic

echo "** Installing ruby enterprise edition **"
wget http://rubyenterpriseedition.googlecode.com/files/ruby-enterprise_1.8.7-2011.03_i386_ubuntu10.04.deb
sudo dpkg -i ruby-enterprise_1.8.7-2011.03_i386_ubuntu10.04.deb

echo "** Installing emacs for my sanity **"
sudo apt-get install -y emacs

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
echo    " ******** YOU MUST Enter the settings specified in the above instructions. "
read -p "          Press any key to continue" # TODO this prompts and is not fully automated.

sudo a2enmod rewrite
sudo /etc/init.d/apache2 restart


echo "** Install scm **"
sudo apt-get install -y git
# because we deploy from github, set up http://help.github.com/deploy-keys/

sudo mkdir -p /srv
sudo chown -R www-data:www-data /srv/
sudo chmod -R g+w /srv/

# we do not yet deploy under a different user
#echo "** Get ready for capistrano deployers **"
#sudo useradd -d /home/deployer -m deployer
#echo "   Set password for new user"
#sudo passwd deployer

#sudo usermod -g www-data deployer  #change primary group to www-data, so new files will be in that group

#mkdir -p /srv
# and need to chgroup -R www-data /srv, and need to chmod g+w -R /srv

