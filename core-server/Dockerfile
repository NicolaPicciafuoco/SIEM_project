# core-server/Dockerfile
FROM nginx:alpine

# 1) Installa tool di rete e Postgres
RUN apk add --no-cache \
      iputils traceroute libcap \
      postgresql postgresql-contrib

# 2) Copia script di init e rotte
COPY start.sh /start.sh
COPY db_init /docker-entrypoint-initdb.d
# init-routes.sh lo monteremo via volume

RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]
