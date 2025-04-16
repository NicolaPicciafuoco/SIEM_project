# firewall-gw/Dockerfile

FROM ubuntu:22.04

RUN apt update && apt install -y \
    iptables iproute2 net-tools curl rsyslog

COPY init-rules.sh /init-rules.sh
RUN chmod +x /init-rules.sh

CMD ["/init-rules.sh"]
