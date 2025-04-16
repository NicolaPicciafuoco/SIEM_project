#!/bin/bash

# Funzione per recuperare il nome dell'interfaccia tramite l'indirizzo IP assegnato
get_interface_by_ip() {
    ip addr show | awk -v ip="$1" '$0 ~ ip {print $NF; exit}'
}

# Recupera le interfacce relative alle reti configurate dal docker-compose
IF_WIFI_GUEST=$(get_interface_by_ip "172.28.10.244")
IF_WIFI_MGMT=$(get_interface_by_ip "172.28.20.244")
IF_ETHERNET=$(get_interface_by_ip "172.29.0.244")

# L'interfaccia Internet è la stessa della route di default
IF_INTERNET=$(ip route show default | awk '/default/ {print $5}')

echo "Interfaccia wifi_guest: $IF_WIFI_GUEST"
echo "Interfaccia wifi_mgmt: $IF_WIFI_MGMT"
echo "Interfaccia ethernet: $IF_ETHERNET"
echo "Interfaccia internet: $IF_INTERNET"

# Abilitiamo il forwarding IP
echo 1 > /proc/sys/net/ipv4/ip_forward

# Pulizia regole precedenti
iptables -F
iptables -t nat -F
iptables -X

# Impostazione della politica default per il FORWARD: DROP
iptables -P FORWARD DROP

# Regola di logging per il traffico nella catena FORWARD
iptables -A FORWARD -j LOG --log-prefix "IPTables-FORWARD: " --log-level 4

# Accettiamo il traffico sul loopback
iptables -A INPUT -i lo -j ACCEPT

# Blocchiamo il traffico dal wifi_guest verso wifi_mgmt ed ethernet
iptables -A FORWARD -i "$IF_WIFI_GUEST" -o "$IF_WIFI_MGMT" -j DROP
iptables -A FORWARD -i "$IF_WIFI_GUEST" -o "$IF_ETHERNET" -j DROP

# Blocchiamo il traffico dal wifi_mgmt verso ethernet
iptables -A FORWARD -i "$IF_WIFI_MGMT" -o "$IF_ETHERNET" -j DROP

# Accettiamo il traffico intra-rete (es. ping, traffico tra istanze sulla stessa interfaccia)
iptables -A FORWARD -i "$IF_WIFI_GUEST" -o "$IF_WIFI_GUEST" -j ACCEPT
iptables -A FORWARD -i "$IF_WIFI_MGMT" -o "$IF_WIFI_MGMT" -j ACCEPT
iptables -A FORWARD -i "$IF_ETHERNET" -o "$IF_ETHERNET" -j ACCEPT

# Permetti il traffico verso il server (IP 172.29.0.100) da tutte le reti
iptables -A FORWARD -d 172.29.0.100 -j ACCEPT

# Ethernet può raggiungere tutti
iptables -A FORWARD -i "$IF_ETHERNET" -j ACCEPT

# NAT per accesso a internet
iptables -t nat -A POSTROUTING -o "$IF_INTERNET" -j MASQUERADE

# Permettiamo il forward verso Internet
iptables -A FORWARD -i "$IF_WIFI_GUEST" -o "$IF_INTERNET" -j ACCEPT
iptables -A FORWARD -i "$IF_WIFI_MGMT" -o "$IF_INTERNET" -j ACCEPT
iptables -A FORWARD -i "$IF_ETHERNET" -o "$IF_INTERNET" -j ACCEPT