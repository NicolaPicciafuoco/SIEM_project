# core-server/Dockerfile
FROM nginx:alpine

# 1) Installa tool di rete, Postgres e su-exec
RUN apk add --no-cache \
    iputils traceroute libcap \
    postgresql postgresql-contrib \
    su-exec

# 2) Imposta variabili ambiente per Postgres
ENV PGDATA=/var/lib/postgresql/data \
    PGHOST=127.0.0.1 \
    PGPORT=5432

# 3) Copia script di init e di avvio
COPY start.sh /start.sh
COPY db_init /docker-entrypoint-initdb.d
# init-routes.sh lo monteremo via volume nel docker-compose

RUN mkdir -p /var/log/postgresql && \
chown postgres:postgres /var/log/postgresql && \
chmod 755 /var/log/postgresql

RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]
