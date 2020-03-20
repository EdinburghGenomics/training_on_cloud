#!/bin/sh

# Connect a WYSE term to the cloud. We need vncviewer to be the Tiger version.
if ! vncviewer --help 2>&1 | grep Tiger ; then
    echo "vncviewer is not TigerVNC"
    exit 1
fi

# Work out which host I am (last 2 chars of hostname)
mynum="${HOSTNAME: -2}"

# Get the magic info.
# Note we need a special version of curl to talk to modern https sites.
magic_curl='/var/lib/addons/curl_static'
#magic_url='http://egcloud.bio.ed.ac.uk/si?csv=1'
magic_url='https://8xupy2m4r1.execute-api.eu-west-1.amazonaws.com/default/summarize_instances?csv=1'
vnc_addr=`$magic_curl -k -# "$magic_url" | grep "^${mynum}," | cut -d, -f2`

# Write out the password
echo "letmein" | vncpasswd -f > ~/.vncpwd

# Force screen blanking with a long delay since it's annoying (but if you bash F8 a few times
# it does come back!)
killall gnome-screensaver
xset s off
xset dpms 0 0 5400

# Give me terminal cos thats useful
xterm -iconic &

# Connect! (If there was no vnc_addr this should prompt)
echo vncviewer FullScreen=1 PasswordFile="$HOME/.vncpwd" $vnc_addr
exec vncviewer FullScreen=1 PasswordFile="$HOME/.vncpwd" $vnc_addr
