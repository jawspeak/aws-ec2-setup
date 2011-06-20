#!/bin/bash

# enterprise ruby, ruby gems, apache httpd, passenger, php, rvm?
# then do deployment with bundler to push out the deps

# then monitoring: monit, nagios?, mumin, newrelic

echo "** Installing ruby enterprise edition **"
wget http://rubyenterpriseedition.googlecode.com/files/ruby-enterprise_1.8.7-2011.03_i386_ubuntu10.04.deb
sudo dpkg -i ruby-enterprise_1.8.7-2011.03_i386_ubuntu10.04.deb

echo "** Installing apache **"
sudo apt-get install -y apache2

echo "** Installing php5 **"
sudo apt-get install -y php5

echo "** Installing phusian passenger, and dependencies **"
# various requirements
sudo apt-get install -y build-essential
sudo apt-get install -y libcurl4-openssl-dev
sudo apt-get install -y libssl-dev
sudo apt-get install -y zlib1g-dev
sudo apt-get install -y apache2-prefork-dev
sudo apt-get install -y libapr1-dev
sudo apt-get install -y libaprutil1-dev
sudo /usr/local/bin/passenger-install-apache2-module

