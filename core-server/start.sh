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
  su-exec postgres initdb \
    --auth-local=trust \
    --auth-host=md5 \
    -D "$PGDATA"

  # sovrascrivo subito l’intero pg_hba.conf
  cp /docker-entrypoint-initdb.d/pg_hba.conf "$PGDATA/pg_hba.conf"
  chown postgres:postgres "$PGDATA/pg_hba.conf"
  chmod 600 "$PGDATA/pg_hba.conf"
fi

# 5) Configura Postgres per ascoltare su tutte le interfacce
sed -i "s/^#\?listen_addresses.*/listen_addresses = '*'/" "$PGDATA/postgresql.conf"


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

# 6) Avvio Postgres e aspetto che sia pronto
su-exec postgres postgres -D "$PGDATA" & 
until pg_isready -q; do sleep 1; done

# 8) Esegui gli script di init (via socket Unix, che è in trust)
for f in /docker-entrypoint-initdb.d/*.sql; do
  echo "Initializing database with $f"
  su-exec postgres psql \
    -h /run/postgresql \
    -U postgres \
    -d postgres \
    -f "$f"
done

# 9a) Avvia PHP-FPM in background
php-fpm82

# 9) Avvia Nginx in primo piano
exec nginx -g 'daemon off;'
