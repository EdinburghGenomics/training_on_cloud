#!/usr/bin/env python3

"""Get an instance to tag itself after booting"""
import os
import json
import requests
import botocore.session
import random
from time import sleep
from subprocess import run, PIPE

def get_my_info():
    """ Get my own instance ID. There really is no botocore wrapper to get this.
    """
    response = requests.get('http://169.254.169.254/latest/dynamic/instance-identity/document')
    return json.loads(response.text)

def get_instance_info(client):
    """ Get some info on all the instances with Role=trainingvm
    """
    # Find all VMs that have a Role of trainingvm
    resp = client.describe_instances(Filters=[dict(Name='tag:Role', Values=['trainingvm'])])

    # A bad query raises an exception, so we shouldn't need this
    assert resp['ResponseMetadata']['HTTPStatusCode'] == 200

    # Now dig out the instances
    instances = [ i for r in resp['Reservations'] for i in r['Instances'] ]

    # Filter out anything in state 'terminated'
    instances = [ i for i in instances if i['State']['Name'] != 'terminated' ]

    def l_to_d(td):
        """Transform a list of Key/Value dicts to a single dict
        """
        return { i['Key']: i['Value'] for i in td }

    # Get the pertinent info for the instances
    return [ dict( instanceId = i['InstanceId'],
                   Name = l_to_d(i['Tags'])['Name'],
                   VM = l_to_d(i['Tags'])['Name'].split('-')[-1],
                   PrivateName = i['PrivateDnsName'],
                   PublicName = i.get('PublicDnsName'),
                   State = i['State']['Name'] )
             for i in instances ]

# So my idea is that when an instance boots, it looks to see if it is in Role=trainingvm
# and name is 'training' or 'training-00'. If so, it picks the next available number and renames
# itself. Smart, eh?

# I can make this a one-off task on boot and add it to the VM recipe.

# Problem. Two VMs attempt to tag themselves with the same number. How do I break the deadlock?
# Well, assuming that AWS tags propogate neatly(ish), I could:
# 1) Set the tag I want for myself
# 2) Wait a second then re-query.
# 3) If someone else took the tag, and they have a lower instance_id, try again.
#
# Can this fail?
#  Well, there's clearly a race condition where an instance can claim, say, training-02,
#  but between making the initial scan and setting the tag another instance with a higher
#  ID has claimed number 02 and decided that all is well. So there will be problems if
#  the wait time in part 2 is ever shorter than the time to do 1.
#  My conclusion is that if I make the wait long enough (5 sec?) then this will be very unlikely,
#  plus the consequences are not dire (you have to fix the names in the web interface).

def rename_myself():

    my_info = get_my_info()

    # This will work if aws configure was done correctly or if we're on an instance with
    # the right IAM role, but I do need to discover what region I'm in.
    sesh = botocore.session.Session()
    client = sesh.create_client('ec2', region_name=my_info['region'])

    # Get all the info
    i_info = get_instance_info(client)

    # Get my own info. Should be exactly one, assuming the instance is correctly tagged
    my_info, = [ i for i in i_info if i['instanceId'] == my_info['instanceId'] ]

    # Also see what the hostname says
    current_num = get_current_number()

    # So by the above notes I need to rename myself under these conditions:
    if my_info['Name'] in ['training', 'training-00']:
        # I've not renamed myself at all yet.
        print("No rename has happened yet.")
    elif my_info['VM'] in [ i['VM'] for i in i_info if i['instanceId'] < my_info['instanceId'] ]:
        # I renamed myself but there's a clash and I need to change
        print("Name conflict on training-{} with VM having a lower instanceId".format(my_info['VM']))
    elif current_num != my_info['VM']:
        print("Tags say I am {} but hostname says {}. Will fix hostname to match tag.".format(my_info['VM'], current_num))
        return my_info['VM']
    else:
        # No I'm actually fine.
        print("I am training-{}. Nothing to do.".format(my_info['VM']))
        return None

    # Find a suitable number:
    for newnum in range(1,100):
        newnumstr = "{:02d}".format(newnum)

        if newnumstr in [ i['VM'] for i in i_info ]:
            # The number is taken
            continue
        else:
            # Get botocore to make the tag
            print("Setting name for {} to training-{}".format(my_info['instanceId'], newnumstr))
            client.create_tags( Resources = [my_info['instanceId']],
                                Tags = [dict(Key="Name", Value="training-{}".format(newnumstr))] )
            break
    else:
        raise RuntimeError("Ran out of numbers")

    # Sleep and call myself recursively. In most cases the call to self should return
    # None from the else block above, else pass it back to the caller.
    sleep(random.uniform(4,6))
    newnumstr = rename_myself() or newnumstr

    return newnumstr

def get_current_number():
    """Checks the current number of the VM as set in the pretty hostname.
    """
    res = run( ["hostnamectl", "--pretty" , "status"],
               stdout = PIPE,
               universal_newlines = True)

    if not res.stdout.startswith("vm-"):
        return None

    return (res.stdout.rstrip()[3:] or None)


def main():

    newnumstr = rename_myself()

    # An easy way to make this visible is by poking the number in the GECOS field
    # for the training user so it shows up on the panel. And XFCE makes it super easy
    # to force a reload of the info :-)
    # Also we can set the 'pretty' hostname. Setting the static hostname while XFCE is
    # running upsets XFCE. I have modified ~training/.bashrc to use this name in the prompts,
    # if set.
    if newnumstr:
        os.system("sudo chfn -f 'Training {}' training".format(newnumstr))
        os.system("sudo -u training pkill -USR1 xfce4-panel")

        os.system("sudo hostnamectl --pretty set-hostname vm-{}".format(newnumstr))

    print("DONE")

if __name__ == '__main__':
    main()
