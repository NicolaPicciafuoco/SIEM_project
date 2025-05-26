#!/bin/sh
set -e

# 1) Inizializza le rotte
sh /init-routes.sh

# 1.a) Prepara la directory di log esterna e assegna ownership
#chown postgres:postgres /var/log/postgresql
#chmod 755 /var/log/postgresql

# 2) Prepara la directory dati di Postgres
mkdir -p "$PGDATA"
chown -R postgres:postgres "$PGDATA"

# 3) Prepara la directory per socket/lock files
mkdir -p /run/postgresql
chown -R postgres:postgres /run/postgresql

# 4) Initdb al primo avvio
if [ ! -s "$PGDATA/PG_VERSION" ]; then
  su-exec postgres initdb -D "$PGDATA"
fi

# 5) Configura Postgres per ascoltare su tutte le interfacce
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PGDATA/postgresql.conf"
cat >> "$PGDATA/pg_hba.conf" <<EOF
host all all 10.10.1.0/24 md5
host all all 10.10.2.0/24 md5
host all all 10.10.3.0/24 md5
host all all 10.10.5.0/24 md5
EOF

# 5.b) Configura il logging su file e il prefisso con client e PRIORITY
cat >> "$PGDATA/postgresql.conf" <<'EOF'
# ————— Log su file invece che solo su stderr
logging_collector = on
log_destination = 'stderr'
log_directory = '/var/log/postgresql'

# file di log statico
log_filename = 'access.log'

# tronca il file ad ogni riavvio
log_truncate_on_rotation = on
# (opzionale) ruota ogni 1GB
log_rotation_size = 1024MB
# (opzionale) ruota almeno ogni 1 giorno
log_rotation_age = 1d

# Imposta i permessi dei file di log a 0644 (rw-r--r--)
log_file_mode = 0644

# ————— Prefisso di log con timestamp, PID, utente@db, client
log_line_prefix = '%m [%p] %u@%d %r '

# ————— Cosa loggare
log_statement = 'all'
log_min_duration_statement = 500
log_connections = on
log_disconnections = on
log_duration = on
EOF

# 6) Avvia Postgres in background come utente postgres
su-exec postgres postgres -D "$PGDATA" &

# 7) Attendi che sia pronto (check TCP, non socket)
until pg_isready -h "$PGHOST" -p "$PGPORT" -q; do
  echo "Waiting for Postgres..."
  sleep 1
done

# 8) Esegui gli script di init solo al primo avvio
for f in /docker-entrypoint-initdb.d/*.sql; do
  echo "Initializing database with $f"
  su-exec postgres psql -f "$f"
done

# 9a) Avvia PHP-FPM in background
php-fpm82

# 9) Avvia Nginx in primo piano
exec nginx -g 'daemon off;'
