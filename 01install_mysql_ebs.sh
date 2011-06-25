#!/bin/bash

# Adopted from Cosmin/@offbytwo/offbytwo.com, and his original presentation for pycon 2011.

EBS_VOLUME_ID=$1

if [ -z $EBS_VOLUME_ID ]; then
    echo "You must specify the volume, like /dev/xvdb. /dev/sdf not used in newest kernal, thus xvd*"
    # As per the comment in the AWS console.
    #Linux Devices: /dev/sdb through /dev/sdp
    #Note: Newer linux kernels may require you to map your devices to /dev/xvdb through /dev/xvdp instead.
    #See http://askubuntu.com/questions/47617/how-to-attach-new-ebs-volume-to-ubuntu-machine-on-aws
    exit 1;
fi

echo "*** Installing MySQL (with no root password) ***" # need to secure password in later step
sudo DEBIAN_FRONTEND=noninteractive aptitude install -y mysql-server

echo "*** Creating XFS filesystem and moving mysql configuration ***"
sudo apt-get install -y xfsprogs
grep -q xfs /proc/filesystems || sudo modprobe xfs
sudo mkfs.xfs $EBS_VOLUME_ID

echo "$EBS_VOLUME_ID /vol xfs noatime 0 0" | sudo tee -a /etc/fstab
sudo mkdir -m 000 /vol
sudo mount /vol

sudo /etc/init.d/mysql stop
sudo mkdir /vol/etc /vol/lib /vol/log
sudo mv /etc/mysql     /vol/etc/
sudo mv /var/lib/mysql /vol/lib/
sudo mv /var/log/mysql /vol/log/

sudo mkdir /etc/mysql
sudo mkdir /var/lib/mysql
sudo mkdir /var/log/mysql

echo "/vol/etc/mysql /etc/mysql     none bind" | sudo tee -a /etc/fstab
sudo mount /etc/mysql

echo "/vol/lib/mysql /var/lib/mysql none bind" | sudo tee -a /etc/fstab
sudo mount /var/lib/mysql

echo "/vol/log/mysql /var/log/mysql none bind" | sudo tee -a /etc/fstab
sudo mount /var/log/mysql

sudo /etc/init.d/mysql start


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

echo "*** Done. Mysql is now running on EBS backed volume at $EBS_VOLUME_ID ***"