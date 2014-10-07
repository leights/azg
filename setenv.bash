#!/bin/bash

root=$(cat ~/.bashrc | grep SGE_ROOT)
if [ -z "$root" ]
then
        echo setting SGE_ROOT
        echo "export SGE_ROOT=/var/lib/gridengine" >> ~/.bashrc
fi
cell=$(cat ~/.bashrc | grep SGE_CELL)
if [ -z "$cell" ]
then
        echo setting SGE_CELL
        echo "export SGE_CELL=default" >> ~/.bashrc
fi

inter=$(cat ~/.bashrc | grep DEBIAN_FRONTEND)
if [ -z "$inter" ]
then
        echo "export DEBIAN_FRONTEND=noninteractive" >> ~/.bashrc
fi
#echo "get shared/gridengineconfig" | sudo debconf-communicate
#echo "set postfix/main_mailer_type 1" | sudo debconf-communicate
#echo "setting postfix postfix/main_mailer_type select No configuration" 
#echo "postfix postfix/main_mailer_type select No configuration" | sudo debconf-set-selections
#echo "set shared/gridengineconfig true" | sudo debconf-communicate
#echo "set shared/gridenginecell default" | sudo debconf-communicate

#if [[ $(hostname) == *"-mstr"* ]]
#then
#echo "set shared/gridenginemaster $hostname" 
#echo "set shared/gridenginemaster $hostname" | sudo debconf-communicate
#fi
