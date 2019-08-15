#!/bin/bash
set -eu

## Helper script to link files from /mnt/s3fs/overlay. Run as root.

OVERLAY_ROOT=${OVERLAY_ROOT:-/mnt/s3fs/overlay}
DRY_RUN=${DRY_RUN:-0}

if [ `id -u` != 0 ] ; then
    echo "Running as `id -nu` - forcing DRY_RUN as you are not root."
    DRY_RUN=1
fi
if [ "$DRY_RUN" != 0 ] ; then
    echo "*** Dry run only ***"
    function irun(){ echo DRY_RUN: "$@" ; }
else
    function irun(){ "$@" ; }
fi

# Find all files in OVERLAY_ROOT and set up some counters.
exec 6< <(find $OVERLAY_ROOT -type f -print0)
file_counter=0
dmade_counter=0
lmade_counter=0

function mkdir_p(){
    # Like mkdir -p but preserves owner based on the last
    # existing directory. $1 must start with a / but not end with one!

    # Make a list of paths to the target.
    # eg. targets=(/ /foo /foo/bar /foo/bar/baz)
    targets=("$1")
    while [ "${targets[0]}" != '/' ] ; do
        targets=("`dirname "${targets[0]}"`" "${targets[@]}")
    done

    # Ignore the case where target is a file or dangling link. This will rightly
    # just raise an error.
    for t in "${targets[@]}" ; do
        if [ ! -e "$t" ] ; then
            irun mkdir -v "$t"
            irun chown --reference="$t/.." "$t"
            dmade_counter=$(( $dmade_counter + 1 ))
        fi
    done
}

# Loop through the files and process them.
while read -u 6 -d $'\0' f ; do
    basename="`basename $f`"
    target="${f#$OVERLAY_ROOT}"

    file_counter=$(( $file_counter + 1))
    if [ -L "$target" ] && [ "`readlink -f "$target"`" = "$f" ] ; then
        # It's all good!
        true
    else
        # Remove whatever was there (this is silent if the path is missing)
        irun rm -vf "$target"

        # Ensure the directory is in place. Use the helper script as this is
        # a little tricky.
        mkdir_p "`dirname "$target"`"

        # Linky!
        irun ln -svn "$f" "$target"
        irun chown -h --reference="`dirname "$target"`" "$target"
        lmade_counter=$(( $lmade_counter + 1 ))
    fi
done

echo "Found $file_counter files under $OVERLAY_ROOT"
echo "Created $lmade_counter new symlinks and $dmade_counter new directories."
