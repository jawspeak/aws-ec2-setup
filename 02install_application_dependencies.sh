#!/bin/bash
set -e # die if any errors
if [ $# -ne 3 ]; then
    echo "Usage `basename $0` EBS_VOLUME_ID  EMAIL_ALERTS_ADDRESS  MUNIN_BASIC_AUTH_PASSWORD"
    echo "   EBS_VOLUME_ID              ex vol-123fff, mounted to /vol that you will backup)"
    echo "   EMAIL_ALERTS_ADDRESS       what email address do you want to get alerted with munin monitoring"
    echo "   MUNIN_BASIC_AUTH_PASSWORD  the password to protect the munin site served by apache"
    exit 1
fi
EBS_VOLUME_ID=$1
EMAIL_ALERTS_ADDRESS=$2
MUNIN_BASIC_AUTH_PASSWORD=$3

echo "** Installing emacs for my sanity **"
sudo apt-get install -y emacs

echo "** Install scm **"
sudo apt-get install -y git

# apache serves out of this directory
sudo mkdir -p /srv
sudo chown -R www-data:www-data /srv/
sudo chmod -R g+w /srv/
# rails logging goes into this directory
sudo mkdir -p /vol/log/sv-lla-ecommerce
sudo chgrp -R  www-data /vol/log/sv-lla-ecommerce/
sudo chmod -R g+w /vol/log/sv-lla-ecommerce/

echo "*** Creating a user for capistrano to deploy with ***"
sudo useradd -m -g www-data -N -s /bin/bash deployer #(no password only keys, same as ubuntu user, below)
sudo mkdir /home/deployer/.ssh
sudo cp ~/.ssh/authorized_keys /home/deployer/.ssh/
sudo chmod 700 /home/deployer/.ssh/
sudo chown -R deployer /home/deployer/.ssh/

sudo cat /etc/sudoers | grep -v 'deployer ALL' | sudo tee -a /etc/sudoers.tmp
sudo chmod 0440 /etc/sudoers.tmp
echo "deployer ALL=(ALL) NOPASSWD:/bin/ln,/etc/init.d/apache2 restart" | sudo tee -a /etc/sudoers.tmp
sudo mv /etc/sudoers.tmp /etc/sudoers

sudo su - deployer
ssh-keygen -t rsa -f .ssh/id_rsa -P ''
exit
echo "   Created a fresh ssh key in /home/deployer/.ssh/id_rsa.pub, which you need to copy/paste into github. All 1 line:"
echo "" && sudo cat /home/deployer/.ssh/id_rsa.pub && echo ""
echo "Copy/paste the above into github to add the key as authorized for you: https://github.com/account/ssh"
read -p "(I suggest doing this right now so you don't forget. Press any key to continue.)"

# and might as well prevent root login from even connecting to prevent DOS when the /root/.ssh/authorized_keys message appears
sudo sed -i -E "s|PermitRootLogin yes|PermitRootLogin no|" /etc/ssh/sshd_config
sudo /etc/init.d/ssh restart

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

echo "** Installing ruby enterprise edition, phusian passenger, and dependencies **"
wget http://rubyenterpriseedition.googlecode.com/files/ruby-enterprise_1.8.7-2011.03_i386_ubuntu10.04.deb
sudo dpkg -i ruby-enterprise_1.8.7-2011.03_i386_ubuntu10.04.deb
sudo gem install -y 'amazon-ec2'
sudo apt-get install -y build-essential
sudo apt-get install -y libcurl4-openssl-dev
sudo apt-get install -y libssl-dev
sudo apt-get install -y zlib1g-dev
sudo apt-get install -y apache2-prefork-dev
sudo apt-get install -y libapr1-dev
sudo apt-get install -y libaprutil1-dev
sudo /usr/local/bin/passenger-install-apache2-module -a
cat <<EOF | sudo tee /etc/apache2/mods-available/passenger.load
# EDIT THIS FILE after install: /etc/apache2/mods-available/passenger.load
#Edit your Apache configuration file, and add these lines (take the lines from installing, don't use the example below)
LoadModule passenger_module /usr/local/lib/ruby/gems/1.8/gems/passenger-!!your version here!!/ext/apache2/mod_passenger.so
PassengerRoot /usr/local/lib/ruby/gems/1.8/gems/passenger- !!your version here!!
PassengerRuby /usr/local/bin/ruby
# then sudo a2enmod passenger, and restart apache
EOF
echo    " ******** YOU MUST Enter the settings specified in the above instructions. ********"
echo    "          Edit /etc/apache2/mods-available/passenger.load and restart apache"
echo    "          (I use a capistrano task to load in all the apache virtual dir settings.)"
read -p "          Press any key to continue" # TODO this prompts and is not fully automated.

sudo a2enmod rewrite passenger
sudo a2dissite default
#sudo usermod -G www-data ubuntu
sudo /etc/init.d/apache2 restart

echo "*** Securing the initiol mysql root account ***"
NEW_MYSQL_ROOT_PASSWORD=`head -c 100 /dev/urandom | md5sum | awk '{print substr($1,1,15)}'`
mysql -u root mysql --execute "UPDATE mysql.user SET Password = PASSWORD(\"$NEW_MYSQL_ROOT_PASSWORD\") WHERE User = 'root'; FLUSH PRIVILEGES;"
echo "MYSQL_ROOT_PASSWORD=$NEW_MYSQL_ROOT_PASSWORD" > ~/.mysqlrootpass
chmod 400 ~/.mysqlrootpass
sudo chown root:root ~/.mysqlrootpass
read -p "Your root mysql password has been changed to $NEW_MYSQL_ROOT_PASSWORD. It is stored in ~/.mysqlrootpass"

echo "**** Install ec2 backup tool for the volume ****"
sudo add-apt-repository ppa:alestic && sudo apt-get update && sudo apt-get install -y ec2-consistent-snapshot
echo " ***** YOU MUST edit $HOME/.ec2credentials exporting of your amazon auth variables. Example:"
cat <<EOF | tee ~/.ec2credentials
export AWS_ACCESS_KEY_ID='xxx'
export AWS_SECRET_ACCESS_KEY='yyy'
EOF
read -p "Press a key to acknowledge this manual step. ****"

echo "*** Configuring backups for the ebs volume $EBS_VOLUME_ID ***"
mkdir ~/bin
sudo mkdir -p /vol/log/backups
sudo chown ubuntu:ubuntu /vol/log/backups
curl -s https://raw.github.com/jawspeak/aws-ec2-setup/master/snapshot_deleter.rb > ~/bin/snapshot_deleter.rb
cat <<EOF | tee ~/bin/backup_ebs.sh
#!/bin/sh
set -e
. /home/ubuntu/.ec2credentials
. /home/ubuntu/.mysqlrootpass
LOGFILE=/vol/log/backups/ebs-backup.log
EBS_VOLUME_ID=\$1
DESCRIPTION="\$(date +'%Y-%m-%d_%H:%M:%S_%Z')_snapshot_backup"
AWS_REGION="us-east-1"

echo "******* \$(date): Starting backing up volume \$EBS_VOLUME_ID  *******" | tee -a \$LOGFILE
cmd="ec2-consistent-snapshot --debug  --mysql --mysql-host localhost --mysql-username root  --mysql-password \$MYSQL_ROOT_PASSWORD --xfs-filesystem /vol --description \$DESCRIPTION --region \$AWS_REGION   \$EBS_VOLUME_ID"
echo "will run: '\$cmd'" | tee -a \$LOGFILE
\$cmd 2>&1 | tee -a \$LOGFILE

KEEP_RECENT_N_SNAPSHOTS=40
echo "Deleting snapshots older than the newest \$KEEP_RECENT_N_SNAPSHOTS snapshots" | tee -a \$LOGFILE
ruby /home/ubuntu/bin/snapshot_deleter.rb \$EBS_VOLUME_ID \$KEEP_RECENT_N_SNAPSHOTS | tee -a \$LOGFILE

echo "\$(date): Backup completed." | tee -a \$LOGFILE
EOF
chmod u+x ~/bin/backup_ebs.sh
crontab -l | grep -v backup_ebs.sh > /tmp/wip_crontab
echo "0 0 * * * /home/ubuntu/bin/backup_ebs.sh $EBS_VOLUME_ID" >> /tmp/wip_crontab
crontab /tmp/wip_crontab
rm -f /tmp/wip_crontab

echo " ******** Munin performance monitoring *********"
sudo apt-get install -y munin munin-node
sudo sed -i -E "s|#.*(dbdir.*/var/lib/munin)|\1|" /etc/munin/munin.conf
sudo sed -i -E "s|#.*(htmldir.*/var/cache/munin/www)|\1|" /etc/munin/munin.conf
sudo sed -i -E "s|#.*(logdir.*/var/log/munin)|\1|" /etc/munin/munin.conf
sudo sed -i -E "s|#.*(rundir.*/var/run/munin)|\1|" /etc/munin/munin.conf
sudo sed -i -E "s|#.*(tmpldir.*/etc/munin/templates)|\1|" /etc/munin/munin.conf
sudo sed -i -e "/#contact.someuser.command mail/i\\
contact.admin.command mail -s \"Munin notification\" $EMAIL_ALERTS_ADDRESS
" /etc/munin/munin.conf
sudo ln -s /usr/share/munin/plugins/mysql_* /etc/munin/plugins/
sudo ln -s /usr/share/munin/plugins/netstat /etc/munin/plugins/
sudo /etc/init.d/munin-node restart
sudo htpasswd -c -b /etc/apache2/sites-available/munin.htpasswd-private admin $MUNIN_BASIC_AUTH_PASSWORD
cat <<EOF | tee /etc/apache2/sites-available/munin
NameVirtualHost *:8899
Listen 8899
<VirtualHost *:8899>
        DocumentRoot /var/cache/munin/www
        <Directory />
                Options FollowSymLinks
                AllowOverride None
        </Directory>
        <Directory /var/cache/munin/www>
                Options Indexes FollowSymLinks MultiViews
                AllowOverride None
                Order allow,deny
                allow from all

                AuthType Basic
                AuthName "Private"
                AuthUserFile /etc/apache2/sites-available/munin.htpasswd-private
                Require valid-user
        </Directory>

        ErrorLog \${APACHE_LOG_DIR}/munin-error.log
        CustomLog \${APACHE_LOG_DIR}/munin-access.log combined
</VirtualHost>
EOF
sudo a2ensite munin
echo "Munin is running, on port 8899, user 'admin', pass $MUNIN_BASIC_AUTH_PASSWORD. Browse to http://<ec2-public-dns>:8899"
read -p "Open up TCP 8899 from 0.0.0.0 at https://console.aws.amazon.com/ec2/home#s=SecurityGroups. Press a key to continue."

echo "--- > Remember to do what we prompted you for, see source of this script if you forget."
echo "--- > Securely save the new root mysql password. (In $HOME/.mysqlrootpass). You need to keep that file for backups to read it."
echo "Done!"
