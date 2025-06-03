import requests
import json
import time
import re
import subprocess
import os
import dotenv

# Existing interface weights and scoring logic from your file
INTERFACE_WEIGHTS = {
    'mgmt_net': 0.9,
    'server_net': 0.8,
    'eth_net': 0.5,
    'guest_net': 0.3,
    'int_net': 0.1
}

def calculate_score(priority, interface):
    base_score = (priority - 1) * 25
    return int(base_score * INTERFACE_WEIGHTS.get(interface, 0.5))

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

def log_decision(src_ip, score, decision):
    with open("/var/log/pdp.log", "a") as logf:
        logf.write(f"PDP Decision: {decision} | Source IP: {src_ip} | Calculated Score: {score}\n")

# --- SPLUNK QUERY SECTION ---

dotenv.load_dotenv()

SPLUNK_HOST = "https://10.10.3.200:8089"
SPLUNK_USER = os.getenv("SPLUNK_USERNAME")
SPLUNK_PASS = os.getenv("SPLUNK_PASSWORD")

def retrieve_logs(ip):
    # Start a search job
    search_query = f"search index=snort {ip} | sort - _time | head 5"
    req_data = {
        "search": search_query,
        "output_mode": "json"
    }
    resp = requests.post(
        f"{SPLUNK_HOST}/services/search/jobs",
        data=req_data,
        auth=(SPLUNK_USER, SPLUNK_PASS),
        verify=False
    )
    sid = resp.json()["sid"]

    # Wait for job to complete
    while True:
        job_resp = requests.get(
            f"{SPLUNK_HOST}/services/search/jobs/{sid}",
            params={"output_mode": "json"},
            auth=(SPLUNK_USER, SPLUNK_PASS),
            verify=False
        )
        if job_resp.json()["entry"][0]["content"]["isDone"]:
            break
        time.sleep(1)

    # Get results
    results_resp = requests.get(
        f"{SPLUNK_HOST}/services/search/jobs/{sid}/results",
        params={"output_mode": "json"},
        auth=(SPLUNK_USER, SPLUNK_PASS),
        verify=False
    )
    return results_resp.json()["results"]

def calculate_trust(logs):
    scores = []
    for log in logs:
        # Extract priority and src_ip from the _raw field if present
        raw = log.get('_raw', '')
        try:
            priority_match = re.search(r'Priority:\s*(\d+)', raw)
            priority = int(priority_match.group(1)) if priority_match else 1
            src_ip_match = re.search(r'\b\d{1,3}(?:\.\d{1,3}){3}\b', raw)
            src_ip = src_ip_match.group(0) if src_ip_match else "10.10.5.1"
            interface = get_interface_from_ip(src_ip)
            print(f"Priority: {priority} | IP: {src_ip} | Interface: {interface}")
            scores.append(calculate_score(priority, interface))
        except Exception as e:
            continue
    if scores:
        return sum(scores) // len(scores)
    return 0  # Default low trust if no logs

def decide_for_ip(ip):
    logs = retrieve_logs(ip)
    score = calculate_trust(logs)
    log_decision(ip, score, "ALLOW" if score >= 50 else "DENY")
    return score

if __name__ == "__main__":
    # Example usage
    ip = "10.10.1.11"
    score = decide_for_ip(ip)
    while True:
        time.sleep(5)