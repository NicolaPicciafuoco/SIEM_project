#!/bin/sh
echo "Configurazione delle rotte statiche..."

# Da guest_net
ip route add 10.10.1.0/24 via 10.10.1.254 2>/dev/null
ip route add 10.10.2.0/24 via 10.10.1.254 2>/dev/null
ip route add 10.10.3.0/24 via 10.10.1.254 2>/dev/null
ip route add 10.10.4.0/24 via 10.10.1.254 2>/dev/null
ip route add 10.10.5.0/24 via 10.10.1.254 2>/dev/null

# Da mgmt_net
ip route add 10.10.1.0/24 via 10.10.2.254 2>/dev/null
ip route add 10.10.2.0/24 via 10.10.2.254 2>/dev/null
ip route add 10.10.3.0/24 via 10.10.2.254 2>/dev/null
ip route add 10.10.4.0/24 via 10.10.2.254 2>/dev/null
ip route add 10.10.5.0/24 via 10.10.2.254 2>/dev/null

# Da eth_net
ip route add 10.10.1.0/24 via 10.10.3.254 2>/dev/null
ip route add 10.10.2.0/24 via 10.10.3.254 2>/dev/null
ip route add 10.10.3.0/24 via 10.10.3.254 2>/dev/null
ip route add 10.10.4.0/24 via 10.10.3.254 2>/dev/null
ip route add 10.10.5.0/24 via 10.10.3.254 2>/dev/null

# Da server_net
ip route add 10.10.1.0/24 via 10.10.4.254 2>/dev/null
ip route add 10.10.2.0/24 via 10.10.4.254 2>/dev/null
ip route add 10.10.3.0/24 via 10.10.4.254 2>/dev/null
ip route add 10.10.4.0/24 via 10.10.4.254 2>/dev/null
ip route add 10.10.5.0/24 via 10.10.4.254 2>/dev/null

# Da int_net
ip route add 10.10.1.0/24 via 10.10.5.254 2>/dev/null
ip route add 10.10.2.0/24 via 10.10.5.254 2>/dev/null
ip route add 10.10.3.0/24 via 10.10.5.254 2>/dev/null
ip route add 10.10.4.0/24 via 10.10.5.254 2>/dev/null
ip route add 10.10.5.0/24 via 10.10.5.254 2>/dev/null

echo "Rotte configurate:"
ip route
