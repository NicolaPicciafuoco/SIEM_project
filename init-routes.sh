#!/bin/sh
echo "Configurazione delle rotte statiche..."

# Management ed Ethernet raggiungono Guest tramite il firewall
ip route add 10.10.1.0/24 via 10.10.2.254 2>/dev/null
ip route add 10.10.1.0/24 via 10.10.3.254 2>/dev/null

# Guest raggiunge Management ed Ethernet tramite il firewall
ip route add 10.10.2.0/24 via 10.10.1.254 2>/dev/null
ip route add 10.10.3.0/24 via 10.10.1.254 2>/dev/null

# Management ↔ Ethernet via firewall
ip route add 10.10.3.0/24 via 10.10.2.254 2>/dev/null
ip route add 10.10.2.0/24 via 10.10.3.254 2>/dev/null

echo "Rotte configurate:"
ip route
