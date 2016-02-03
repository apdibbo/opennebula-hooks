#!/bin/bash

USERID=$1
TEMPLATE=$2

#basic xml parsing
read_dom () {
    local IFS=\>
    read -d \< ENTITY CONTENT
}
LDAPSEARCH="ldapsearch -h <domain> -b <dc> -t sAMAccountName=$USERNAME -x"
DCTEMP=`echo $TEMPLATE | base64 --decode`

echo $DCTEMP >> /tmp/DCTEMP$USERID

while read_dom; do
   if [ "$ENTITY" == "NAME" ]
   then
      USERNAME=$CONTENT
   elif [ "$ENTITY" == "AUTH_DRIVER"  ]
   then
      USERTYPE=$CONTENT
   fi
done < /tmp/DCTEMP$USERID
if [ "$USERTYPE" == "ldap" ]
then
    GIVENNAME=`$LDAPSEARCH | grep givenName`

    DISPLAYNAME=`$LDAPSEARCH | grep displayName`
    EMAILADDRESS=`$LDAPSEARCH | grep mail:`

    TIERONE=`$LDAPSEARCH | grep EscTierAdmin`

    #SCD=`ldapsearch -h FED.CCLRC.AC.UK -b dc=FED,dc=CCLRC,dc=AC,dc=UK -t sAMAccountName=$USERNAME -x | grep 'Esc\|escience\|Cse\|SC\|Hartree'`
    if [ -n "$TIERONE" ]
    then
       oneuser chgrp -v $USERNAME Tier1Users
       oneuser addgroup $USERNAME ScientificComputing
       oneuser delgroup $USERNAME users
       GROUPADDITION="$USERNAME Primary Group set to Tier1Users, added to Scientific Computing Group"
    elif [[ $DISPLAYNAME == *'SC'* ]]
    then
       oneuser chgrp -v $USERNAME ScientificComputing
       oneuser delgroup $USERNAME users
       GROUPADDITION="$USERNAME Primary Group set to Scientific Computing"
    else
       oneuser chgrp -v $USERNAME users
       GROUPADDITION="$USERNAME remains in users"
    fi
else
    ADDITIONALCONTENT="$USERNAME is not an LDAP user, user type is $USERTYPE"
    oneuser chgrp -v $USERNAME users
    GROUPADDITION="$USERNAME remains in users"
fi

mail -s "DEV Cloud - New User $USERNAME" "cloud-support@helpdesk.gridpp.rl.ac.uk"<<EOF
$USERNAME has just signed up to use the DEV Cloud
$DISPLAYNAME
$EMAILADDRESS
$GROUPADDITION
$ADDITIONALCONTENT

EOF
SENDTOADDRESS=`echo $EMAILADDRESS | cut -d ' ' -f 2`
FIRSTNAME=`echo $GIVENNAME | cut -d ' ' -f 2`
echo $SENDTOADDRESS
CONTENT=$(<<EOF
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head><title></title>
</head>
<body>

<p>Hello $FIRSTNAME, </p>

<p>Thank you for signing up for the DEV Cloud</p>

<p>This service provides a private IaaS cloud resource for STFC users.</p>

<p>The terms of service are below, these are subject to change and the most up to date terms of service can be found at https://cloud.stfc.ac.uk/tos</p>

This is a service under continual development. If you are unsure about ANY of the following conditions of use or how they apply to you or your intended use of this service then, BEFORE continuing, please contact the Cloud Service Managers at <a href="mailto:cloud-support@helpdesk.gridpp.rl.ac.uk">cloud-support@helpdesk.gridpp.rl.ac.uk</a> who will be pleased to help.
            <br /><br />
            By continuing to log in you agree to abide by the following conditions of use of this service:
            <ol>
                <li>You MUST comply with Organisational Information Security Policy particularly regarding the Roles and Responsibilities of System Administrators together with familiarising yourself with the supporting policy framework available at <a href="https://staff.stfc.ac.uk/core/security/information/Pages/default.aspx">https://staff.stfc.ac.uk/core/security/information/Pages/default.aspx</a></li>
                <li>You MUST NOT, except by WRITTEN authorization from the Cloud Service Managers, disable or otherwise modify or degrade the configuration of installed system monitoring and management tools including but not limited to that of rsyslog, pakiti, ssh, yum and auto-updating</li>
                <li>You UNDERSTAND that, whilst best effort is made to provide a stable platform, VMs may be subject to interruption and/or data loss at any time without notice (this is a development platform and should not be used for production services)</li>
                <li>With respect to any SOFTWARE that you install you MUST ensure that all applicable license and terms and conditions of use are met </li>
                <li>You MUST NOT use the service in any way related to providing any commercial service or running a private business</li>
                <li>You MUST report any suspected or actual security incident or other misuse of the VM immediately to <a href="mailto:cloud-support@helpdesk.gridpp.rl.ac.uk">cloud-support@helpdesk.gridpp.rl.ac.uk</a> and notify the appropriate STFC security contact by following the procedure at <a href="https://staff.stfc.ac.uk/core/security/information/Pages/Incidents.aspx">https://staff.stfc.ac.uk/core/security/information/Pages/Incidents.aspx</a></li>
                <li>Credentials applicable to the VM (such as X509 host certificate and Kerberos private keys) MUST be obtained through the Cloud Service Managers. You MUST apply and maintain appropriate protection to prevent exposure or misuse for all such credentials and NOT export private keys or take any other action which would prejudice credential re-use in future VM instances.</li>
                <li>You will be informed by email of any changes to these conditions and MUST inform the Cloud Service Managers immediately if you can no longer abide by the updated conditions. The latest conditions of these conditions are available at <a href="https://cloud.stfc.ac.uk/tos">https://cloud.stfc.ac.uk/tos</a></li>
                <li>You AGREE that you can be held liable for any consequences of your failure to abide by these conditions of use including, but not limited to, the possible immediate termination of your VM without notice, reporting to your organisational management and, if thought to be appropriate, necessary law enforcement agencies.</li>
            </ol>



<p>If you have any issues please email cloud-support@helpdesk.gridpp.rl.ac.uk</p>

<p>Welcome aboard</p>

<p>The Cloud Team</p>

</body>
</html>
EOF
)
(
echo "FROM: cloud-support@helpdesk.gridpp.rl.ac.uk";
echo "TO: $SENDTOADDRESS";
echo "Subject: Welcome to the DEV Cloud";
echo "Content-Type: text/html";
echo "MIME-Version: 1.0";
echo "";
echo $CONTENT;
) | sendmail -t
