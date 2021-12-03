#!/bin/bash

# Block incoming traffic in the specified port range from a big list of
# IP addresses.
# 
# Download the list of countries you want to block from here:
# https://www.ip2location.com/free/visitor-blocker
# in CIDR format.
# 
# Requirements:
# ipset
# apt-get install ipset
# 
# This creates ipset lists containing 10,000 IPs each to avoid exceeding the
# maximum number of IPs per list and getting an error
# 'ipset v7.1: Hash is full, cannot add more elements'

#STARTPORT=8000
#ENDPORT=9000
PORTS=8100,8300 
INPUTFILE="ips.txt"

IPSET=ipset
IPTABLES=iptables

# For debugging:
#IPSET="echo ipset"
#IPTABLES="echo iptables"

cleanOldRules(){
    $IPTABLES -F
    $IPTABLES -X
    $IPTABLES -t nat -F
    $IPTABLES -t nat -X
    $IPTABLES -t mangle -F
    $IPTABLES -t mangle -X
    $IPTABLES -P INPUT ACCEPT
    $IPTABLES -P OUTPUT ACCEPT
    $IPTABLES -P FORWARD ACCEPT
}
 
# clean old rules
cleanOldRules
 
totalips=`wc -l $INPUTFILE |cut -d\  -f 1`

echo "${totalips} total IPs"

listprefix="countryblock"
listnumber=1
listname="${listprefix}-${listnumber}"

# Create first list
$IPSET destroy $listname
$IPSET create $listname hash:net

i=0
while read line; do 
    i=$((i+1))
    
    if !((i % 10000)); then
        listnumber=$((listnumber+1))
        listname="${listprefix}-${listnumber}"

        echo "Starting new list ${listname} (IP count: ${i}/${totalips})"

        # Create next list
        $IPSET destroy $listname
        $IPSET create $listname hash:net
    fi

    #echo ${i}/${totalips} ${line} ${listname}
    $IPSET add $listname $line;
done < ips.txt

for (( c=1; c<=$listnumber; c++ ))
do  
    listname="${listprefix}-${c}"
    echo "$IPTABLES -I INPUT -p tcp --match multiport --dports $PORTS -m set --match-set $listname src -j DROP"
    $IPTABLES -I INPUT -p tcp --match multiport --dports $PORTS -m set --match-set $listname src -j DROP
done
