import time
import re
import threading
import subprocess

# Log file paths
SNORT_LOG = "/var/log/snort/alert"
SQUID_LOG = "/var/log/squid/access.log"

INTERFACE_WEIGHTS = {
    'mgmt_net': 0.9,
    'server_net': 0.8,
    'eth_net': 0.5,
    'guest_net': 0.3,
    'int_net': 0.1
}

def follow(file):
    file.seek(0, 2)  # Go to end of file
    while True:
        line = file.readline()
        if not line:
            time.sleep(0.1)
            continue
        yield line

# Scoring logic
def calculate_score(priority, interface):
    base_score = (priority - 1) * 25 
    return int(base_score * INTERFACE_WEIGHTS.get(interface, 0.5))

# PEP

def enforce(src_ip, score):
    if score < 30:
        # Block at firewall (iptables/ipset example)
        subprocess.run(["ipset", "add", "PDP_BLACKLIST", src_ip])

        block_squid(src_ip)
        decision = "DENY"
    else:
        decision = "ALLOW"
    log_decision(src_ip, score, decision)
    return decision

def block_squid(ip):
    blocklist_path = "/etc/squid/blocked_ips.txt"
    try:
        with open(blocklist_path, "r+") as f:
            blocked = set(line.strip() for line in f if line.strip())
            if ip not in blocked:
                f.write(f"{ip}\n")
        # subprocess.run(["squid", "-k", "reconfigure"])
    except Exception as e:
        print(f"Error updating squid blocklist: {e}")

def log_decision(src_ip, score, decision):
    with open("/var/log/pdp.log", "a") as logf:
        logf.write(f"PDP Decision: {decision} | Source IP: {src_ip} | Calculated Score: {score}\n")

# Snort Log Parsing
def parse_snort_line(line):

    match = re.search(r'\[Priority: (\d+)\].*? (\d+\.\d+\.\d+\.\d+) ->', line)
    if match:
        priority = int(match.group(1))
        src_ip = match.group(2)
        interface = get_interface_from_ip(src_ip)
        return src_ip, priority, interface
    return None, None, None

def get_interface_from_ip(ip):
    if ip.startswith("10.10.1."):
        return "guest_net"
    elif ip.startswith("10.10.2."):
        return "mgmt_net"
    elif ip.startswith("10.10.3."):
        return "eth_net"
    elif ip.startswith("10.10.4."):
        return "server_net"
    elif ip.startswith("10.10.5."):
        return "int_net"
    else:
        return "unknown"

# Squid Log Parsing
def parse_squid_line(line):

    parts = line.strip().split()
    if len(parts) > 2:
        src_ip = parts[2]
        interface = get_interface_from_ip(src_ip)
        return src_ip, interface
    return None, None

# Snort log monitoring
def monitor_snort():
    try:
        with open(SNORT_LOG, "r") as logfile:
            for line in follow(logfile):
                src_ip, priority, interface = parse_snort_line(line)
                if src_ip and priority and interface:
                    score = calculate_score(priority, interface)
                    enforce(src_ip, score)
    except Exception as e:
        print(f"Error monitoring Snort log: {e}")

# Squid log monitoring
def monitor_squid():
    try:
        with open(SQUID_LOG, "r") as logfile:
            for line in follow(logfile):
                src_ip, interface = parse_squid_line(line)
                if src_ip and interface:
                    
                    score = calculate_score(4, interface)  # Assume lowest priority for HTTP logs
                    enforce(src_ip, score)
    except Exception as e:
        print(f"Error monitoring Squid log: {e}")

if __name__ == "__main__":
    threading.Thread(target=monitor_snort, daemon=True).start()
    threading.Thread(target=monitor_squid, daemon=True).start()
    while True:
        time.sleep(1)
