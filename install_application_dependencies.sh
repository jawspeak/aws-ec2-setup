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

echo "** Installing ruby enterprise edition **"
wget http://rubyenterpriseedition.googlecode.com/files/ruby-enterprise_1.8.7-2011.03_i386_ubuntu10.04.deb
sudo dpkg -i ruby-enterprise_1.8.7-2011.03_i386_ubuntu10.04.deb

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
#    echo "Warning - this was written for Ubuntu 11.04 natty, but you are running something else"
#   read -p "We Cannot install Java, ec2 tools, or backups. Press any key to continue. Manually configure sun-java6-jre later"
#fi
#sudo sed -i -E "s|# (deb http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ natty multiverse)|\1|" /etc/apt/sources.list
#sudo sed -i -E "s|# (deb-src http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ natty multiverse)|\1|" /etc/apt/sources.list
#sudo sed -i -E "s|# (deb http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ natty-updates multiverse)|\1|" /etc/apt/sources.list
#sudo sed -i -E "s|# (deb-src http://us-east-1.ec2.archive.ubuntu.com/ubuntu/ natty-updates multiverse)|\1|" /etc/apt/sources.list
#sudo apt-get install -y sun-java6-jdk
#sudo apt-get install -y openjdk-6-jre-headless
#cat <<EOF | tee .ec2/set_credentials
#export
#EOF

echo "**** Install ec2 backup tool ****"
sudo add-apt-repository ppa:alestic && sudo apt-get update && sudo apt-get install -y ec2-consistent-snapshot
read -p " ***** YOU MUST copy over into $HOME/.awssecret a file containing both the Amazon AWS access key and
          secret access key on seprate lines and in that order. Press a key to understand. ****"
mkdir ~/bin
sudo mkdir -p /vol/log/backups
sudo chown ubuntu:ubuntu /vol/log/backups
cat <<EOF | tee ~/bin/backup_ebs.sh
#!/bin/sh
#set -xe
LOGFILE=/vol/log/backups/ebs-backup.log
VOLUME=\$1
DESCRIPTION="\$(date +'%Y-%m-%d_%H:%M:%S_%Z')_snapshot"
AWS_REGION="us-east-1"
echo "******* \$(date): Starting backing up volume \$VOLUME  *******" | tee -a \$LOGFILE
    #--mysql-password \$MYSQL_ROOT_PASSWORD
cmd="ec2-consistent-snapshot --debug  --mysql --mysql-host localhost --mysql-username root  --xfs-filesystem /vol --description \$DESCRIPTION --region \$AWS_REGION   \$VOLUME"
echo "will run: '\$cmd'" | tee -a \$LOGFILE
\$cmd 2>&1 | tee -a \$LOGFILE

# TODO remove old snapshots
#KEEP_RECENT_N_SNAPSHOTS=40
#echo "Deleting snapshots older than the newest \$KEEP_RECENT_N_SNAPSHOTS snapshots" | tee -a \$LOGFILE
#ec2-describe-snapshots | sort -r -k 5 | sed 1,\$KEEP_RECENT_N_SNAPSHOTSd | awk '{print "Deleting snapshot " \$2; system("ec2-delete-snapshot " \$2)}' | tee -a \$LOGFILE

echo "\$(date): Backup completed." | tee -a \$LOGFILE
EOF
chmod u+x ~/bin/backup_ebs.sh
crontab -l | grep -v backup_ebs.sh > /tmp/wip_crontab
echo "0 0 * * * /home/ubuntu/bin/backup_ebs.sh $EBS_VOLUME_ID" >> /tmp/wip_crontab
crontab /tmp/wip_crontab
rm -f /tmp/wip_crontab

# TODO
#echo " ******** Munin performance monitoring *********"
#sudo apt-get install -y munin munin-node apache2
