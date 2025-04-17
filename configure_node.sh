#!/bin/bash

# Lista dei nodi
nodes=("node1" "node2" "node3" "node4" "node5" "node6")
# docker exec -it node1  bash -c "ip route add 172.29.0.0/24 via 172.28.10.244 dev eth0"
# Indirizzo del firewall gateway
gw_ip_wifi_G="172.28.10.244"
gw_ip_wifi_M="172.28.20.244"
gw_ip_eth="172.29.0.244"
# Configurazione dei nodi
for node in "${nodes[@]}"; do
    echo "Configurando $node..."

    # Abilitazione IP forwarding
    echo "Abilitando IP forwarding su $node..."
    docker exec -it $node bash -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

    # Aggiunta delle rotte (inverso rispetto alla configurazione dei nodi)
    case $node in
        "node1")
            # Nodo 1: rotta per 172.29.0.0/24 attraverso il firewall-gw
            echo "Aggiungendo rotta per 172.29.0.0/24 e 172.28.0.0/24 su $node..."
            docker exec -it $node bash -c "ip route add 172.29.0.0/24 via $gw_ip_wifi_G dev eth0"
            docker exec -it $node bash -c "ip route add 172.28.20.0/24 via $gw_ip_wifi_G dev eth0"
            ;;

        "node2")
            # Nodo 2: rotta per 172.29.0.0/24 attraverso il firewall-gw
            echo "Aggiungendo rotta per 172.29.0.0/24 su $node..."
            docker exec -it $node bash -c "ip route add 172.29.0.0/24 via $gw_ip_wifi_G dev eth0"
            docker exec -it $node bash -c "ip route add 172.28.20.0/24 via $gw_ip_wifi_G dev eth0"
            ;;
        "node3")
            # Nodo 3: rotta per 172.29.0.0/24 attraverso il firewall-gw
            echo "Aggiungendo rotta per 172.29.0.0/24 su $node..."
            docker exec -it $node bash -c "ip route add 172.29.0.0/24 via $gw_ip_wifi_M dev eth0"
            docker exec -it $node bash -c "ip route add 172.28.10.0/24 via $gw_ip_wifi_M dev eth0"
            ;;
        "node4")
            # Nodo 4: rotta per 172.29.0.0/24 attraverso il firewall-gw
            echo "Aggiungendo rotta per 172.29.0.0/24 su $node..."
            docker exec -it $node bash -c "ip route add 172.29.0.0/24 via $gw_ip_wifi_M dev eth0"
            docker exec -it $node bash -c "ip route add 172.28.10.0/24 via $gw_ip_wifi_M dev eth0"
            ;;
        "node5")
            # Nodo 5: rotta per 172.28.10.0/24 attraverso il firewall-gw
            echo "Aggiungendo rotta per 172.28.10.0/24 su $node..."
            docker exec -it $node bash -c "ip route add 172.28.10.0/24 via $gw_ip_eth dev eth0"
            docker exec -it $node bash -c "ip route add 172.28.20.0/24 via $gw_ip_eth dev eth0"
            ;;
        "node6")
            # Nodo 6: rotta per 172.28.10.0/24 attraverso il firewall-gw
            echo "Aggiungendo rotta per 172.28.10.0/24 su $node..."
            docker exec -it $node bash -c "ip route add 172.28.10.0/24 via $gw_ip_eth dev eth0"
            docker exec -it $node bash -c "ip route add 172.28.20.0/24 via $gw_ip_eth dev eth0"
            ;;
    esac

    # Verifica della configurazione
    echo "Verifica configurazione su $node:"
    docker exec -it $node bash -c "ip route show"
    docker exec -it $node bash -c "cat /proc/sys/net/ipv4/ip_forward"

    echo "Configurazione completata per $node."
    echo "--------------------------------------------------"
done

echo "Configurazione completata per tutti i nodi."
