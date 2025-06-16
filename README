- [SIEM Project](#siem-project)
  - [🔎 Overview](#-overview)
  - [🚀 Prerequisites](#-prerequisites)
  - [🛠️ Installation and Startup](#️-installation-and-startup)
      - [1. Download the Code](#1-download-the-code)
      - [2. Run the Project](#2-run-the-project)
  - [🖥️ Useful Commands](#️-useful-commands)
      - [1. Run a Test Database Query from an arbitrary Client (*For Example Guest1*)](#1-run-a-test-database-query-from-an-arbitrary-client-for-example-guest1)


# SIEM Project

A containerized Security Information and Event Management (SIEM) system integrating firewalling, IDS, transparent proxy, policy enforcement/decision points, and an indexing engine to deliver a complete **Zero-Trust** architecture.

## 🔎 Overview

This project demonstrates a modular, Docker Compose–orchestrated architecture in which:

- **firewall-gw** applies `iptables` rules, NAT/MASQUERADE, and runs Snort for both the *data plane* and the *control plane*.  
- **squid** acts as a transparent HTTP/HTTPS/FTP proxy with ACLs based on URL, time, and subnet.  
- **core-server** hosts Nginx (reverse-proxying to the PEP) and PostgreSQL, with advanced logging and least-privilege execution via `su-exec`.  
- **PEP** (Policy Enforcement Point) receives requests, enriches context, and forwards them to the PDP.  
- **PDP** (Policy Decision Point) queries Splunk, computes a trust score, and returns `ALLOW` or `DENY`.  
- **Splunk** indexes logs from Snort, Squid, PostgreSQL, and PDP, exposes REST APIs to the PDP, and provides dashboards for alerting and reporting.  

All components communicate over five isolated Docker networks (`guest_net`, `mgmt_net`, `eth_net`, `server_net`, `int_net`), each carrying a different trust weight for policy evaluation.

## 🚀 Prerequisites

- **Docker** ≥ 20.10  
- **Docker Compose** ≥ 1.29  
- Create a `.env` file in the project root containing:
  ```bash
    SPLUNK_USERNAME=<your_splunk_username>
    SPLUNK_PASSWORD=<your_splunk_password>
  ```

To install Docker and Docker Compose, follow the official [guide](https://docs.docker.com/compose/install/).

## 🛠️ Installation and Startup

#### 1. Download the Code

    ```bash
    curl -L -o SIEM_project.zip \
    https://github.com/NicolaPicciafuoco/SIEM_project/archive/refs/heads/master.zip

    unzip SIEM_project.zip

    cd SIEM_project-master
    ```

#### 2. Run the Project

From the project root directory, execute:
```bash
docker compose up --build
```

## 🖥️ Useful Commands

#### 1. Run a Test Database Query from an arbitrary Client (*For Example Guest1*)

```bash
  curl -G "http://localhost/query" \
  --data-urlencode "db=<db>" \
  --data-urlencode "user=<user>" \
  --data-urlencode "password=<password>" \
  --data-urlencode "query=SELECT * FROM <db_table>;"
```