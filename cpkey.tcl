#!/usr/bin/expect -d

set timeout -1

if { $argc != 4 } {
    puts "Usage $argv0 host user pass command"
    exit 1
}

set host [lindex $argv 0]
set user [lindex $argv 1]
set pass [lindex $argv 2]
set myfile [lindex $argv 3]

spawn scp -oStrictHostKeyChecking=no -oCheckHostIP=no $myfile  $user@$host:/home/$user/.ssh/authorized_keys
#spawn ssh-copy-id -i $myfile $user@$host
expect *assword:

send "$pass\r"
expect eof
