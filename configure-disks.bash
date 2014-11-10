#!/bin/bash

function usage
{
    echo "usage: script.bash AZURE_HEAD"
}

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo "args ar $@"
AZURE_HEAD=$1

if [ -z $AZURE_HEAD ]
then
        echo Error: AZURE_HEAD missing
        usage
        exit 1
fi

hostname=$(hostname)

echo "postfix postfix/main_mailer_type select No configuration" | sudo debconf-set-selections

if [ $hostname == "$AZURE_HEAD" ]
then
	apt-get install mdadm nfs-kernel-server -y
else
	apt-get install mdadm nfs-common -y 
fi


diskcount=0
for i in $(parted -l|grep /sd|grep unrecognised|awk -F: '{print $2}')
do
        disks="$disks $i"
        diskcount=$((diskcount + 1))
done

if [ "$diskcount" -gt "0" ] 
then
	if [ "$diskcount" -gt "1" ] 
	then

		if [ -b "/dev/md/data" ]
		then
       		 echo "/dev/md/data alread exists moving on..."
		else
			echo ""
			echo "Creating raid for $hostname"
			echo ""
			#read -p "Press [Enter] to create stripped disk out of $disks"
			mdadm --create /dev/md/data --name=data --chunk=8 --level=0 --raid-devices=$diskcount $disks
			mkfs -t ext4 /dev/md/data
			mkdir /mnt/data
			chmod -R 777 /mnt/data
			mount /dev/md/data /mnt/data
			echo "/dev/md/data/ /mnt/data   auto defaults,nobootwait,comment=cloudconfig 0       2" >> /etc/fstab
			df -h
		fi

	else
		if [ -b "/dev/md/data" ]
		then
       		 	echo "/dev/md/data alread exists moving on..."
		else
			echo ""
			echo "Single disk, skipping mdm configuration..."
			echo ""
			mkfs -t ext 4 $disks
			mkdir /mnt/data
			mount $disks /mnt/data
			echo "$disks /mnt/data   auto defaults,nobootwait,comment=cloudconfig 0       2" >> /etc/fstab
		fi
	fi

	# setup nfs
	if [ $hostname == "$AZURE_HEAD" ]
	then
		fsExist=$( grep "/mnt/data" /etc/fstab ) 
		echo "fs is $fsExist"
		if [ -z "$fsExist" ]
		then	
			if [ -b "/dev/md/data" ]
			then
				echo "/dev/md/data/ /mnt/data   auto defaults,nobootwait,comment=cloudconfig 0       2" >> /etc/fstab
			else
				echo "$disks /mnt/data   auto defaults,nobootwait,comment=cloudconfig 0       2" >> /etc/fstab
			fi
		fi

		exportExist=$( grep "/mnt/data" /etc/exports ) 
		echo "export is $exportExist"
		if [ -z "$exportExist" ]
		then	
			echo "/mnt/data 10.0.0.0/24(rw,nohide,insecure,no_subtree_check,async)" >> /etc/exports
		fi
		
		
		chmod -R 777 /mnt/data
		mount -a
		exportfs -a
	else
		fsExist=$( grep "/mnt/nfsdata" /etc/fstab ) 
		echo "fs is $fsExist"
		if [ -z "$fsExist" ]
		then
			mkdir /mnt/nfsdata
			echo "$AZURE_HEAD:/mnt/data   /mnt/nfsdata   nfs    auto  0  0" >> /etc/fstab
		fi
		mount -a 
	fi

else
	echo ""
	echo "No extra disks..."
	echo ""
fi

echo $disks $diskcount

