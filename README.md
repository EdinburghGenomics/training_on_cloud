# Virtual Destops for training on EC2

## Summary

When running training courses in bioinformatics, you want to put course attendees
in front of Linux systems with the software, sample data and reference data required
to perform analyses that are as close as possible to what they would tackle in the
real world.

One popular way to set up such systems is on IaaS cloud providers like AWS EC2, which
is very flexible but brings a set of problems.

This repository contains our solutions to some of those problems. It is not a quick
fix and will require some knowledge of Linux internals, BASH, Python etc., to get things
working but we hope at least some parts will be useful to others. Most of these ideas
should also translate to other IaaS cloud platforms (Azure, Google, OpenStack providers, ...)

If you are considering running a setup like this please contact me directly
and I'll be happy to discuss what we do at Edinburgh Genomics. (tim.booth@ed.ac.uk)

## One VM per User

You could argue that connecting via vanilla SSH (or PuTTY or MobaXterm or whatever) to a single
large Linux server with multiple accounts is more realistic, given how most people do bioinformatics work.
This is definitely feasible, but the approach here is to give each user their own personal workstation with
a virtual desktop. Then we can control the entire graphical environment and save users copying files back and
forth if they need to view them in a GUI. Also, we had a previous training setup with individual desktops so it
made sense to mirror this in the cloud. We start as many EC2 instances as we have attendees on any given
course (see _Managing Multiple Instances_ below).

## Remote Desktops

After looking at various options, TigerVNC seemed the best remote desktop for us, for the following reasons:

* It's fast and secure (though we're not using the fully secured mode)
* The client runs on just about anything (Windows, Mac, Linux)
* Nice-to-have feature like dynamic destop sizing, view-only connection etc.
* Requires just one open port (or proxies via SSH)

The Ansible setup rules provided here put the VNC server on the VM and set it to start on boot so anyone
connecting with the client immediately sees a destop logged in as user 'training'. We've used XFCE4
as a lightweight desktop environment.

We also considered *x2go* as a remote viewer but sadly this the project is morbid. *NoMachine NX* or *Teradici PCoIP* also
work really well but are commercial software.

Users are instructed on how to set up the client on whatever machine they have in front of them and to
connect to the desktop (see _Managing Multiple Instances_ below).

## Ansible

Use of a configuration management system is highly advisable when working on Cloud VMs
(or indeed any VM) so that configuration changes are documented and reproducible.
Ansible is lightweight and has no client-side dependencies, meaning the playbooks can be run
against brand new VMs created from the stock Ubuntu AMI templates. Here we're not using
Ansible to control the VM deployment on EC2 (though this would be possible) but only to
set files and config on the VM itself. We do however use the _aws_ec2_ iventory plugin to locate
our VMs using EC2 metadata (ie. instance tags) rather than by explicit IP address.

Basic steps to get started:

1. Install Ansible on your dev box
1. Fire up a new Ubuntu instance on EC2 and ensure it has a public IP
1. Add a Role=trainingbase tag to the instance in the AWS console
1. Ensure you can connect via SSH with your .pem file
1. Configure Ansible and the aws_ec2 inventory plugin
1. Run a test playbook against the VM

Understanding the basics of Ansible and writing a test "Hello world" playbook are well documented elsewhere,
as is starting and connecting to EC2 Ubuntu instances with vanilla SSH. Configuring the inventory plugin is slightly
tricky but the sample `.ansible.cfg` and `.ansible/hosts` files here may help. You will also need to set up
the AWS keys and config which get saved in `~/.aws/credentials` and `~/.aws/config` respectively. Once Ansible
is set up this way no further configuration is necessary.

Run:

```
$ ansible-inventory --graph --verbose
```

To check that Ansible sees your instance. Now it is trivial to:

1. Run the master playbook against a vanilla Ubuntu VM tagged as 'trainingbase' or to add updated settings
to an existing master image.
1. Run hot fixes against a whole set of VMs at once, so you can patch problems on-the-fly.

In principle we could always start with a bunch of vanilla Ubuntu instances and configure them with Ansible just
before the course. In practise we snapshot the base image as an AMI and deploy that on the day, but ideally we
avoid making ad-hoc changes to the image and keep everything we change in Ansible.

## Managing Multiple Instances

EC2 has various options for managing multiple VMs at once, like autoscaling groups and such. These are not actually
much use to us. What we want is simply:

1. We have a customised AMI + Launch Template
1. We start as many VMs as we have attendees
1. The AMIs should all get numbers so we know which is which

The last point turns out to be tricky, as there is (currently on EC2) no simple way to assign a range of tags to
multiple VMs when you start them. Therefore we allow the VMs to tag themselves (by setting an IAM role with
appropriate permissions - see `policies/TagInstances.json`) and have a script that runs on first startup to
negotiate the numbering amongst the VMs (see `tag_myself.py`).

Once the `tag_myself.py` script has established the correct number for its VM, this will be displayed on the
remote desktop and in the BASH prompt. See the notes in the script for how this works.

## Connecting to an Instance

EC2 allows you to allocate a public IP address for your instance, which we need to make the connection with TigerVNC.
But this IP address only persists so long as the VM is running, and will change if the VM is stopped and restarted.
The tags set by `tag_myself.py`, which record the VM number, persist until the VM is terminated, so what we want is
a quick way to see a list of tag numbers and IP addresses for all the active VMs. The `summarize_instances.py` script
provides this and can be placed on any internal web server to run as a CGI script.

### Connecting from our own clients

If we are using our own thin clients (stripped-down Linux PCs) in the teaching room, each of these has a number
and an auto-run script that accesses `http://our.internal.server/summarize_instances.cgi`, parses the result to discover
the corresponding VM IP and connects to it by launching TigerVNC. All we need to do is turn the clients on and wait.

### From other computers

The attendees are given a VM number each and provided with instructions to:

1. Install the appropriate TigerVNC client
1. Visit `http://our.internal.server/summarize_instances.cgi` in a local browser
1. Copy-paste the IP for their own VM into TigerVNC
1. Maximize the viewer so they are now seeing just the cloud desktop

Overnight we shut down all the VMs to save running costs, so the next day attendees need to find the
new IP address to retrieve their own VM desktop and any saved files they have on it.

## Auto-shutdown

Running EC2 VMs is pretty cheap but we still find it useful to have all VMs shut down automatically at 6pm (our
course days are generally scheduled to finish at 5). This is done with a very simple CRON job. Note that if using this
you should be careful to set the local time zone correctly. The file `ansible/playbooks/training_master.yml` has sample
rules for this.

## Shared Data and Software

A lot of bioinformatics work involves running pipelines or toolkits. A typical bioinformatics toolkit depends on two
versions of Python, a very specific version of Java, a Ruby interpreter, Perl 5.1  and whatever else the developer was
using back in 2008. To ease the pain of installing these things, often they are bundled up into a single big directory
and distributed as a big ugly tar file with all the dependencies inside (distribution via Conda amounts to the same thing).
You unpack the tar file and off you go, but the problem is that the unpacked directory is many gigabytes. If you put
this directly on your VM image, you'll need to pay for the disk space for all instances of the image. Reference data adds
further space requirements.

An obvious solution is to set up a shared NFS file system that all VMs connect to, and AWS provides the EFS service
for this. For various reasons we've opted instead to keep the shared data files in an S3 bucket and to make it available
to the VMs by mounting the bucket under /mnt/s3fs (with FUSE+s3fs). Additionally, any squashfs files placed into autosquash
directory in the bucket are automounted to /mnt/autosquash (see `ansible/playbooks/auto_squashfs.yml`), a bit like SNAP
packages. This setup provides surprisingly fast read times and supports file attributes not honoured by s3fs. The procedure
for getting a new pipeline onto the VM is thus:

1. Install and test on local dev box under eg. /mnt/autosquash/bigUglyPipeline0.0.4
1. Pack that whole directory into a .squashfs file
1. Upload this to the bucket under ./autosquash
1. Upload any large reference files to the bucket too, but outside of the autosquash area

With this approach, you can test pipelines offline and any new ones you upload to S3 are immediately available to all VMs.

But it would still probably have been more sensible to use EFS...

## Miscellany

Don't forget to disable the screen saver/screen lock on the remote desktops. At present any attempt to blank the X display will crash TigerVNC. Having a screen saver on the client is fine.


