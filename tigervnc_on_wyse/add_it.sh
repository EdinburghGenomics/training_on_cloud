#!/bin/bash
set -eu

# This is script should be run through packit.perl to make a self-contained thingy.
#==I root
#==F tigervnc-1.10.1.squash
#==F curl_static
#==F auto_tigervnc.sh

echo RUNNING $0 as `whoami`

# Sanity check
test -d /var/lib/addons

# Remove tightvnc and old tigervnc
for pkg in tightvnc-viewer tigervnc-1.9.0 ; do
    if [ -e /var/lib/addons/${pkg}.squash ] ; then
        echo squash-merge -u ${pkg}
        squash-merge -u ${pkg}
        rm /var/lib/addons/${pkg}.squash
    fi
done

# Copy over tiger
for pkg in tigervnc-1.10.1 ; do
    if [ ! -e /var/lib/addons/${pkg}.squash ] ; then
        mv ${pkg}.squash /var/lib/addons
        squash-merge -m ${pkg}
    else
        rm ${pkg}.squash
    fi
done

# Check it looks right
vncviewer --help 2>&1 | grep TigerVNC | grep -q v1.10.1

# Copy the bootstrap script (see thinuser.ini)
mv -t /var/lib/addons auto_tigervnc.sh
chmod +x /var/lib/addons/auto_tigervnc.sh

# Copy curl_static (needed for newer SSL)
mv -t /var/lib/addons curl_static
chmod +x /var/lib/addons/curl_static

# Touch the thing to show we did the thing.
touch /tmp/rcrun ; chown admin /tmp/rcrun
