# Usa Ubuntu LTS
FROM ubuntu:22.04

# Evitiamo prompt interattivi
ENV DEBIAN_FRONTEND=noninteractive

# Installiamo iptables e conntrack
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        snort \
        rsyslog \
        curl \
        iptables \
        conntrack \
        iputils-ping \
        iproute2 \
        gawk \
        traceroute \
        ca-certificates \
        python3 \
        python3-pip \
        ipset \
    && python3 -m pip install flask


# Copiamo lo script fw-init.sh e init-routes.sh nella cartella /usr/local/bin
# e diamo i permessi di esecuzione
COPY rsyslog-snort.conf /etc/rsyslog.d/90-snort.conf
COPY fw-init.sh /usr/local/bin/fw-init.sh
COPY init-routes.sh /usr/local/bin/init-routes.sh

# Copia il file di configurazione snort.conf nel container
RUN mkdir -p /etc/snort && \
    rm -f /etc/snort/snort.conf  
# Rimuove qualsiasi file presente per evitare conflitti

# Copia il file di configurazione squid.conf nel container
RUN mkdir -p /etc/squid && \
    rm -f /etc/squid/squid.conf

RUN chmod +x /usr/local/bin/fw-init.sh
RUN chmod +x /usr/local/bin/init-routes.sh

# Creiamo la directory dei log di Snort e cambiamo proprietà e permessi
RUN mkdir -p /var/log/snort && \
    chown root:root /var/log/snort && \
    chmod 755 /var/log/snort

# Creiamo la directory dei log di Squid e cambiamo proprietà e permessi
RUN mkdir -p /var/log/squid && \
    chown root:root /var/log/squid && \
    chmod 755 /var/log/squid

# Abilitiamo l’entrypoint
ENTRYPOINT ["/usr/local/bin/fw-init.sh"]
# # CMD ["sh", "-c", "/usr/local/bin/fw-init.sh && snort -A console -c /etc/snort/snort.conf -i eth0"]
# CMD ["sh", "-c", "/usr/local/bin/fw-init.sh && service rsyslog start && snort -c /etc/snort/snort.conf -i eth0"]

# PDP Setup

COPY pdp.py /usr/local/bin/
CMD ["sh", "-c", "snort -c /etc/snort/snort.conf -i any & python3 /usr/local/bin/pdp.py"]