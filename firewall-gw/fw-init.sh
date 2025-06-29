#!/bin/bash
set -e

ip addr

# 1) Rinomina interfacce
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

# 2) Abilita IP forwarding
sysctl -w net.ipv4.ip_forward=1

# 3) Pulisci tutte le regole
iptables -F
iptables -X
iptables -t nat -F

# 3.1) Mitigazione DoS: rate-limit sulle nuove connessioni TCP SYN
# crea una chain dedicata
iptables -N DOS_FILTER

# lascia passare fino a 100 nuove connessioni al secondo (burst 200), poi scarta
iptables -A DOS_FILTER -m limit --limit 50/second --limit-burst 100 -j RETURN
iptables -A DOS_FILTER -j DROP

# applica il filtro sia all’INPUT che al FORWARD delle connessioni SYN
iptables -I INPUT   -p tcp --syn -j DOS_FILTER
iptables -I FORWARD -p tcp --syn -j DOS_FILTER

# 3.2) Limitazione connessioni per singolo IP
# se un singolo IP apre più di 20 connessioni TCP, rifiuta le nuove
iptables -A INPUT   -p tcp --syn -m connlimit --connlimit-above 20 --connlimit-mask 32 -j REJECT
iptables -A FORWARD -p tcp --syn -m connlimit --connlimit-above 20 --connlimit-mask 32 -j REJECT

# 3.3) Rate-limit ICMP (ping flood)
iptables -A INPUT  -p icmp --icmp-type echo-request -m limit --limit 10/second --limit-burst 20 -j ACCEPT
iptables -A INPUT  -p icmp --icmp-type echo-request -j DROP

# 4) Transparent proxy: intercept HTTP, HTTPS e FTP verso Squid (porta 3128)
iptables -t nat -A PREROUTING -p tcp --dport 80  -j REDIRECT --to-port 3128
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 3128
iptables -t nat -A PREROUTING -p tcp --dport 21  -j REDIRECT --to-port 3128

# 5) INPUT (firewall stesso): lascia passare Squid
iptables -A INPUT  -p tcp --dport 3128 \
    -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 6) OUTPUT (firewall stesso): Squid verso server
iptables -A OUTPUT -p tcp --dport 80  \
    -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 \
    -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --dport 21  \
    -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 7) Default DROP
iptables -P INPUT   DROP
iptables -P OUTPUT  DROP
iptables -P FORWARD DROP

# 8) Loopback e ICMP di base (ping al firewall)
iptables -A INPUT   -i lo    -j ACCEPT
iptables -A OUTPUT  -o lo    -j ACCEPT
iptables -A INPUT   -p icmp  -j ACCEPT
iptables -A OUTPUT  -p icmp  -j ACCEPT

# 9) FORWARD: risposte ESTABLISHED,RELATED
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 10) Intra-subnet
iptables -A FORWARD -s 10.10.1.0/24 -d 10.10.1.0/24 -j ACCEPT
iptables -A FORWARD -s 10.10.2.0/24 -d 10.10.2.0/24 -j ACCEPT
iptables -A FORWARD -s 10.10.3.0/24 -d 10.10.3.0/24 -j ACCEPT
iptables -A FORWARD -s 10.10.4.0/24 -d 10.10.4.0/24 -j ACCEPT
iptables -A FORWARD -s 10.10.5.0/24 -d 10.10.5.0/24 -j ACCEPT

# ——— Guest_net (10.10.1.0/24) ———
# Guest → Server (10.10.4.0/24) solo HTTP/HTTPS/FTP via Squid
iptables -A FORWARD \
    -s 10.10.1.0/24 -d 10.10.4.0/24 \
    -p tcp -m multiport --dports 80,443,21 \
    -j ACCEPT
# Guest → Server solo ping
iptables -A FORWARD \
    -s 10.10.1.0/24 -d 10.10.4.0/24 \
    -p icmp --icmp-type echo-request -j ACCEPT

# blocca tutto il resto da Guest
iptables -A FORWARD -s 10.10.1.0/24 -j REJECT

# ——— Management_net (10.10.2.0/24) ———
# Mgmt → Server solo HTTP/HTTPS/FTP
iptables -A FORWARD \
    -s 10.10.2.0/24 -d 10.10.4.0/24 \
    -p tcp -m multiport --dports 80,443,21 \
    -j ACCEPT
# Mgmt → Server solo ping
iptables -A FORWARD \
    -s 10.10.2.0/24 -d 10.10.4.0/24 \
    -p icmp --icmp-type echo-request -j ACCEPT

# Blocca tutto il resto da Mgmt
iptables -A FORWARD -s 10.10.2.0/24 -j REJECT

# ——— Ethernet_net (10.10.3.0/24) ———
# Eth → Server solo HTTP/HTTPS/FTP
iptables -A FORWARD \
    -s 10.10.3.0/24 -d 10.10.4.0/24 \
    -p tcp -m multiport --dports 80,443,21 \
    -j ACCEPT
# Eth → Guest e Mgmt e Server solo ping
iptables -A FORWARD \
    -s 10.10.3.0/24 -d 10.10.1.0/24 \
    -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD \
    -s 10.10.3.0/24 -d 10.10.2.0/24 \
    -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD \
    -s 10.10.3.0/24 -d 10.10.4.0/24 \
    -p icmp --icmp-type echo-request -j ACCEPT

# blocca tutto il resto da Eth
iptables -A FORWARD -s 10.10.3.0/24 -j REJECT

# ——— Internet_net (10.10.5.0/24) ———
# Internet → Server solo HTTP/HTTPS/FTP
iptables -A FORWARD \
    -s 10.10.5.0/24 -d 10.10.4.0/24 \
    -p tcp -m multiport --dports 80,443,21 \
    -j ACCEPT
# Internet → Server solo ping
iptables -A FORWARD \
    -s 10.10.5.0/24 -d 10.10.4.0/24 \
    -p icmp --icmp-type echo-request -j ACCEPT

# blocca tutto il resto da Internet
iptables -A FORWARD -s 10.10.5.0/24 -j REJECT

# Da server a PEP (HTTP/HTTPS)
iptables -A FORWARD -s 10.10.4.0/24 -d 10.10.3.0/24 -p tcp --dport 5000 -j ACCEPT
iptables -A FORWARD -s 10.10.4.0/24 -d 10.10.3.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -s 10.10.4.0/24 -d 10.10.3.0/24 -p icmp --icmp-type echo-reply -j ACCEPT

# Da PEP a server (HTTP/HTTPS)
iptables -A FORWARD -s 10.10.3.222 -d 10.10.4.0/24 -p tcp -j ACCEPT
iptables -A FORWARD -s 10.10.3.222 -d 10.10.4.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -s 10.10.3.222 -d 10.10.4.0/24 -p icmp --icmp-type echo-reply -j ACCEPT

# 11) # NAT per permettere routing
iptables -t nat -A POSTROUTING -s 10.10.5.0/24 -o int0 -j MASQUERADE

# 12) Avvio servizi di logging e Snort
# Avvia rsyslog in foreground
#rsyslogd -n &

# Crea cartella dei log di Snort
mkdir -p /var/log/snort
# Avvia Snort (continua a girare)
snort -A fast -c /etc/snort/snort.conf -i guest0  -l /var/log/snort &
snort -A fast -c /etc/snort/snort.conf -i mgmt0   -l /var/log/snort &
snort -A fast -c /etc/snort/snort.conf -i eth0    -l /var/log/snort &
snort -A fast -c /etc/snort/snort.conf -i server0 -l /var/log/snort &
snort -A fast -c /etc/snort/snort.conf -i int0    -l /var/log/snort &

wait  # mantiene il container attivo
