#!/bin/bash
set -e
set -u

# This is script should be run through packit.perl to make a self-contained thingy.
#==F tigervnc-1.9.0.squash
#==F auto_tigervnc.sh

# Sanity check
test -d /var/lib/addons

# Remove tightvnc
if [ -e /var/lib/addons/tightvnc-viewer.squash ] ; then
    squash-merge -u tightvnc-viewer
    rm /var/lib/addons/tightvnc-viewer.squash
fi

# Copy over tiger
if [ ! -e /var/lib/addons/tigervnc-1.9.0.squash ] ; then
    mv tigervnc-1.9.0.squash /var/lib/addons
    squash-merge -m tigervnc-1.9.0
else
    rm tigervnc-1.9.0.squash
fi

# Check it looks right
vncviewer --help 2>&1 | grep -q Tiger

# Copy the bootstrap script (see thinuser.ini)
mv auto_tigervnc.sh /var/lib/addons
chmod +x auto_tigervnc.sh
