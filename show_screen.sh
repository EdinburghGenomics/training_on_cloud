#!/bin/bash

# Show the screen of an unsuspecting user...
vm_to_show=`printf "%02d\n" $1`

# Use the CSV output it's easier to manipulate in shell
magic_url='https://8xupy2m4r1.execute-api.eu-west-1.amazonaws.com/default/summarize_instances?csv=1'
vm_addr=$( wget -q -O- "$magic_url" | awk -F , '$1=="'"$vm_to_show"'" {print $2}' )

if [ -z "$vm_addr" ] ; then
    echo "No VM found with ID=$vm_to_show"
    exit 1
fi

PATH="/opt/tigervnc/usr/bin:$PATH"

set -x
vncviewer PasswordFile=<(echo "letmein" | vncpasswd -f) \
    ViewOnly=1 Shared=1 RemoteResize=0 "$vm_addr"
