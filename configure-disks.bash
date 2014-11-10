#!/bin/bash

function usage
{
    echo "usage: script.bash AZURE_HEADNODE"
}

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo "args ar $@"
AZURE_HEADNODE=$1
AZURE_DATA_MOUNT="/data"
AZURE_RAID_DEVICE="/dev/md127"
AZURE_NFS_MOUNT="/nfsdata"
AZURE_EXPORTS_SUBNET="10.0.0.0/24"

if [ -z $AZURE_HEADNODE ]
then
        echo Error: AZURE_HEADNODE missing
        usage
        exit 1
fi

hostname=$(hostname)

echo "postfix postfix/main_mailer_type select No configuration" | sudo debconf-set-selections

if [ $hostname == "$AZURE_HEADNODE" ]
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

		if [ -b "$AZURE_RAID_DEVICE" ]
		then
       		 echo "$AZURE_RAID_DEVICE alread exists moving on..."
		else
			echo ""
			echo "Creating raid for $hostname"
			echo ""
			#read -p "Press [Enter] to create stripped disk out of $disks"
			mdadm --create $AZURE_RAID_DEVICE --symlink=no --name=data --chunk=8 --level=0 --raid-devices=$diskcount $disks
			mkfs -t ext4 $AZURE_RAID_DEVICE
			mkdir $AZURE_DATA_MOUNT
			chmod -R 777 $AZURE_DATA_MOUNT
			mount $AZURE_RAID_DEVICE $AZURE_DATA_MOUNT
			chmod 664 /etc/fstab
			chgrp adm /etc/fstab
			echo "$AZURE_RAID_DEVICE $AZURE_DATA_MOUNT   auto defaults,nobootwait,comment=cloudconfig 0       2" >> /etc/fstab
			mdadm --detail --verbose --scan > /etc/mdadm/mdadm.conf
			df -h
		fi

	else
		if [ -b "$AZURE_RAID_DEVICE" ]
		then
       		 	echo "$AZURE_RAID_DEVICE alread exists moving on..."
		else
			echo ""
			echo "Single disk, skipping mdm configuration on $hostname"
			echo ""
			mkfs -t ext 4 $disks
			mkdir $AZURE_DATA_MOUNT
			mount $disks $AZURE_DATA_MOUNT
			echo "$disks $AZURE_RAID_DEVICE   auto defaults,nobootwait,comment=cloudconfig 0       2" >> /etc/fstab
		fi
	fi

	# setup nfs
	if [ $hostname == "$AZURE_HEADNODE" ]
	then
		fsExist=$( grep "$AZURE_DATA_MOUNT" /etc/fstab ) 
		#echo "fs is $fsExist"
		if [ -z "$fsExist" ]
		then	
			if [ -b "$AZURE_RAID_DEVICE" ]
			then
				echo "$AZURE_RAID_DEVICE $AZURE_DATA_MOUNT   auto defaults,nobootwait,comment=cloudconfig 0       2" >> /etc/fstab
			else
				echo "$disks $AZURE_DATA_MOUNT   auto defaults,nobootwait,comment=cloudconfig 0       2" >> /etc/fstab
			fi
		fi

		exportExist=$( grep "$AZURE_DATA_MOUNT" /etc/exports ) 
		echo "export is $exportExist"
		if [ -z "$exportExist" ]
		then	
			echo "$AZURE_DATA_MOUNT $AZURE_EXPORTS_SUBNET(rw,nohide,insecure,no_subtree_check,async)" >> /etc/exports
		fi
		
		
		chmod -R 777 $AZURE_DATA_MOUNT
		mount -a
		exportfs -a
	else
		fsExist=$( grep "$AZURE_NFS_MOUNT" /etc/fstab ) 
		#echo "fs is $fsExist"
		if [ -z "$fsExist" ]
		then
			mkdir $AZURE_NFS_MOUNT
			chmod 664 /etc/fstab
			chgrp adm /etc/fstab
			echo "$AZURE_HEADNODE:$AZURE_DATA_MOUNT   $AZURE_NFS_MOUNT   nfs    auto  0  0" >> /etc/fstab
		fi
		mount -a 
	fi

else
	echo ""
	echo "No unknown disks..."
	echo ""
fi

echo $disks $diskcount

