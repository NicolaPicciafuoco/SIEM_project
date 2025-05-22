-- core-server/db_init/init.sql

-- 1) Crea gli utenti
--   - siem_user: OWNER del database
--   - siem_admin: può interagire con tutte le tabelle
--   - siem_reader: può interagire solo con la tabella "public"

CREATE USER siem_user WITH ENCRYPTED PASSWORD 'VeryStrongPass0';
CREATE USER siem_admin WITH ENCRYPTED PASSWORD 'AdminPassword0';
CREATE USER siem_reader WITH ENCRYPTED PASSWORD 'ReaderPassword0';

-- 2) Crea il database e ne imposta l’owner
CREATE DATABASE siem OWNER siem_user;

-- 3) Passa al database appena creato
\connect siem

-- 4) Crea le tabelle
CREATE TABLE "public" (
    id SERIAL PRIMARY KEY,
    info TEXT
);

CREATE TABLE "private" (
    id SERIAL PRIMARY KEY,
    secret TEXT
);

-- 5) Privilegi di connessione e schema
-- tutti i ruoli devono poter connettersi e usare lo schema public
GRANT CONNECT ON DATABASE siem TO siem_admin, siem_reader;
GRANT USAGE ON SCHEMA public TO siem_admin, siem_reader;

-- 6) Privilegi per siem_admin (full access)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO siem_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO siem_admin;

-- 7) Privilegi per siem_reader (solo sulla tabella "public")
GRANT SELECT, INSERT, UPDATE, DELETE
    ON TABLE "public" TO siem_reader;
-- per poter inserire, serve anche l’accesso alla sequence del campo serial
GRANT USAGE, SELECT
    ON SEQUENCE "public_id_seq" TO siem_reader;

-- Versione solo lettura "public"

-- 7) Privilegi per siem_reader (solo SELECT sulla tabella "public")
--GRANT SELECT ON TABLE "public" TO siem_reader;
