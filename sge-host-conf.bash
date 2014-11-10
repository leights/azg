#!/bin/bash

#############################
### On master node 
#############################

function usage
{
    echo "usage: script.bash AZURE_USER HOST1 HOST2 ... HOSTN"
}

echo "args ar $@"
AZURE_USER=$1
shift
SGE_HOSTS=$@

if [ -z $AZURE_USER ]
then
        echo Error: AZURE_USER missing
	usage
        exit 1
fi

if [ -z "$SGE_HOSTS" ]
then
        echo Error: AZURE_HOSTS missing
	usage
        exit 1
fi

echo "user $AZURE_USER hosts $SGE_HOSTS"
## Add yourself as a manager
sudo -u sgeadmin qconf -am $AZURE_USER

## And add yourself to a userlist.
qconf -au $AZURE_USER users

## Add a submission host
qconf -as $(hostname)

## Add a new host group
# Just save the file without modifying it
#qconf -ahgrp @allhosts
qconf -dhgrp @allhosts
#qconf -ahgrp @allhosts <<< :wq
qconf -Ahgrp ~/hostgroup.conf

## Add the exec host to the @allhosts list
#qconf -aattr hostgroup hostlist $(hostname) @allhosts
#qconf -aattr hostgroup hostlist sgelinux-work01 @allhosts
#qconf -aattr hostgroup hostlist sgelinux-work02 @allhosts
#qconf -aattr hostgroup hostlist sgelinux-work03 @allhosts

## Add a queue
# Just save the file without modifying it
qconf -dq default
qconf -Aq ~/queue.conf

## Add the host group to the queue
#qconf -aattr queue hostlist @allhosts main.q

## Make sure there is a slot allocated to the execd
#qconf -aattr queue slots "2, [$(hostname)=1]" default

## Adding Exec node to the grid

arr=$(echo -e $SGE_HOSTS|tr ' ' '\n' )
for i in $arr
do
	qconf -as $i
done

## See host status of the grid
echo "Printing hosts info to verify that things are working correctly."
qhost
echo "Printing queue info to verify that things are working correctly."
qstat -f
echo "You should see sge_execd and sge_qmaster running below:"
ps aux | grep "sge"
