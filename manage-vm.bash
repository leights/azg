#!/bin/bash

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
esac

echo "Running action $laction on $lvm"
$bcmd $lvm $ecmd

}

array=$(echo $2 | tr "," "\n")
for i in $array
do
	echo "$1 acton on VM $i"
	manageVM $1 $i
done
