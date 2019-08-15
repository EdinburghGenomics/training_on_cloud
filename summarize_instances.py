#!/opt/aws/pyvenv/bin/python3
from __future__ import print_function, division, absolute_import

"""Summarize our training instances"""

# CGI debugging
import os
import cgi
import cgitb
if os.access("/var/log/cgi-bin", os.W_OK):
    cgitb.enable(display=0, logdir="/var/log/cgi-bin")
else:
    cgitb.enable()

import json
import botocore.session
import botocore.exceptions

# Firstly, see if the user wants JSON or not and give the server a header.
args = cgi.FieldStorage()
emit_json = args.getvalue('json', '0') != '0'
emit_csv = args.getvalue('csv', '0') != '0'

if emit_json:
    print("Content-Type: application/json\n")
elif emit_csv:
    print("Content-Type: text/plain\n")
else:
    print("Content-Type: text/html\n")

# This will work if aws configure was done correctly...
sesh = botocore.session.Session()

# Prepare to query ec2
try:
    client = sesh.create_client('ec2')
except botocore.exceptions.NoRegionError:
    raise Exception("Botocore raised botocore.exceptions.NoRegionError.\n"
                    "You need to run 'aws configure' and set up the config and access credentials, or else\n"
                    "run this from an account that already has a .aws/config file.")


# This filter is based on the tags. We could also just use the name - see notes.
resp = client.describe_instances(Filters=[dict(Name='tag:Role', Values=['trainingvm'])])

# A bad query raises an exception, so we shouldn't need this
assert resp['ResponseMetadata']['HTTPStatusCode'] == 200

# Now dig out the instances
instances = [ i for r in resp['Reservations'] for i in r['Instances'] ]

# Filter out anything in state 'terminated'
instances = [ i for i in instances if i['State']['Name'] != 'terminated' ]

# We can't convert directly to JSON as there are datetime objects. What we care about is:
#  InstaceID
#  tag:Name
#  tag:trainingvm
#  NetworkInterfaces
#  State

def l_to_d(td):
    """Transform a list of Key/Value dicts to a single dict
    """
    return { i['Key']: i['Value'] for i in td }

i_info = [ dict( InstanceID = i['InstanceId'],
                 Name = l_to_d(i['Tags'])['Name'],
                 VM = l_to_d(i['Tags'])['Name'].split('-')[-1],
                 PrivateName = i['PrivateDnsName'],
                 PublicName = i.get('PublicDnsName'),
                 VNC = (i['PublicDnsName'] + ':1') if i.get('PublicDnsName') else None,
                 State = i['State']['Name'] )
           for i in instances ]

# Check that all names and VM numbers are unique
# FIXME - this happens while the VM's are re-labelling themselves, so
# we should probably have a better error message.
for k in ['Name', 'VM']:
    assert len(set([i[k] for i in i_info])) == len(i_info)

# JSON dump. This will be enough for the thin clients to auto-discover.
if emit_json:
    print(json.dumps(i_info))
elif emit_csv:
    # Or it would be if the thin clients had any JSON parser
    for i in sorted(i_info, key=lambda vm:vm['VM']):
       print("{},{}".format(i['VM'],i['VNC']))
else:

    # HTML print - this will be good for people configuring manually. Classic print-a-table.
    print('''<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
             <html lang="en"> <head>
                <meta http-equiv="content-type" content="text/html; charset=utf-8">
                <title>Edinburgh Genomics Training VMs</title>
                <link rel="shortcut icon" href="https://genomics.ed.ac.uk/sites/default/files/tab_0.png" type="image/png" />
                <style type="text/css" media="all">
                    @import url("https://genomics.ed.ac.uk/modules/system/system.base.css?pjz6w4");
                    @import url("https://genomics.ed.ac.uk/modules/system/system.theme.css?pjz6w4");
                </style>
             </head>
             <body>
             <h1>Edinburgh Genomics Training VMs</h1>

             <table style="min-width:600px">
                <tr><th>VM Number</th><th>Current VNC Address</th><th>State</th></tr>
          ''')

    for vm in sorted(i_info, key=lambda vm:vm['VM']):
        print('''
             <tr><td>{}</td><td><pre>{}</pre></td><td>{}</td></tr>'''.format(
                     cgi.escape(vm['VM']),
                                cgi.escape(vm['VNC']) if vm['VNC'] else '<em>Unavailable</em>',
                                           cgi.escape(vm['State']) ))

    print("</table> </body> </html>")

