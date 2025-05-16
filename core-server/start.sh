#!/bin/sh
set -e

# 1) Inizializza le rotte
sh /init-routes.sh

# 2) Prepara la directory dati di Postgres
mkdir -p /var/lib/postgresql/data
chown -R postgres:postgres /var/lib/postgresql

# 3) Initdb al primo avvio
if [ ! -s /var/lib/postgresql/data/PG_VERSION ]; then
  su postgres -c "initdb -D /var/lib/postgresql/data"
fi

# 4) Abilita l'ascolto su tutte le interfacce e accesso dalla subnet Docker
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/postgresql/data/postgresql.conf
echo "host all all 10.10.4.0/24 md5" >> /var/lib/postgresql/data/pg_hba.conf

# 5) Avvia Postgres in background
su postgres -c "postgres -D /var/lib/postgresql/data &"

# 6) Attendi che sia pronto
until su postgres -c "pg_isready"; do
  echo "Waiting for Postgres..."
  sleep 1
done

# 7) Esegui gli script di init
for f in /docker-entrypoint-initdb.d/*.sql; do
  su postgres -c "psql -f $f"
done

# 8) Avvia Nginx in primo piano
nginx -g 'daemon off;'
