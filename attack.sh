#!/bin/bash

TARGET_SERVER_IP="10.10.4.100"

ATTACKER_CONTAINERS=("mgmt1" "eth1" "internet")

SCAN_SCRIPT_PATH="/attacker-scripts/scan_dirs.sh"

echo "--- Avvio della simulazione di attacco manuale ---"
echo "Server Target: ${TARGET_SERVER_IP}"
echo "Attaccanti designati: ${ATTACKER_CONTAINERS[@]}"
echo "Script di scansione: ${SCAN_SCRIPT_PATH} (nel container)"
echo "-------------------------------------------------"


execute_command_in_container() {
    CONTAINER_NAME=$1
    COMMAND_TO_RUN=$2

    echo ""
    echo "--> Eseguendo su container: ${CONTAINER_NAME}"
    echo "    Comando: ${COMMAND_TO_RUN}"
    echo "--- Output del comando ---"


    docker exec "${CONTAINER_NAME}" sh -c "${COMMAND_TO_RUN}" || true



    echo "--- Fine Output ---"
    echo "<-- Fine esecuzione su ${CONTAINER_NAME}"
    echo "-------------------------------------------------"
}

echo "### Fase 1: Scan Nmap  ###"
for container in "${ATTACKER_CONTAINERS[@]}"; do
    execute_command_in_container "${container}" "nmap ${TARGET_SERVER_IP}"
done

echo ""
echo "### Fase 2: Scansione Directory (${TARGET_SERVER_IP}  ###"
for container in "${ATTACKER_CONTAINERS[@]}"; do
    execute_command_in_container "${container}" "sh ${SCAN_SCRIPT_PATH}"
done

 Esempio 3: Ping al server target da ogni container attaccante
 echo ""
 echo "### Fase 3: Ping al Server ###"
 for container in "${ATTACKER_CONTAINERS[@]}"; do
     execute_command_in_container "${container}" "ping -c 4 ${TARGET_SERVER_IP}"
 done

echo ""
echo "--- Simulazione di attacco manuale completata ---"