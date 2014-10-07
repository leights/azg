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
echo -e export SGE_ROOT=/var/lib/gridengine | sudo tee -a /etc/profile 
echo -e export SGE_CELL=default  | sudo tee -a /etc/profile 

echo -e export SGE_ROOT=/var/lib/gridengine | sudo tee -a /etc/bash.bachrc
echo -e export SGE_CELL=default  | sudo tee -a /etc/bash.bachrc

source /etc/profile

## Update atp-get resouce 
sudo add-apt-repository ppa:webupd8team/java -y
sudo apt-get purge openjdk*
sudo apt-get purge oracle-java7-installer*
sudo apt-get update -qq

## Install Gridengine exec package
# unattended gridengine install
# postfix is a dependency which we disable
echo "postfix postfix/main_mailer_type select No configuration" | sudo debconf-set-selections
echo "gridengine-client shared/gridenginemaster string $MASTER" | sudo debconf-set-selections
echo "gridengine-client shared/gridenginecell string default" | sudo debconf-set-selections
echo "gridengine-client shared/gridengineconfig boolean true" | sudo debconf-set-selections
echo "oracle-java7-installer shared/accepted-oracle-license-v1-1 boolean true" | sudo debconf-set-selections

sudo apt-get purge openjdk*


#sudo DEBIAN_FRONTEND=noninteractive apt-get install gridengine-client gridengine-exec -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install oracle-java7-installer gridengine-client gridengine-exec -y
sudo service postfix stop
sudo update-rc.d postfix disable
sudo /etc/init.d/gridengine-exec restart
