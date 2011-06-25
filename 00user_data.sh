#!/bin/bash
set -e -x
cd /home/ubuntu
wget https://raw.github.com/jawspeak/aws-ec2-setup/master/01install_mysql_ebs.sh
wget https://raw.github.com/jawspeak/aws-ec2-setup/master/02install_application_dependencies.sh
wget https://raw.github.com/jawspeak/aws-ec2-setup/master/03init_db.sh
chown ubuntu:ubuntu 0*
