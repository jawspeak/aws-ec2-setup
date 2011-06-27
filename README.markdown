Follow these steps to get a working t1.micro ebs backed ec2 rails and php server
--------------------------------------------------------------------------------

#### Note ####
> There are some manual steps still. When you encounter a prompt from the script, follow the instructions.

### On your laptop ###
1. `wget wget https://raw.github.com/jawspeak/aws-ec2-setup/master/00user_data.sh`
1. Create a new instance based on the Ubuntu 11.04 image. This requires the aws tools (`brew install ec2-api-tools` on mac):
   `ec2-run-instances ami-06ad526f -z us-east-1a  -t t1.micro -k <keyname without path or .pem> -f 00user_data.sh`
1. Create an ebs volume for your persistant data `ec2-create-volume -s 1 -z us-east-1a`
1. Attach the volume to your instance `ec2-attach-volume vol-2b3b0000 -i  i-00001111 -d /dev/sdf` (use your new vol and instance id's)
1. Get the public dns of your instance `ec2-describe-instances`, look for something like ec2-50-19-100-100.compute-1.amazonaws.com. Use that to ssh in.
1. You may also want to add tags to the instance and volumes. Such as a Name. Easy to do in the [console](https://console.aws.amazon.com/ec2/home).

### SSH into your new instance ###
1. `ssh -i ~/.ssh/your-key.pem ubuntu@<your public dns>`
1. `bash 01install_mysql_ebs.sh /dev/xvdX` (find the ebs volume device, ex /dev/xvdb not /dev/sdf in new kernels). You can find out the volume by looking what is not already mounted by running `mount`, or `sudo dmesg | tail` and see what was connected.
1. `bash 02install_application_dependencies.sh ECB_VOLUME_ID` (ex: vol-2b3b0000, from above when you created it)
1. this will also involve adding a new key to github. http://help.github.com/mac-set-up-git/ On the ec2 machine, run `ssh-keygen -t rsa`. Then copy/paste the public key into github. Deployer keys won't work, because we deploy several projects from 1 key.
1. Record how the script changed the default mysql root password. Save it somewhere.

### Load data and deploy ###
1. Prepare however you need a database dump, copy from your local machine up. `scp -i ~/.ssh/your-key.pem ecom_datadump.sql ubuntu@<public dns>:` Then load the dump in a new database.
  `bash 03init_db.sh -D lla_ecom_production -U lla_ecom_prod` Take note of the new users' generated passwords.
1. Scp another database dump to this server, forum_datadump.sql
  `bash 03init_db.sh -D lla_forum_production -U lla_forum_prod -L forum_datadump.sql` Note these new users new passwords too.
1. If you use elastic IP, associate it with this instance. Easiest in the web admin console.
1. Run the application's capistrano deployment script to push the apache app configs out. Then `sudo a2ensite SITE`, then `sudo /etc/init.d/apache restart`.


### Future work / thoughts ###
* TODO: replace all of this with an automated chef recipe. See http://agiletesting.blogspot.com/2010/07/bootstrapping-ec2-instances-with-chef.html and elsewhere.
* I prefer taking an Ubuntu AMI and building it out in an automated fashion. However, in a dynamicly updating cloud, we have to consider the time it will take to get a new instance up. To mimize that time, creating an AMI from an automated good state has major speed benefits.
