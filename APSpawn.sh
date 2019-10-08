#!/bin/bash
#clean some shit up
killall hostapd > /dev/null 2>&1
killall dnsmasq > /dev/null 2>&1

#make sure we can forward traffic
sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1

echo "what interface do we use? [wlan0]"
read IFACE
if [[ -z "$IFACE" ]]; then
	IFACE="wlan0"
fi
ip link set $IFACE up

echo "What range do we use? [172.25.20.1/24]"
read RANGE
if [[ -z "$RANGE" ]]; then
	RANGE="172.25.20.1/24"
fi

echo "What SSID will we use? [TestWifi]" 
read SSID 
if [[ -z "$SSID" ]]; then
	SSID="TestWifi"
fi

echo "What Password will we use? [pa55w0rd!!]"
read PASS
if [[ -z "$PASS" ]]; then
	PASS="pa55w0rd!!" 
fi

echo "Are you using Nope Proxy DNS? Y/N [N]"
read NOPE
if [[ -z "$NOPE" ]]; then
	NOPE="N"
fi

if [[ "$NOPE" = "N" ]];then
	echo "Do you want to redirect 80 and 443 to a remote burp? Y/N [N]"
	read REDIRECT
	if [[ -z "$REDIRECT" ]]; then
		REDIRECT="N"
	fi
fi
if [[ "$REDIRECT" == "Y" ]]; then
	echo "Where are we sending 80 and 443 to?  <IP>:<port>"
	read REMOTE
fi

echo "Do you want a pcap file saved of all $IFACE traffic? Y/N [N]"
read PCAP
if [[ -z "$PCAP" ]]; then
	PCAP="N"
fi

read -r -d '' CONFIG << EOM
interface=wlan0
driver=nl80211
ssid=$SSID
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$PASS
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOM

echo "$CONFIG" > /tmp/hostapd.conf
echo "Spawning HostAPd process"
xterm -e "/usr/sbin/hostapd /tmp/hostapd.conf"&

echo "Setting interface address"
#flush existing addresses
ip addr flush $IFACE
#find out our broadcast
BCAST=$(ipcalc $RANGE -n -b | grep Broadcast | cut -d' ' -f 2)
#find our range
DHCPRANGE=$(echo $RANGE | cut -d'.' -f 1,2,3)"."
DHCPRANGE=$DHCPRANGE"100,"$DHCPRANGE"200,12h"
ip addr add $RANGE broadcast $BCAST dev $IFACE

#if we are running nope proxy ignore the DNS options
if [[ "$NOPE" == "Y" ]];then
	echo "We are starting DNSMASQ without any DNS, make sure you are running NOPE Proxys DNS server"
	xterm -e  "dnsmasq -d -D -b -R -f -E -s PTPLAN -i $IFACE  -F $DHCPRANGE"&
else
	echo "We are starting DNSMASQ with DNS server"
	xterm -e  "dnsmasq -d -D -b -R -f -E -s PTPLAN -i $IFACE -S 1.1.1.1 -F $DHCPRANGE -q "&
fi

#check if we need to iptables 80 and 443

if [[ "$REDIRECT" == "Y" ]];then
	echo "Setting IP tables to redirect 80 and 443 on $IFACE to $REMOTE"
	echo "!!!!Remember to set the burp proxy to invisible mode!!!!"
	iptables -F
	iptables -X
	iptables -t nat -F
	iptables -t nat -X
	iptables -t mangle -F
	iptables -t mangle -X
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -t nat -A  POSTROUTING -o $(route | grep '^default' | grep -o '[^ ]*$') -j MASQUERADE
	iptables -A FORWARD -i $IFACE -j ACCEPT
	iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination $REMOTE
	iptables -t nat -A POSTROUTING -p tcp --dport 443 -j MASQUERADE
	iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination $REMOTE
	iptables -t nat -A POSTROUTING -p tcp --dport 80 -j MASQUERADE
else
        iptables -F
        iptables -X
        iptables -t nat -F
        iptables -t nat -X
        iptables -t mangle -F
        iptables -t mangle -X
        iptables -P INPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -t nat -A  POSTROUTING -o $(route | grep '^default' | grep -o '[^ ]*$') -j MASQUERADE
        iptables -A FORWARD -i $IFACE -j ACCEPT
fi

if [[ "$PCAP" == "Y" ]];then
	today=`date +%Y-%m-%d.%H:%M:%S` 
	echo "Saving pcap of all traffic on $IFACE to ${today}.pcap "
	xterm -e "tcpdump -i $IFACE -w ${today}.pcap"&
fi

