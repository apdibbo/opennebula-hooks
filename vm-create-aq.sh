#!/bin/bash
ID=$1
TEMPLATE=$2

echo $ID
vmtemplate=`onevm show $ID`
curl_cmd='/usr/bin/curl -s --negotiate -u : --capath /etc/grid-security/certificates/ -XPOST'
url_prefix='https://aquilon.gridpp.rl.ac.uk/private/aqd.cgi'

TEMPLATE=`onevm show -x $ID`
echo $TEMPLATE > /tmp/vmcreate$ID
IP=`xpath /tmp/vmcreate$ID "VM/TEMPLATE/NIC/IP/text()"`
hostname=`curl -s http://aquilon.gridpp.rl.ac.uk:6901/find/host?ip=$IP`
echo $hostname
kinit -k HTTP/<hostname>


if [[ $vmtemplate == *'AQ_SANDBOX'* ]] ;
then
    aqsandbox=`onevm show $ID | grep AQ_SANDBOX | sed 's/  //g' | sed 's/,//g' | sed 's/AQ_SANDBOX="//g' | sed 's/"//g' | sed 's/\//%2F/g'`
    echo $aqsandbox
    sandbox='sandbox'
    counter=0
    while  [[ $sandbox != *"No data"* ]] && [[ $sandbox != "" ]] && [ $counter -lt 5 ] ;
    do
        sandbox=`$curl_cmd "$url_prefix/command/manage_hostname?hostname=$hostname&sandbox=$aqsandbox&force=true"`
        counter=$((counter+1))
        if [[ $sandbox == *"No data"* ]] || [[ $sandbox == "" ]];
        then
            kinit -k HTTP/<hostname>
        fi

    done
    if [ $counter -eq 5 ] ;
    then
        logger "ONEHOOK - VM:$ID - VM Creation - AQ Sandbox Failed"
    else
        logger "ONEHOOK - VM:$ID - VM Creation - AQ Sandbox Assigned"
    fi

    echo $sandbox

fi

if [[ $vmtemplate == *'AQ_ARCHETYPE'* ]] ;
then
    aqarchetype=`onevm show $ID | grep AQ_ARCHETYPE | sed 's/  //g' | sed 's/,//g' | sed 's/AQ_ARCHETYPE="//g' | sed 's/"//g'`
fi
if [[ $vmtemplate == *'AQ_PERSONALITY'* ]] ;
then
    aqpersonality=`onevm show $ID | grep AQ_PERSONALITY | sed 's/  //g' | sed 's/,//g' | sed 's/AQ_PERSONALITY="//g' | sed 's/"//g'`
    personality='personality'
    echo $aqpersonality
    counter=0
    if [[ $vmtemplate == *'AQ_OS'* ]] ;
    then
        aqos=`onevm show $ID | grep AQ_OS | sed 's/  AQ_OS="//g' | sed 's/",//g'`
        while [[ $personality != *"No data"* ]] && [[ $personality != "" ]] && [ $counter -lt 5 ] ;
        do
            if [[ $vmtemplate == *'AQ_ARCHETYPE'* ]] ;
            then
                personality=`$curl_cmd "$url_prefix/host/$hostname/command/make?personality=$aqpersonality&osversion=$aqos&archetype=$aqarchetype"`
            else
                personality=`$curl_cmd "$url_prefix/host/$hostname/command/make?personality=$aqpersonality&osversion=$aqos"`
            fi
            counter=$((counter+1))
            if [[ $personality == *"No data"* ]] || [[ $personality == "" ]];
            then
                kinit -k HTTP/dev-hn1.nubes.rl.ac.uk
            fi

        done
        if [ $counter -eq 5 ] ;
        then
            logger "ONEHOOK - VM:$ID - VM Creation - AQ Personality&OS Failed"
        else
            logger "ONEHOOK - VM:$ID - VM Creation - AQ Personality&OS Assigned"
        fi

    else
        while [[ $personality != *"No data"* ]] && [[ $personality != "" ]]  && [ $counter -lt 5 ] ;
        do
            if [[ $vmtemplate == *'AQ_ARCHETYPE'* ]] ;
            then
                personality=`$curl_cmd "$url_prefix/host/$hostname/command/make?personality=$aqpersonality&archetype=$aqarchetype"`
            else
                personality=`$curl_cmd "$url_prefix/host/$hostname/command/make?personality=$aqpersonality"`
            fi
            counter=$((counter+1))
        done
        if [ $counter -eq 5 ] ;
        then
            logger "ONEHOOK - VM:$ID - VM Creation - AQ Personality Failed"
        else
            logger "ONEHOOK - VM:$ID - VM Creation - AQ Personality Assigned"
        fi
    fi
    echo $personality
fi

if [[ $vmtemplate == *'AQ_OS'* ]] ;
then
    personality='personality'
    aqos=`onevm show $ID | grep AQ_OS | sed 's/  AQ_OS="//g' | sed 's/",//g'`
    counter=0
    while [[ $personality != *"No data"* ]] && [[ $personality != "" ]] && [ $counter -lt 5 ] ;
    do
        personality=`$curl_cmd "$url_prefix/host/$hostname/command/make?osversion=$aqos"`
        counter=$((counter+1))
    done
    echo $personality
fi


rm -f /tmp/vmcreate$ID
