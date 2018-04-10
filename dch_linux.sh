#!/bin/bash
#DCH Build

# Listen on external port
sed -i '/ExecStart=/c\ExecStart=/usr/bin/dockerd -H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock' /lib/systemd/system/docker.service
systemctl start docker
systemctl enable docker
#Open firewall for API access
iptables -A INPUT -p tcp --dport 2375 -j ACCEPT
iptables-save > /etc/systemd/scripts/ip4save
