# APSpawn
AutoSpawning of Wirelress APs with data logging.
Typically when I’m testing a mobile app and it doesn’t respect the set proxy I end up using hostapd.

Wrote this quick script to streamline the process, it asks a series of questions, the values in brackets are the defaults you can just hit enter:

	what interface do we use? [wlan0]
	What range do we use? [172.25.20.1/24]
	What SSID will we use? [TestWifi]
	What Password will we use? [pa55word!!]
	Are you using Nope Proxy DNS? Y/N [N]
	Do you want to redirect 80 and 443 to a remote burp? Y/N [N] <-Only appears if you select N to Nope Proxy
	Do you want a pcap file saved of all wlan0 traffic? Y/N [N]
	Spawning HostAPd process
	Setting interface address
	We are starting DNSMASQ with DNS server

If you answer Y to the Nope proxy question DNSmasq is started without DNS so you need to make sure burp is running with NOPE enabled and the DNS started on your kali box.

If you answer Y to the redirection question it will run DNSmasq with a DNS server and setup iptables rules to redirect 80/443 to a remote hostand port (normally burp)

It also spawns the processes in an xterm window so you can monitor activity.

