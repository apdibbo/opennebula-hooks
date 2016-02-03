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

vmid = sys.argv[1]
print vmid
with  open("/var/lib/one/.one/one_auth","r") as authfile:
    auth_string = authfile.read().replace('\n','')


server = xmlrpclib.ServerProxy("https://"+hostname+"/RPC2")
response = server.one.user.login(auth_string, "oneadmin", "dontleaveblank", 1000)
sessionid = response[1]
one_auth = "oneadmin:" + sessionid

vmxml = server.one.vm.info(one_auth,int(vmid))[1]
vm = ET.fromstring(vmxml)
requiredcpu = int(float(vm.find('TEMPLATE').find('CPU').text) * 100 )
requiredmem = int(vm.find('TEMPLATE').find('MEMORY').text) * 1024
vnetid = int(vm.find('TEMPLATE').find('NIC').find('NETWORK_ID').text)
requiredips = 1
vnetxml = server.one.vn.info(one_auth,vnetid)[1]
vnet = ET.fromstring(vnetxml)
leases = 0
usedleases = 0
for ar in vnet.find('AR_POOL').findall('AR'):
    leases = leases + int(ar.find('SIZE').text)
    usedleases = usedleases + int(ar.find('USED_LEASES').text)

freeips = leases - usedleases
print ('FREEIPS = ' + str(freeips))
print ('REQUIRED CPU = '+str(requiredcpu))
print ('REQUIRED MEM = '+str(requiredmem))

hostxml = server.one.hostpool.info(one_auth)[1]
host_pool = ET.fromstring(hostxml)

hostfreeestcpu = 0
hostfreeestmem = 0
hosts = {}
for host in host_pool.findall('HOST'):
    if host.find('STATE').text != '4':
        onehost = host.find('NAME').text
        hostid = host.find('ID').text
        allocatedcpu= int(host.find('HOST_SHARE').find('CPU_USAGE').text)
        maxcpu= int(host.find('HOST_SHARE').find('MAX_CPU').text)
        hostfreecpu = maxcpu - allocatedcpu
        allocatedmem = int(host.find('HOST_SHARE').find('MEM_USAGE').text)
        maxmem = int(host.find('HOST_SHARE').find('MAX_MEM').text)
        hostfreemem = maxmem - allocatedmem
        hostvms = []
        for hostvm in host.find('VMS').findall('ID'):
            hostvms.append(int(hostvm.text))
        hosts[hostid]={ 'NAME':onehost, 'FREECPU':hostfreecpu, 'FREEMEM':hostfreemem, 'VMS':hostvms}
        print ("FreeCPU = "+ str( hostfreecpu))
        print ("FreeMem = "+ str(hostfreemem))
        if hostfreecpu > hostfreeestcpu:
            hostfreeestcpu= hostfreecpu
        if hostfreemem > hostfreeestmem:
            hostfreeestmem= hostfreemem
        if hostfreecpu >= requiredcpu and hostfreemem >= requiredmem and freeips >= requiredips:
            print onehost
            break
print (hosts)
freeableips = 0
if hostfreeestcpu < requiredcpu or hostfreeestmem < requiredmem or freeips < requiredips:
    for host in hosts:
        freeableips = 0
        print host
        freeablecpu = hosts[host]['FREECPU']
        freeablemem = hosts[host]['FREEMEM']
        print('FREEABLE CPU = '+ str(freeablecpu))
        print('FREEABLE MEM = '+ str(freeablemem))
        preemptablevms = []
        for vm in hosts[host]['VMS']:
            hostvmxml = server.one.vm.info(one_auth,int(vm))[1]
            hostvm = ET.fromstring(hostvmxml)
            if  hostvm.find('USER_TEMPLATE').find('PREEMPTABLE') != None and hostvm.find('STATE').text == '3' and hostvm.find('LCM_STATE').text == '3':
                freeablecpu = freeablecpu + int(float(hostvm.find('TEMPLATE').find('CPU').text) * 100)
                freeablemem = freeablemem + (int(hostvm.find('TEMPLATE').find('MEMORY').text) * 1024)
                freeableips = freeableips + 1

                print('FREEABLE CPU = '+ str(freeablecpu))
                print('FREEABLE MEM = '+ str(freeablemem))
                preemptablevms.append(vm)
                if freeablecpu >= requiredcpu and freeablemem >= requiredmem:
                    break
        print('FREEABLE CPU = '+ str(freeablecpu))
        print('FREEABLE MEM = '+ str(freeablemem))
        if freeablecpu >= requiredcpu and freeablemem >= requiredmem and freeableips >= requiredips:
            for vm in preemptablevms:
                deleteresponse = server.one.vm.action(one_auth,'shutdown-hard',int(vm))
            print "space created"
            print vm
            break


