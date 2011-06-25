#!/bin/bash
set -e # error if any errors
if [ $# -ne 1 ]; then
    echo "Usage `basename $0` EBS_VOLUME_ID (ex vol-123fff mounted to /vol that you will backup)"
    exit 1
fi
EBS_VOLUME_ID=$1

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


echo "** Installing ruby enterprise edition **"
wget http://rubyenterpriseedition.googlecode.com/files/ruby-enterprise_1.8.7-2011.03_i386_ubuntu10.04.deb
sudo dpkg -i ruby-enterprise_1.8.7-2011.03_i386_ubuntu10.04.deb
sudo gem install -y 'amazon-ec2'

echo "**** Install ec2 backup tool for the volume ****"
sudo add-apt-repository ppa:alestic && sudo apt-get update && sudo apt-get install -y ec2-consistent-snapshot
read -p " ***** YOU MUST copy over into $HOME/.ec2credentials exporting of variables. Example:
          export AWS_ACCESS_KEY_ID='xxx'
          export AWS_SECRET_ACCESS_KEY='yyy'
Press a key to acknowledge this manual step. ****"
mkdir ~/bin
sudo mkdir -p /vol/log/backups
sudo chown ubuntu:ubuntu /vol/log/backups
curl https://raw.github.com/jawspeak/aws-ec2-setup/master/snapshot_deleter.rb > ~/bin/snapshot_deleter.rb
cat <<EOF | tee ~/bin/backup_ebs.sh
#!/bin/sh
#set -xe
. /home/ubuntu/.ec2credentials
LOGFILE=/vol/log/backups/ebs-backup.log
EBS_VOLUME_ID=\$1
DESCRIPTION="\$(date +'%Y-%m-%d_%H:%M:%S_%Z')_snapshot_backup"
AWS_REGION="us-east-1"
echo "******* \$(date): Starting backing up volume \$EBS_VOLUME_ID  *******" | tee -a \$LOGFILE
    #--mysql-password \$MYSQL_ROOT_PASSWORD
cmd="ec2-consistent-snapshot --debug  --mysql --mysql-host localhost --mysql-username root  --xfs-filesystem /vol --description \$DESCRIPTION --region \$AWS_REGION   \$EBS_VOLUME_ID"
echo "will run: '\$cmd'" | tee -a \$LOGFILE
\$cmd 2>&1 | tee -a \$LOGFILE

KEEP_RECENT_N_SNAPSHOTS=40
echo "Deleting snapshots older than the newest \$KEEP_RECENT_N_SNAPSHOTS snapshots" | tee -a \$LOGFILE
ruby /home/ubuntu/bin/snapshot_deleter.rb \$EBS_VOLUME_ID \$KEEP_RECENT_N_SNAPSHOTS | tee -a \$LOGFILE

# not using this because java doesn't work on t1.micro as of 2011-06-24
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

echo "--- > You need to create and authorize your GitHub keys to be able to deploy"
echo "--- > Also, don't forget to change mysql root user"