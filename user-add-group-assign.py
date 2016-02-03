#!/usr/bin/python
from ConfigParser import SafeConfigParser
import xmlrpclib
import urllib2
import urllib
from xml.etree import ElementTree
import xml.etree.ElementTree as ET
import logging
import requests
import subprocess
import sys
from socket import gethostname
from requests.auth import HTTPBasicAuth

hostname = gethostname()

userid = sys.argv[1]
with  open("/var/lib/one/.one/one_auth","r") as authfile:
    auth_string = authfile.read().replace('\n','')


server = xmlrpclib.ServerProxy("https://"+hostname+"/RPC2")
response = server.one.user.login(auth_string, "oneadmin", "dontleaveblank", 1000)
sessionid = response[1]
one_auth = "oneadmin:" + sessionid

user_xml =  ET.fromstring(server.one.user.info(one_auth,int(userid))[1])
username = user_xml.find("NAME").text
primary_group = user_xml.find("GNAME").text

groupxml = server.one.grouppool.info(one_auth)[1]
group_pool = ET.fromstring(groupxml)

matched = False

for group in group_pool.findall("GROUP"):
    groupname = group.find("NAME").text
    groupid = group.find("ID").text
    prestaged_users = ""
    if group.find('TEMPLATE/PRESTAGE_USERS') != None :
        print groupname
        print group.find('TEMPLATE/PRESTAGE_USERS').text
        if group.find('TEMPLATE/PRESTAGE_USERS').text:
            for un in group.find("TEMPLATE/PRESTAGE_USERS").text.split():
                if username == un:
                    print(un+" - matched")
                    matched = True
                    if primary_group == "users":
                        updateuser = server.one.user.chgrp(one_auth,int(userid),int(groupid))
                    else:
                        updateuser = server.one.user.addgroup(one_auth,int(userid),int(groupid))
                else:
                    prestaged_users = un + " " + prestaged_users
            if matched:
                updatestring = 'PRESTAGE_USERS="'+prestaged_users+'"'
                print(updatestring)
                updategroup = server.one.group.update(one_auth,int(groupid),updatestring,1)

