#!/bin/bash
#############################
### Install SGE on Ubuntu 14
#############################

#############################
### On master node ( sgelinux-header )
#############################

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

## Install Gridengine master,client and exec packages on master node
# unattended gridengine install
# postfix is a dependency which we disable
echo "postfix postfix/main_mailer_type select No configuration" | sudo debconf-set-selections
echo "gridengine-master shared/gridenginemaster string $(hostname)" | sudo debconf-set-selections
echo "gridengine-master shared/gridenginecell string default" | sudo debconf-set-selections
echo "gridengine-master shared/gridengineconfig boolean true" | sudo debconf-set-selections
echo "gridengine-common shared/gridenginemaster string $(hostname)" | sudo debconf-set-selections
echo "gridengine-common shared/gridenginecell string default" | sudo debconf-set-selections
echo "gridengine-common shared/gridengineconfig boolean true" | sudo debconf-set-selections
echo "gridengine-client shared/gridenginemaster string $(hostname)" | sudo debconf-set-selections
echo "gridengine-client shared/gridenginecell string default" | sudo debconf-set-selections
echo "gridengine-client shared/gridengineconfig boolean true" | sudo debconf-set-selections
echo "oracle-java7-installer shared/accepted-oracle-license-v1-1 boolean true" | sudo debconf-set-selections

sudo DEBIAN_FRONTEND=noninteractive apt-get install oracle-java7-installer gridengine-common gridengine-client gridengine-master gridengine-exec -y
#sudo DEBIAN_FRONTEND=noninteractive apt-get install gridengine-common gridengine-client gridengine-master gridengine-exec -y
sudo -u sgeadmin /usr/share/gridengine/scripts/init_cluster /var/lib/gridengine default /var/spool/gridengine/spooldb sgeadmin
sudo service gridengine-master restart
sudo service postfix stop
sudo update-rc.d postfix disable
