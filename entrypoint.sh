#!/bin/bash

# Abilita il forwarding lato container (utile per testare catene locali)
echo 1 > /proc/sys/net/ipv4/ip_forward

#  Aggiunge route statiche verso tutte le reti tramite il firewall-gw
ip route add 172.28.10.0/24 via 172.28.10.244 dev eth0 2>/dev/null
ip route add 172.28.20.0/24 via 172.28.20.244 dev eth0 2>/dev/null
ip route add 172.29.0.0/24 via 172.29.0.244 dev eth0 2>/dev/null

#  Mantiene il container attivo
exec "$@"
