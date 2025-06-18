# core-server/Dockerfile
FROM nginx:alpine

# 1) Installa tool di rete, Postgres e su-exec
RUN apk add --no-cache \
    iputils traceroute libcap \
    postgresql postgresql-contrib \
    su-exec \
    php82 php82-fpm php82-pdo_pgsql

# 2) Imposta variabili ambiente per Postgres
ENV PGDATA=/var/lib/postgresql/data \
    PGHOST=127.0.0.1 \
    PGPORT=5432

RUN sed -i 's|^listen = .*|listen = 127.0.0.1:9000|' /etc/php82/php-fpm.d/www.conf

# 3a) Copia config Nginx e script PHP
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf
COPY query.php /usr/share/nginx/html/query.php

# 3) Copia script di init e di avvio
COPY start.sh /start.sh
COPY db_init /docker-entrypoint-initdb.d
COPY pg_hba.conf /docker-entrypoint-initdb.d/pg_hba.conf
# init-routes.sh lo monteremo via volume nel docker-compose

RUN mkdir -p /var/log/postgresql && \
mkdir -p var/log/queries && \
chown postgres:postgres /var/log/postgresql && \
chown nobody:nobody /var/log/queries && \
chmod 755 /var/log/queries && \
chmod 755 /var/log/postgresql

RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]
