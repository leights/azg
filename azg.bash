#!/bin/bash
#############################
### Create cluster in Azure by xplat-cli
### If you have not already installed and configured xplat-cli,
### see http://azure.microsoft.com/en-us/documentation/articles/xplat-cli/
### for details on how to install, configure, and use the xplat-cli.
### written by Trevor Eberl 
#############################

debug=0

IFS=' '

CLUSTER_CONFIG_FILE="`dirname $0`/include.conf"
if [ -f ${CLUSTER_CONFIG_FILE} ]
then
        source ${CLUSTER_CONFIG_FILE}
else
        echo "Error: could not find include.bash configuration file"
        echo "       Expected to find: ${CLUSTER_CONFIG_FILE}"
        exit 1
fi

function usage
{
    echo "usage: create-cluster.bash [[[-a (create|start|stop|destroy|listtemplates)][-p publishSettingsFile.xml ] [-n numberOfWorkers] [-s sizeOfNodes]] | [-h]]"
}

while [ "$1" != "" ]; do
	case $1 in
	-p | --publishfile )    shift
				AZURE_PubFile=$1
				;;
        -n | --numberofworkers )  shift
				AZURE_WkrCount=$1
				;;
	-t | --template )	shift
				AZURE_Template=$1
				;;
	-a | --action )		shift
				AZURE_Action="${1,,}"
				if [ $AZURE_Action == "runcmd" ]
				then
					shift
					AZURE_Cmd="${1}"
				fi
				;;
	-s | --sizeofvm )  	shift
				AZURE_VMSize=$1
				;;
	-h | --help )           usage
				exit
				;;
	* )			usage
				exit 1
	esac
	shift
done

# Confirm vars/args

if [ -z $AZURE_WkrCount ] 
then
	echo Error: AZURE_WkrCount missing
	exit 1
fi

if [ -z $AZURE_Template ] 
then
	echo Error: AZURE_Template missing
	exit 1
fi

if [ -z $AZURE_VMSize_Head ] 
then
	echo Error: AZURE_VMSize missing
	exit 1
fi

if [ -z $AZURE_VMSize_Worker ] 
then
	echo Error: AZURE_VMSize missing
	exit 1
fi

if [ -z $AZURE_Action ]
then
	echo Error: AZURE_Action missing $AZURE_Action
	usage
	exit 1
fi
if [ -z $AZURE_Action ]
then
	echo Error: AZURE_Action missing
	usage
	exit 1
fi

# Check dependencies   

depArray=("expect" "node" "azure" "nc")

for i in "${depArray[@]}"
do
        result=$(which $i|grep "/$i$")
	if [ -z "$result" ]
	then
		echo "Error missing dependency $i"
		echo "try: apt-get install $i"
		exit 1
	fi
done

# Verify/Set account

AZURE_AccName=$(azure account list --json|grep name|awk -F\" '{print $(NF-1)}')
if [ -z "$AZURE_AccName" ]
then
	if [ ! -e $AZURE_PubFile ] 
	then
		echo AZURE_PubFile missing using login
		azure login
	else
		echo AZURE_PubFile exists, loading
		azure account import $AZURE_PubFile
	fi
	AZURE_AccName=$(azure account list --json|grep name|awk -F\" '{print $(NF-1)}')
	echo Set default subscription to $AZURE_AccName
	azure account set $AZURE_AccName
else
	echo "account valid: $AZURE_AccName"
fi

if [ debug == 1 ]
then
	echo PubFile:$AZURE_PubFile SlaveCount:$AZURE_WkrCount Template:$AZURE_Template VMSize:$AZURE_VMSize
	read -p "Press [Enter] key to load account info"
fi

# create name array

function createVMArray
{
VMNameArray=()
AZURE_HeadName="$AZURE_VMName-hst"
VMNameArray+=($AZURE_HeadName)

for ((i=1;i<=$AZURE_WkrCount;i++))
do
	AZURE_WkrName="$AZURE_VMName-wkr$i"
	VMNameArray+=($AZURE_WkrName)
done
}

function manageSA ()
{

saAction=$1
if [ -z "$saAction" ]
then
	echo "Error: saAction missing"
	exit 1
fi

if [ debug == 1 ]
then
	read -p "Press [Enter] key to $saAction storage account"
fi
saexist=$(azure storage account list|grep $AZURE_SAName)
if [ "$saAction" == "create" ]
then
	if [ -z "$saexist" ]
	then
		echo "Creating storage account..."
		azure storage account create $AZURE_SAName --label $AZURE_SAName --location "$AZURE_Location" 
	fi
	setSAEnvVars
fi

if [ "$saAction" == "destroy" ]
then
	if [ -n "$saexist" ]
	then
		SADisks=$(azure storage blob list vhds|grep -v status)
		SADisksShort=$(echo $SADisks|grep $AZURE_VMName)
		while [ -n "$SADisksShort" ]
		do
			#echo "short $SADisksShort"
			echo ""
			echo "SA Still has the below disks.  Sleeping for 5 and checking again..."
			echo ""
			echo $SADisks
			sleep 5
			SADisks=$(azure storage blob list vhds|grep -v status)
			SADisksShort=$(echo $SADisks|grep $AZURE_VMName)
		done

		echo "Storage account $AZURE_SAName exists, removing..."
		azure storage account delete $AZURE_SAName -q
	fi
fi

} 

function setSAEnvVars
{

echo Setting account env variables...
AZURE_STORAGE_ACCESS_KEY=$(azure storage account keys list $AZURE_SAName | grep Primary| awk  '{print $3}'); export AZURE_STORAGE_ACCESS_KEY
AZURE_STORAGE_ACCOUNT=$AZURE_SAName;export AZURE_STORAGE_ACCOUNT

}


function manageVNet ()
{
vnetAction=$1
if [ -z "$vnetAction" ]
then
	echo "Error: vnetAction missing"
	exit 1
fi


if [ debug == 1 ]
then
	read -p "Press [Enter] to $vnetAction vnet"
fi

vnetexist=$(azure network vnet list|grep $AZURE_VNet)
if [ "$vnetAction" == "create" ]
then
	if [ -z "$vnetexist" ]
	then
		echo "Creating vnet..."
		azure network vnet create --address-space 10.0.0.0 --cidr 18 --subnet-start-ip 10.0.0.0 --subnet-name $AZURE_SubNet --subnet-cidr 24 $AZURE_VNet -l "$AZURE_Location"
	fi
fi

if [ "$vnetAction" == "destroy" ]
then

	if [ -n "$vnetexist" ]
	then
  		echo "VNet $AZURE_VNet exists, destroying..."
  		azure network vnet delete $AZURE_VNet -q
	fi
fi

}

function createVM ()
{

lvm=$1
lvmSize=$2
ldiskCount=$3
lip=$4 #place holder for now

if [ -z "$lvm" ]
then
	echo "Error: manage missing lvm"
	exit 1
fi

if [ -z "$lvmSize" ]
then
	echo "Error: manage missing lvm size"
	exit 1
fi

if [ -z "$ldiskCount" ]
then
	echo "Error: manage missing disk count"
	exit 1
fi


vmexist=""
vmexist=$(azure vm list|grep $lvm)
if [ -n "$vmexist" ]
then
	echo "VM $vm exists, skipping..."
	#echo $vmexist
else
	if [ debug == 1 ]
	then
		read -p "Press [Enter] key to create vm $vm"
	fi
	echo "Creating VM $vm..."
	azure vm create -u https://$AZURE_SAName.blob.core.windows.net/vhds/$lvm-OS.vhd -z $lvmSize -n $lvm -e 22 -w $AZURE_VNet -b $AZURE_SubNet -l "$AZURE_Location" $lvm $AZURE_Template -u $AZURE_User -p $AZURE_Pass
fi

addDisks $lvm $ldiskCount
}

function addDisks ()
{

lvm=$1
ldiskCount=$2

if [ -z "$ldiskCount" ]
then
	echo "Error: manage missing disk count"
	exit 1
fi

if [ -z "$lvm" ]
then
	echo "Error: manage missing lvm"
	exit 1
fi


echo "attaching $ldisks disks to $lvm"
vmstatus=""
echo "getting $lvm status"
vmstatus=$(azure vm list |grep $lvm|awk '{print $3}')
#echo status is $vmstatus
while [ "$vmstatus" != "ReadyRole" ]
do
	echo "waiting for $lvm to come online..."
	sleep 10
	vmstatus=$(azure vm list |grep $lvm|awk '{print $3}')
done

if [ "$vmstatus" == "ReadyRole" ] 
then
	echo "getting disk count for $lvm"
	disks=$(azure storage blob list --container vhds|grep $lvm|grep -c 1098437886464)
	echo "$lvm has $disks disks of $ldiskCount"
	while [ $disks -lt $ldiskCount ]
	do
		echo "adding disk to $lvm"
		newdisk=$(($disks + 1))
		#azure vm disk create -u https://$AZURE_SAName.blob.core.windows.net/vhds/$lvm-Data-$newdisk.vhd -e  "$lvm data disk $newdisk"
		azure vm disk attach-new $lvm 1023 https://$AZURE_SAName.blob.core.windows.net/vhds/$lvm-DataDisk-$newdisk.vhd
		echo "getting current disk count for $lvm"
		disks=$(azure storage blob list --container vhds|grep $lvm|grep -c 1098437886464)
		echo "$lvm has $disks of $ldiskCount created"
	done
fi
}

function manageVM ()
{
laction=$1
lvm=$2
if [ -z "$lvm" ]
then
	echo "Error: manage missing vm"
	exit 1
fi
if [ -z "$laction" ]
then
	echo "Error: managevm missing action"
	exit 1
fi

case "$laction" in
	stop)
		bcmd="azure vm shutdown "
		ecmd=""
		;;
	start)
		bcmd="azure vm start "
		ecmd=""
		;;
	destroy)
		bcmd="azure vm delete "
		ecmd=" -b -q"
		;;
esac

if [ "$lvm" == "all" ]
then
	vms=$(azure vm list)
	for vm in ${VMNameArray[*]}
	do
		vmexist=""
		vmexist=$(echo $vms|grep $vm)
		if [ -n "$vmexist" ]
		then
			echo "Running action $laction on $vm"
			#echo "$bcmd $vm $ecmd"
			$bcmd $vm $ecmd
		fi
	done
else
	echo "Running action $laction on $lvm"
	$bcmd $lvm $ecmd
fi
		

}

function destroyVM ()
{
lvm=$1
if [ -z "$lvm" ]
then
	echo "Error: destroyvm missing vm"
	exit 1
fi
if [ "$lvm" == "all" ]
then
	vms=$(azure vm list)
	for vm in ${VMNameArray[*]}
	do
		vmexist=""
		vmexist=$(echo $vms|grep $vm)
		if [ -n "$vmexist" ]
		then
			echo "destroying $vm"
			azure vm delete $vm -b -q
		fi
	done
else
	echo "destroying $lvm"
	azure vm delete $lvm -b -q
fi
		

}

function destroyCluster
{

#must remove VMs first
vmActions

}


function warning
{
	setSAEnvVars
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!WARNING!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo "This will delete all of the assets below w/o asking again!!"
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!WARNING!!!!!!!!!!!!!!!!!!!!!!!!!"
	echo ""
	echo "Storage Account: $AZURE_SAName"
	#azure storage blob list vhds
	echo "Virtual Network: $AZURE_VNet"
	#echo "VMs: $VMNameArray"
	disks=$(azure storage blob list vhds --json)
	for vm in ${VMNameArray[*]}
	do
		echo "VM: $vm"
		echo "Disks:"
		echo -e $disks|grep $vm|grep -v status
		#azure vm disk list $vm|grep $vm
	done
	echo ""
	echo "Do you want to do this?(y/n)"
	read answer
	if [ $answer != "y" ]
	then
		exit
	fi
}

function cpKeys 
{

CP_KEY="`dirname $0`/cpkey.tcl"

if [ -e ./rsa_key ] 
then
	echo "Key file exists, moving on..."
else
	echo "generating key $KEY_GEN"
	ssh-keygen -f ./rsa_key -P ""
fi

for vm in ${VMNameArray[*]}
do
	knownHosts=$(ssh-keygen -F $vm.cloudapp.net)
	if [ -n "$knownHosts" ]
	then
		echo ""
		echo "removing $vm from known_hosts"
		echo ""
		ssh-keygen -R $vm.cloudapp.net
	fi

	sshStatus=$(nc -z -v -w 5 $vm.cloudapp.net 22  2>&1 | grep succeeded )
	while [ -z "$sshStatus" ]
	do
		echo "waiting for ssh on $vm"
		sleep 5
		sshStatus=$(nc -z -v -w 5 $vm.cloudapp.net 22  2>&1 | grep succeeded )
	done

	echo "SSH port open, now to wait a bit before we try to copy the key"
	sleep 10 # give it a few more seconds to respond correctly
	echo "copying rsa key to $vm..."
	expect $CP_KEY $vm.cloudapp.net $AZURE_User $AZURE_Pass rsa_key.pub
done

}

function runCmd
{
for vm in ${VMNameArray[*]}
do
	echo "running '$AZURE_Cmd' on $vm"
	ssh -oStrictHostKeyChecking=no -oCheckHostIP=no $AZURE_User@$vm.cloudapp.net -i rsa_key $AZURE_Cmd
done
}

function configureSGE
{
if [ -e $AZURE_HeadScript ]
then
	echo ""
else
	echo "Error: missing $AZURE_HeadScript"
	exit
fi

if [ -e $AZURE_WkrScript ]
then
	echo ""
else
	echo "Error: missing $AZURE_WkrScript"
	exit
fi

getdns

for vm in ${VMNameArray[*]}
do
	if [[ $vm == *"-hst"* ]]
	then
		echo "Copying $AZURE_HeadScript to $vm"
		scp -oStrictHostKeyChecking=no -oCheckHostIP=no -i rsa_key $AZURE_HeadScript $AZURE_User@$vm.cloudapp.net:/home/$AZURE_User/install.bash
	else
		echo "Copying $AZURE_WrkScript to $vm"
		scp -oStrictHostKeyChecking=no -oCheckHostIP=no -i rsa_key $AZURE_WkrScript $AZURE_User@$vm.cloudapp.net:/home/$AZURE_User/install.bash
	fi
	#scp -oStrictHostKeyChecking=no -oCheckHostIP=no -i rsa_key ./setenv.bash $AZURE_User@$vm.cloudapp.net:/home/$AZURE_User/setenv.bash
	#ssh -oStrictHostKeyChecking=no -oCheckHostIP=no $AZURE_User@$vm.cloudapp.net -i rsa_key /home/$AZURE_User/setenv.bash
	hostResult=$(ssh -oStrictHostKeyChecking=no -oCheckHostIP=no $AZURE_User@$vm.cloudapp.net -i rsa_key grep $vm /etc/hosts)
	if [ -z "$hostResult" ]
	then
		echo "adding /etc/hosts entry to $vm"
		ssh -oStrictHostKeyChecking=no -oCheckHostIP=no $AZURE_User@$vm.cloudapp.net -i rsa_key "sudo chown $AZURE_User /etc/hosts"
		echo -e "$intHosts" | ssh -oStrictHostKeyChecking=no -oCheckHostIP=no $AZURE_User@$vm.cloudapp.net -i rsa_key 'cat >> /etc/hosts'
	fi

	ssh -oStrictHostKeyChecking=no -oCheckHostIP=no $AZURE_User@$vm.cloudapp.net -i rsa_key "chmod +x /home/$AZURE_User/install.bash"
	ssh -oStrictHostKeyChecking=no -oCheckHostIP=no $AZURE_User@$vm.cloudapp.net -i rsa_key /home/$AZURE_User/install.bash $AZURE_HeadName
	
done
sgecpcfg
}

function getdns
{
intHosts=""
sgeHosts=""
for vm in ${VMNameArray[*]}
do
	vmip=$(azure vm list -d $vm|grep $vm|awk '{print $NF}')
	intHosts+=$(echo $vmip $vm '\n')
	sgeHosts+=$(echo "$vm " )
	#echo $vm $vmip
done
	echo -e "$intHosts"
}


function sgecpcfg 
{

# create host config
getdns
echo -e "group_name @allhosts" > $AZURE_SGEHostgroup
echo -e "hostlist $sgeHosts" >> $AZURE_SGEHostgroup

#copy files
scp -oStrictHostKeyChecking=no -oCheckHostIP=no -i rsa_key $AZURE_HeadConfScript $AZURE_User@$AZURE_HeadName.cloudapp.net:/home/$AZURE_User/sgeconf.bash
scp -oStrictHostKeyChecking=no -oCheckHostIP=no -i rsa_key $AZURE_SGEQConf $AZURE_User@$AZURE_HeadName.cloudapp.net:/home/$AZURE_User/queue.conf
scp -oStrictHostKeyChecking=no -oCheckHostIP=no -i rsa_key $AZURE_SGEHostgroup $AZURE_User@$AZURE_HeadName.cloudapp.net:/home/$AZURE_User/hostgroup.conf

#run script
ssh -oStrictHostKeyChecking=no -oCheckHostIP=no -i rsa_key $AZURE_User@$AZURE_HeadName.cloudapp.net "chmod +x /home/$AZURE_User/sgeconf.bash"
ssh -oStrictHostKeyChecking=no -oCheckHostIP=no -i rsa_key $AZURE_User@$AZURE_HeadName.cloudapp.net /home/$AZURE_User/sgeconf.bash $AZURE_User $sgeHosts

}

function fixdns
{
getdns
for vm in ${VMNameArray[*]}
do
	hosts=$(ssh -oStrictHostKeyChecking=no -oCheckHostIP=no -i rsa_key $AZURE_User@$vm.cloudapp.net "egrep -v $AZURE_VMName /etc/hosts")
	finalhosts="$hosts""\n""$intHosts"
	echo "updating /etc/hosts on $vm"
	ssh -oStrictHostKeyChecking=no -oCheckHostIP=no $AZURE_User@$vm.cloudapp.net -i rsa_key "sudo chown $AZURE_User /etc/hosts"
	echo -e "$finalhosts" | ssh -oStrictHostKeyChecking=no -oCheckHostIP=no $AZURE_User@$vm.cloudapp.net -i rsa_key 'cat > /etc/hosts'
	#echo "$vm start"
	#ssh -oStrictHostKeyChecking=no -oCheckHostIP=no $AZURE_User@$vm.cloudapp.net -i rsa_key 'cat /etc/hosts'
	#echo "$vm end"

done

}

function configureDisks 
{

for vm in ${VMNameArray[*]}
do
	scp -oStrictHostKeyChecking=no -oCheckHostIP=no -i rsa_key $AZURE_DiskScript $AZURE_User@$vm.cloudapp.net:/home/$AZURE_User/configure-disks.bash
	ssh -oStrictHostKeyChecking=no -oCheckHostIP=no $AZURE_User@$vm.cloudapp.net -i rsa_key "chmod +x /home/$AZURE_User/configure-disks.bash"
	ssh -oStrictHostKeyChecking=no -oCheckHostIP=no $AZURE_User@$vm.cloudapp.net -i rsa_key sudo /home/$AZURE_User/configure-disks.bash $AZURE_HeadName
done
}

# Main block

createVMArray

case "$AZURE_Action" in
	listtemplates)
		echo "listing templates.."
		azure vm image list
		;;
	create)
		echo "creating cluster.."
		manageSA create
		manageVNet create
		for vm in ${VMNameArray[*]}
		do
			if [ $vm == "$AZURE_HeadName" ]
			then
				echo ""
				echo "creating headnode"
				echo ""
				createVM $vm $AZURE_VMSize_Head $AZURE_HostDiskCount
			else
				echo ""
				echo "creating workernode"
				echo ""
				createVM $vm $AZURE_VMSize_Worker $AZURE_WorkerDiskCount
			fi
		done
		cpKeys
		fixdns
		configureDisks
		configureSGE
		AZURE_Cmd="sudo /etc/init.d/gridengine-exec restart"
		runCmd
		;;
	stop)
		echo "stopping cluster.."
		manageVM stop all
		;;
	start)
		echo "starting cluster..."
		manageVM start all
		;;
	destroy)
		echo "destroying cluster..."
		warning
		manageVM destroy all
		manageVNet destroy
		manageSA destroy
		;;
	copykey)
		cpKeys
		;;
	getdns)
		getdns
		;;
	fixdns)
		fixdns
		;;
	runcmd)
		runCmd
		;;
	confdisk)
		configureDisks
		;;
	sgecpcfg)
		sgecpcfg
		;;
	sge)
		configureSGE
		;;
	*)
		echo "Error: Unknown action $AZURE_Action"
		usage
		exit
		;;
esac
