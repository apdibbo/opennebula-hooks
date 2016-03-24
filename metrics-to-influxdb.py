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
from ConfigParser import SafeConfigParser

# Read from config file
parser = SafeConfigParser()
try:
   parser.read('/usr/local/etc/influxdb.conf')
   host = parser.get('db', 'host')
   database = parser.get('db', 'database')
   username = parser.get('auth', 'username')
   password = parser.get('auth', 'password')
   instance = parser.get('cloud','instance')
except:
   print 'Unable to read from config file'
   sys.exit(1)

url = 'http://'+host+'/write?db='+database

hostname = gethostname()

datastring=""

with  open("/var/lib/one/.one/one_auth","r") as authfile:
    auth_string = authfile.read().replace('\n','')

server = xmlrpclib.ServerProxy("https://"+hostname+"/RPC2")
response = server.one.user.login(auth_string, "oneadmin", "dontleaveblank", 1000)
sessionid = response[1]
one_auth = "oneadmin:" + sessionid

hostxml = server.one.hostpool.info(one_auth)[1]
host_pool = ET.fromstring(hostxml)

totalallocatedcpu = 0
totalallocatedmem = 0
totalusedcpu = 0
totalusedmem = 0
totalmaxcpu = 0
totalmaxmem = 0
totalvms = 0
metrics = {}
for host in host_pool.findall('HOST'):
    onehost = host.find('NAME').text
    allocatedcpu= int(host.find('HOST_SHARE').find('CPU_USAGE').text)
    allocatedmem= float(host.find('HOST_SHARE').find('MEM_USAGE').text)

    usedcpu= int(host.find('HOST_SHARE').find('USED_CPU').text)
    usedmem= float(host.find('HOST_SHARE').find('USED_MEM').text)

    maxcpu= int(host.find('HOST_SHARE').find('MAX_CPU').text)
 maxmem= float(host.find('HOST_SHARE').find('MAX_MEM').text)

    vms = int(host.find('HOST_SHARE').find('RUNNING_VMS').text)
    metrics[onehost] = {}
    metrics[onehost]['cpu_allocated'] = allocatedcpu
    metrics[onehost]['cpu_used'] = usedcpu
    metrics[onehost]['mem_allocated'] = allocatedmem
    metrics[onehost]['mem_used'] = usedmem
    metrics[onehost]['vms'] = vms

    totalallocatedcpu = totalallocatedcpu + allocatedcpu
    totalallocatedmem = totalallocatedmem + allocatedmem
    totalusedcpu = totalusedcpu + usedcpu
    totalusedmem = totalusedmem + usedmem
    totalmaxcpu = totalmaxcpu + maxcpu
    totalmaxmem = totalmaxmem + maxmem
    totalvms = totalvms + vms

metrics['total'] = {}
metrics['total']['cpu_allocated'] = totalallocatedcpu
metrics['total']['cpu_used'] = totalusedcpu
metrics['total']['mem_allocated'] = totalallocatedmem
metrics['total']['mem_used'] = totalusedmem
metrics['total']['cpu_allocated%'] = totalallocatedcpu * 100 / totalmaxcpu
metrics['total']['mem_allocated%'] = totalallocatedmem * 100 / totalmaxmem
metrics['total']['cpu_used%'] = totalusedcpu * 100 / totalmaxcpu
metrics['total']['mem_used%'] = totalusedmem * 100 / totalmaxmem

metrics['total']['vms'] = totalvms


groupxml = server.one.grouppool.info(one_auth,-2)[1]
group_pool = ET.fromstring(groupxml)
groupmetrics = {}
for group in group_pool.findall('QUOTAS'):
    for groupsearch in group_pool.findall('GROUP'):
        if groupsearch.find('ID').text == group.find('ID').text:
            groupname = groupsearch.find('NAME').text
    if group.find('VM_QUOTA').find('VM') != None:
        groupusedcpu = float(group.find('VM_QUOTA').find('VM').find('CPU_USED').text)
        groupusedmem = float(group.find('VM_QUOTA').find('VM').find('MEMORY_USED').text)
        groupusedvms = int(group.find('VM_QUOTA').find('VM').find('VMS_USED').text)
    else:
        groupusedcpu = 0
        groupusedmem = 0
        groupusedvms = 0
    groupmetrics[groupname] = {}
    groupmetrics[groupname]['cpu_used_group']=groupusedcpu
    groupmetrics[groupname]['memory_used_group']=groupusedmem
    groupmetrics[groupname]['vms_used_group']=groupusedvms

json_metrics = []
for tag in metrics:
    for metric in metrics[tag]:
        json_metric = {
            "measurement" : metric,
            "tags" : { "host" : tag , "region":hostname},
            "fields" : { "value": metrics[tag][metric] }
        }
        json_metrics.append(json_metric)
        datastring +=  metric+",host="+tag+",instance="+instance+" value=" + str(metrics[tag][metric])+"\n"

for tag in groupmetrics:
    for metric in groupmetrics[tag]:
        json_metric = {}
        json_metric["measurement"] = metric
        json_metric["tags"] = { "group" : tag , "region":hostname}
        json_metric["fields"] = { "value" : groupmetrics[tag][metric] }
        json_metrics.append(json_metric)
        datastring +=  metric+",group='"+tag+"',instance="+instance+" value=" + str(groupmetrics[tag][metric])+"\n"

r = requests.post(url,data=datastring,auth=(username,password))
print r.text
print r
                                               
