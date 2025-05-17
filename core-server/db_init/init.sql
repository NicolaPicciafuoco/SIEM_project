-- core-server/db_init/init.sql

-- 1) Crea l’utente e il database
CREATE USER siem_user WITH ENCRYPTED PASSWORD 'VeryStr0ngP@ss';
CREATE DATABASE siem OWNER siem_user;

-- 2) Passa al database appena creato
\connect siem

-- 3) Crea le tue tabelle
CREATE TABLE "public" (
    id SERIAL PRIMARY KEY,
    info TEXT
);

CREATE TABLE "private" (
    id SERIAL PRIMARY KEY,
    secret TEXT
);
