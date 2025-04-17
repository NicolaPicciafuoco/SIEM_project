#!/bin/bash

#!/bin/bash

# Abilita l'inoltro dei pacchetti IPv4
echo 1 > /proc/sys/net/ipv4/ip_forward

# Pulizia delle catene esistenti
iptables -F
iptables -t nat -F
iptables -X

# Imposta la policy di default su ACCEPT (temporaneamente, poi metteremo DROP + regole specifiche)
iptables -P FORWARD ACCEPT
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT

# Permette inoltro tra tutte le interfacce
# (se vuoi restrizioni, le mettiamo nel prossimo step)














# Abilitiamo il forwarding IP
#echo 1 > /proc/sys/net/ipv4/ip_forward
#
## Pulizia regole
#iptables -F
#iptables -t nat -F
#iptables -X
#
## Politica default DROP tra le reti
#iptables -P FORWARD DROP
#
## Accettiamo loopback interno
#iptables -A INPUT -i lo -j ACCEPT
## Permetti il traffico verso il server da tutte le reti
#iptables -A FORWARD -d 172.29.0.100 -j ACCEPT
#
## Accettiamo traffico intra-rete (ping etc.)
#iptables -A FORWARD -i wifi_guest -o wifi_guest -j ACCEPT
#iptables -A FORWARD -i wifi_mgmt -o wifi_mgmt -j ACCEPT
#iptables -A FORWARD -i ethernet -o ethernet -j ACCEPT
#iptables -A FORWARD -i wifi_guest -o ethernet -j ACCEPT
#
#iptables -A FORWARD -i ethernet -o wifi_guest -j ACCEPT
## Ethernet può raggiungere tutti
#iptables -A FORWARD -i ethernet -j ACCEPT
#
#
## Blocchiamo GUEST verso mgmt o ethernet
#iptables -A FORWARD -i wifi_guest -o wifi_mgmt -j DROP
##iptables -A FORWARD -i wifi_guest -o ethernet -j DROP
#
## Blocchiamo MGMT verso ethernet
#iptables -A FORWARD -i wifi_mgmt -o ethernet -j DROP
#
##  NAT per accesso a internet
#iptables -t nat -A POSTROUTING -o internet -j MASQUERADE
#
## Permettiamo il forward verso Internet
#iptables -A FORWARD -i wifi_guest -o internet -j ACCEPT
#iptables -A FORWARD -i wifi_mgmt -o internet -j ACCEPT
#iptables -A FORWARD -i ethernet -o internet -j ACCEPT
