#!/bin/sh

# Connect a WYSE term to the cloud. We need vncviewer to be the Tiger version.
if ! vncviewer --help 2>&1 | grep Tiger ; then
    echo "vncviewer is not TigerVNC"
    exit 1
fi

# Work out which host I am (last 2 chars of hostname)
mynum="${HOSTNAME: -2}"

# Get the magic info
vnc_addr=`curl -# 'http://egcloud.bio.ed.ac.uk/si?csv=1' | grep "^${mynum}," | cut -d, -f2`

# Write out the password
echo "letmein" | vncpasswd -f > ~/.vncpwd

# Connect! (If there was no vnc_addr this should prompt)
echo vncviewer FullScreen=1 PasswordFile="$HOME/.vncpwd" $vnc_addr
exec vncviewer FullScreen=1 PasswordFile="$HOME/.vncpwd" $vnc_addr
