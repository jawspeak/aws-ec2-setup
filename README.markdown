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

### SSH into your new instance ###
1. `ssh -i ~/.ssh/your-key.pem ubuntu@<your public dns>`
1. `./01install_mysql_ebs.sh /dev/xvdb` (where the ebs volume is mounted to, ex /dev/xvdb not /dev/sdf in new kernels)
1. `./02install_application_dependencies.sh ECB_VOLUME_ID` (ex: vol-2b3b0000)
1. this will also involve adding a new key to github. http://help.github.com/mac-set-up-git/ On the ec2 machine, run `ssh-keygen -t rsa`. Then copy/paste the public key into github. Deployer keys won't work, because we deploy several projects from 1 key.

### Load data and deploy ###
1. Prepare however you need a database dump, copy from your local machine up. `scp -i ~/.ssh/your-key.pem ecom_datadump.sql ubuntu@<your dns>:` Then load the dump in a new database.
  `03init_db.sh -D lla_ecom_production -U lla_ecom_prod -L ecom_datadump.sql` Take note of the generated passwords.
1. Scp another database dump to this server, forum_datadump.sql
  `03init_db.sh -D lla_forum_production -U lla_forum_prod -L forum_datadump.sql` Note these new passwords too.
1. Run the application's capistrano deployment script to push the apache app configs out. Then `sudo a2ensite SITE`, then `sudo /etc/init.d/apache restart`.
1. Secure the root mysql password. Update it for the backup script to be able to run it.


### Future work ###
* TODO: replace all of this with an automated chef recipe.
