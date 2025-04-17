# Usa Ubuntu LTS
FROM ubuntu:22.04

# Evitiamo prompt interattivi
ENV DEBIAN_FRONTEND=noninteractive

# Installiamo iptables e conntrack
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    iptables \
    conntrack \
    iputils-ping \
    iproute2 \
    gawk \
    traceroute \
    && rm -rf /var/lib/apt/lists/*

# Copiamo lo script fw-init.sh e init-routes.sh nella cartella /usr/local/bin
# e diamo i permessi di esecuzione
COPY fw-init.sh /usr/local/bin/fw-init.sh
COPY init-routes.sh /usr/local/bin/init-routes.sh
RUN chmod +x /usr/local/bin/fw-init.sh
RUN chmod +x /usr/local/bin/init-routes.sh

# Abilitiamo l’entrypoint
ENTRYPOINT ["/usr/local/bin/fw-init.sh"]
