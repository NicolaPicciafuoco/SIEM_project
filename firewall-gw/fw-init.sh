#!/bin/bash
set -e

# Abilita il forwarding
sysctl -w net.ipv4.ip_forward=1

# Pulisce le tabelle
iptables -F
iptables -X
iptables -t nat -F

# Default policy
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# Consenti traffico locale e icmp
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A OUTPUT -p icmp -j ACCEPT

# Connessioni già stabilite
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Permetti traffico da tutte le reti verso server_net
iptables -A FORWARD -i guest_net -o server_net -j ACCEPT
iptables -A FORWARD -i mgmt_net -o server_net -j ACCEPT
iptables -A FORWARD -i eth_net -o server_net -j ACCEPT

# Permetti traffico di ritorno da server_net verso tutte le reti
iptables -A FORWARD -i server_net -o guest_net -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i server_net -o mgmt_net -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i server_net -o eth_net -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Permetti traffico intra-subnet (tra container della stessa rete)
iptables -A FORWARD -i guest_net -o guest_net -j ACCEPT
iptables -A FORWARD -i mgmt_net -o mgmt_net -j ACCEPT
iptables -A FORWARD -i eth_net -o eth_net -j ACCEPT

# Permetti ping da mgmt a guest (solo in una direzione)
iptables -A FORWARD -i mgmt_net -o guest_net -p icmp -j ACCEPT
iptables -A FORWARD -i guest_net -o mgmt_net -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Permetti ping da mgmt a eth (solo in una direzione)
iptables -A FORWARD -i mgmt_net -o eth_net -p icmp -j ACCEPT
iptables -A FORWARD -i eth_net -o mgmt_net -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Blocca il traffico ICMP da guest verso mgmt ed eth (i guest non devono fare ping su altre reti)
iptables -A FORWARD -i guest_net -o mgmt_net -p icmp -j REJECT
iptables -A FORWARD -i guest_net -o eth_net -p icmp -j REJECT

# Permetti traffico tra tutte le reti verso core-server (gestito dal firewall)
iptables -A FORWARD -j ACCEPT

# NAT per permettere routing
iptables -t nat -A POSTROUTING -j MASQUERADE

# Mantieni attivo
tail -f /dev/null