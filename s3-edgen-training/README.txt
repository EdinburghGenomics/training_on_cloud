## S3 Bucket at https://s3.console.aws.amazon.com/s3/buckets/edgen-training/?region=eu-west-1

If you are reading this file in /mnt/s3fs on a training VM, then the files in this directory
are being accessed via an S3 bucket, which is basically like an FTP server, made to act like
part of the regular file system (but read-only) via s3fs-fuse.

The following info should be useful if you are trying to modify the training image for a new
course, by adding or amending files in this area. If not, it's probably not so useful, but
you can read it anyway if you like.

** Why this setup?

The most obvious way to provide data files for use in course modules is to copy them to the master
EC2 image and thus to bake them into the AMI that is cloned for all the students. For small-ish
files and most software this is exactly what you should do. But adding large files entails a
larger disk size for every single VM, and this costs money. Putting the file on an FTP site
doesn't help as students still need to copy the files to the local disk during the course, so
they still need a big disk. The s3fs mount provides a workaround where the files appear local
but are actually just a single copy on S3.

** What should go on to S3?

If you are adding something like a new reference genome, or any single data file over 500MB, it
should probably go on to S3 and not the base image.

** What should NOT go on S3?

Most things, in particular:
- Any file the student is expected to edit or modify.
- Large collections of small-ish files, because of the high overhead of directory
  scanning and per-file opening (but see autosquash below).
- Software tools, because the file permissions get totally messed up (but see
  autosquash below).

** How do I put a file on here?

It's possible to use s3fs in read/write mode if you force a remount with your own valid AWS
credentials. However my advice would be to upload via the web interface (link at the top)
or the standard S3 command-line tools (see AWS docs and any number of on-line help resources).

** How do I make the new file I just put on S3 appear on the VM?

The VM can immediately access any file in the bucket, but you'll probably want to use a symlink
to have the file show up where you actually want it.

The idea here is that the 'overlay' directory is structured to match the standard VM filesystem,
and for each file you put in there, a symlink in the real file system will point back to it from
the corresponding location. So for example if you want to add a new file:

  /home/training/my_course/my_big_genome.fa

You upload the file into the edgen-training S3 bucket under:

  /overlay/home/training/my_course/my_big_genome.fa

Then back on the VM, you make the '/home/training/my_course' directory and symlink the file
within that directory:

  my_course/my_big_genome.fa -> /mnt/s3fs/overlay/home/training/my_course/my_big_genome.fa

So the directory and the symlimk live on the image but the data stays on S3.

* Can the overlay_linker.sh script help me?

Yes! In fact, you should avoid making the symlinks manually as it is easy to mess up.
Run the script (as root) on the VM and it will ensure all the overlay links are in place. The
script is idempotent so run it as many times as you like. If a file exists both in
/mnt/s3fs/overlay and also on the real file system it will be removed from the real FS and
replaced with a link. Links will always be made to individual files, not directories. There are good
reasons for doing this - principally it avoids unexpected 'filesystem is read-only' errors when
trying to write a new file into a directory you didn't realise was symlinked to s3fs.

* What about removing old dangling links if a file is removed from S3?

You need to do this manually. Remember that 'find -L -type l' can help you scan for dangling
links.

* Autosquash - how does this help me for smaller files or software packages?

It seems that putting a squashfs file system in an S3 bucket then mounting it via s3fs+loopback
works remarkably well, so I've added an automounter config to the images that makes this simple.

Using a squashfs gets around the small-files problem and the permissions problem, and
also gives you data compression in case the files are not already compressed (but the files
are still read-only). A squash file is like a tarball that can be mounted directly into the
file system without unpacking it. You can convert a tarball to a squashfs like so (given
my-tarball.tar.gz containing a single top level directory named my-tarball):

$ tar -xvaf my-tarball.tar.gz
$ cd my-tarball/
$ fakeroot mksquashfs . ../my-tarball.squash -comp xz

Now add the my-tarball.squash file to /autosquash in this S3 bucket. On an image, try:

$ ls -l /mnt/autosquash/my-tarball

Magic! The only real problems with this approach are the extra step to make the .squash file, and that
it's not possible to easily see the individual file on the S3 bucket without looking through the image.

--
TIM B. - Jan 2019
