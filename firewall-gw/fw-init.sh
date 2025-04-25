#!/bin/bash
set -e

# 1) Abilita IP forwarding
sysctl -w net.ipv4.ip_forward=1

# 2) Pulisci tutte le regole
iptables -F
iptables -X
iptables -t nat -F

# 3) Policy di default
iptables -P INPUT   DROP
iptables -P OUTPUT  DROP
iptables -P FORWARD DROP

# 4) Loopback e ICMP di controllo
iptables -A INPUT   -i lo    -j ACCEPT
iptables -A OUTPUT  -o lo    -j ACCEPT
iptables -A INPUT   -p icmp  -j ACCEPT
iptables -A OUTPUT  -p icmp  -j ACCEPT

# 5) Connessioni ESTABLISHED,RELATED (prima di ogni REJECT)
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 6) Intra-subnet
iptables -A FORWARD -s 10.10.1.0/24 -d 10.10.1.0/24 -j ACCEPT
iptables -A FORWARD -s 10.10.2.0/24 -d 10.10.2.0/24 -j ACCEPT
iptables -A FORWARD -s 10.10.3.0/24 -d 10.10.3.0/24 -j ACCEPT
iptables -A FORWARD -s 10.10.4.0/24 -d 10.10.4.0/24 -j ACCEPT
iptables -A FORWARD -s 10.10.5.0/24 -d 10.10.5.0/24 -j ACCEPT

# 7) Management <-> Ethernet
iptables -A FORWARD -s 10.10.2.0/24 -d 10.10.3.0/24 -j ACCEPT
iptables -A FORWARD -s 10.10.3.0/24 -d 10.10.2.0/24 -j ACCEPT

# 8) Management -> Guest
iptables -A FORWARD -s 10.10.2.0/24 -d 10.10.1.0/24 -j ACCEPT

# 9) Ethernet -> Guest
iptables -A FORWARD -s 10.10.3.0/24 -d 10.10.1.0/24 -j ACCEPT

# 10) Management & Ethernet -> Server
iptables -A FORWARD -s 10.10.2.0/24 -d 10.10.4.0/24 -j ACCEPT
iptables -A FORWARD -s 10.10.3.0/24 -d 10.10.4.0/24 -j ACCEPT

# 11) Guest -> Server
iptables -A FORWARD -s 10.10.1.0/24 -d 10.10.4.0/24 -j ACCEPT

# 12) Internet -> Server
iptables -A FORWARD -s 10.10.5.0/24 -d 10.10.4.0/24 -j ACCEPT

# 13) Blocchi:
#   Guest → Mgmt/Eth/Internet
iptables -A FORWARD -s 10.10.1.0/24 -d 10.10.2.0/24 -j REJECT
iptables -A FORWARD -s 10.10.1.0/24 -d 10.10.3.0/24 -j REJECT
iptables -A FORWARD -s 10.10.1.0/24 -d 10.10.5.0/24 -j REJECT

#   Internet → Guest/Mgmt/Eth
iptables -A FORWARD -s 10.10.5.0/24 -d 10.10.1.0/24 -j REJECT
iptables -A FORWARD -s 10.10.5.0/24 -d 10.10.2.0/24 -j REJECT
iptables -A FORWARD -s 10.10.5.0/24 -d 10.10.3.0/24 -j REJECT

# 14) # NAT per permettere routing
iptables -t nat -A POSTROUTING -j MASQUERADE

# 15) Mantieni vivo il container
tail -f /dev/null
