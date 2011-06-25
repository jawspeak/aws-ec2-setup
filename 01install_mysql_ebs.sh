#!/bin/bash

# Adopted from Cosmin/@offbytwo/offbytwo.com, and his original presentation for pycon 2011.

VOLUME=$1

if [ -z $VOLUME ]; then
    echo "You must specify the volume, like /dev/xvdb. /dev/sdf not used in newest kernal, thus xvd*"
    echo "Linux Devices: /dev/sdb through /dev/sdp"
    echo "Note: Newer linux kernels may require you to map your devices to /dev/xvdb through /dev/xvdp instead."
    echo "See http://askubuntu.com/questions/47617/how-to-attach-new-ebs-volume-to-ubuntu-machine-on-aws"
    exit 1;
fi

echo "*** Updating ***"
sudo aptitude update
sudo aptitude -y safe-upgrade

echo "*** Installing MySQL (with no root password) ***" # (we secure password in later step)
sudo DEBIAN_FRONTEND=noninteractive aptitude install -y mysql-server

echo "*** Creating XFS filesystem and moving mysql configuration ***"
sudo apt-get install -y xfsprogs
grep -q xfs /proc/filesystems || sudo modprobe xfs
sudo mkfs.xfs $VOLUME

echo "$VOLUME /vol xfs noatime 0 0" | sudo tee -a /etc/fstab
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

echo "*** Done. Mysql is now running on EBS backed volume at $VOLUME ***"