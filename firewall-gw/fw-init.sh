#!/bin/bash
set -e

ip addr

# Rinomina interfacce
for IFACE in $(ls /sys/class/net/ | grep '^eth'); do
    IP=$(ip -4 addr show dev "$IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    case "$IP" in
        10.10.1.254) ip link set "$IFACE" down && ip link set "$IFACE" name guest0 && ip link set guest0 up ;;
        10.10.2.254) ip link set "$IFACE" down && ip link set "$IFACE" name mgmt0 && ip link set mgmt0 up ;;
        10.10.3.254) ip link set "$IFACE" down && ip link set "$IFACE" name eth0 && ip link set eth0 up ;;
        10.10.4.254) ip link set "$IFACE" down && ip link set "$IFACE" name server0 && ip link set server0 up ;;
        10.10.5.254) ip link set "$IFACE" down && ip link set "$IFACE" name int0 && ip link set int0 up ;;
    esac
done

ip addr

# 1) Abilita IP forwarding
sysctl -w net.ipv4.ip_forward=1

# 2) Pulisci tutte le regole
iptables -F
iptables -X
iptables -t nat -F

# 4) Transparent proxy REDIRECT: tutto il TCP/80 → porta 3128 locale (Squid)
iptables -t nat -A PREROUTING \
    -p tcp --dport 80 \
    -j REDIRECT --to-port 3128

# 5) INPUT: lascia passare le nuove connessioni verso Squid su 3128
iptables -A INPUT \
    -p tcp --dport 3128 \
    -m conntrack --ctstate NEW,ESTABLISHED \
    -j ACCEPT

# 6) INPUT: lascia passare le risposte (ESTABLISHED,RELATED) verso Squid
iptables -A INPUT \
    -m conntrack --ctstate ESTABLISHED,RELATED \
    -j ACCEPT

# 7) OUTPUT: permetti a Squid di aprire nuove connessioni HTTP verso i server
iptables -A OUTPUT \
    -p tcp --dport 80 \
    -m conntrack --ctstate NEW,ESTABLISHED \
    -j ACCEPT

# 8) OUTPUT: permetti a Squid di inviare le risposte ai client
iptables -A OUTPUT \
    -m conntrack --ctstate ESTABLISHED,RELATED \
    -j ACCEPT

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
iptables -t nat -A POSTROUTING -s 10.10.5.0/24 -o int0 -j MASQUERADE

# # 15) Mantieni vivo il container
# tail -f /dev/null

# 16) Avvio servizi di logging e Snort
# Avvia rsyslog in foreground
rsyslogd -n &

# Crea cartella dei log di Snort
mkdir -p /var/log/snort

# Avvia Snort (continua a girare)
exec snort -c /etc/snort/snort.conf -i eth0 -l /var/log/snort