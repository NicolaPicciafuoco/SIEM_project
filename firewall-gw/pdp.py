from flask import Flask, request, jsonify
import subprocess
import ipaddress

# Decision Logging

import logging

# File logging
logging.basicConfig(
    filename='/var/log/pdp.log',
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s >>> %(message)s'
)
logger = logging.getLogger("pdp_logger")

BLOCKLIST_PATH = "/etc/squid/blocked_ips.txt"

app = Flask(__name__)

INTERFACE_WEIGHTS = {
    'mgmt_net': 0.9,
    'server_net': 0.8,
    'eth_net': 0.5,
    'guest_net': 0.3,
    'int_net': 0.1
}

def calculate_score(priority, interface):

    base_score = 100 - (priority - 1) * 25  # 1:100, 2:75, 3:50, 4:25
    return int(base_score * INTERFACE_WEIGHTS.get(interface, 0.5))

@app.route('/evaluate', methods=['POST'])
def evaluate():
    data = request.json
    src_ip = data['src_ip']
    priority = int(data['snort_priority'])
    interface = data.get('interface', 'eth_net')
    score = calculate_score(priority, interface)

    # Enforcement logic
    if score < 60:
        # Block at firewall
        subprocess.run(["ipset", "add", "PDP_BLACKLIST", src_ip])

        # Squid IP Blocklist
        with open(BLOCKLIST_PATH, "r+") as f:
            blocked = set(line.strip() for line in f if line.strip())
            if src_ip not in blocked:
                f.write(f"{src_ip}\n")
                f.flush()

        # Reload Squid
        subprocess.run(["squid", "-k", "reconfigure"])

        decision = "DENY"
    else:
        decision = "ALLOW"

    logger.info(
        f"Decision: {decision} | src_ip=: {src_ip} | priority: {priority} | "
        f"interface: {interface} | score: {score}"
    )

    return jsonify({
        "decision": decision,
        "score": score,
        "priority": priority,
        "interface": interface
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, threaded=True)
