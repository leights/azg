#!/bin/bash
#############################
### Install SGE on Ubuntu 14
#############################

# Set hostname of master 
MASTER=$1

if [ -z "$MASTER" ]
then
	echo "Error: missing master arg"
	exit 1
fi

## Set SGE_ROOT and SGE_CELL environment variables
fsExist=$( grep "SGE_ROOT" /etc/profile )
#echo "fs is $fsExist"
if [ -z "$fsExist" ]
then

echo -e export SGE_ROOT=/var/lib/gridengine | sudo tee -a /etc/profile
echo -e export SGE_CELL=default  | sudo tee -a /etc/profile

fi

fsExist=$( grep "SGE_ROOT" /etc/bash.bashrc )
#echo "fs is $fsExist"
if [ -z "$fsExist" ]
then

echo -e export SGE_ROOT=/var/lib/gridengine | sudo tee -a /etc/bash.bashrc
echo -e export SGE_CELL=default  | sudo tee -a /etc/bash.bashrc

source /etc/profile

fi


# find what is installed

currentInstalled=$(dpkg --get-selections)
javaInstall=$(echo currentInstalled|grep oracle-java7-installer)
openJDKInstall=$(echo currentInstalled|grep openjdk)



## purge openJDK
if [ -n "$openJDKInstall" ]
then

sudo apt-get purge openjdk* -y

fi

# add source for Java
if [ -z "$javaInstall" ]
then

sudo add-apt-repository ppa:webupd8team/java -y
echo "oracle-java7-installer shared/accepted-oracle-license-v1-1 boolean true" | sudo debconf-set-selections
#sudo apt-get purge oracle-java7-installer* -y
sudo apt-get update -qq

fi

## Install Gridengine exec package
# unattended gridengine install
# postfix is a dependency which we disable
echo "postfix postfix/main_mailer_type select No configuration" | sudo debconf-set-selections
echo "gridengine-client shared/gridenginemaster string $MASTER" | sudo debconf-set-selections
echo "gridengine-client shared/gridenginecell string default" | sudo debconf-set-selections
echo "gridengine-client shared/gridengineconfig boolean true" | sudo debconf-set-selections
echo "oracle-java7-installer shared/accepted-oracle-license-v1-1 boolean true" | sudo debconf-set-selections

#sudo DEBIAN_FRONTEND=noninteractive apt-get install gridengine-client gridengine-exec -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install oracle-java7-installer gridengine-client gridengine-exec -y
sudo service postfix stop
sudo update-rc.d postfix disable
sudo /etc/init.d/gridengine-exec restart
