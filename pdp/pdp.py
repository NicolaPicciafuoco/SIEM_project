import requests
import json
import time
import re
import os
import dotenv
from flask import Flask, request, jsonify

app = Flask(__name__)

# Existing interface weights and scoring logic from your file
INTERFACE_WEIGHTS = {
    'mgmt_net': 0.9,
    'server_net': 0.8,
    'eth_net': 0.5,
    'guest_net': 0.3,
    'int_net': 0.1
}
def get_interface_weight(ip):
    if ip.startswith("10.10.1."):
        return INTERFACE_WEIGHTS['guest_net']
    elif ip.startswith("10.10.2."):
        return INTERFACE_WEIGHTS['mgmt_net']
    elif ip.startswith("10.10.3."):
        return INTERFACE_WEIGHTS['eth_net']
    elif ip.startswith("10.10.4."):
        return INTERFACE_WEIGHTS['server_net']
    elif ip.startswith("10.10.5."):
        return INTERFACE_WEIGHTS['int_net']
    else:
        return 0.5  # peso default


# def calculate_score(priority, interface):
#     base_score = (priority - 1) * 25
#     return int(base_score * INTERFACE_WEIGHTS.get(interface, 0.5))

def calculate_combined_score(ip):
    snort_logs = retrieve_snort_logs(ip, limit=50)
    squid_logs = retrieve_squid_logs(ip, limit=50)
    pdp_logs = retrieve_pdp_logs(ip, limit=50)

    snort_score = 0
    alert_counts = 0
    weighted_priority_sum = 0
    for log in snort_logs:
        raw = log.get('_raw', '')
        prio_match = re.search(r'Priority:\s*(\d+)', raw)
        if prio_match:
            priority = int(prio_match.group(1))
            weight = INTERFACE_WEIGHTS.get(get_interface_weight(ip), 0.5)  # usa IP passato
            prio_weight = 5 - priority
            weighted_priority_sum += prio_weight * weight
            alert_counts += 1

    snort_score = min(5, max(1, int(weighted_priority_sum / alert_counts))) if alert_counts > 0 else 1

    squid_score = 0
    weight = INTERFACE_WEIGHTS.get(get_interface_weight(ip), 0.5)
    for log in squid_logs:
        raw = log.get('_raw', '')
        if "TCP_MISS/200" in raw:
            squid_score += 1 * weight
        elif "TCP_DENIED" in raw or "TCP_FORBIDDEN" in raw:
            squid_score -= 1 * weight

    squid_score = max(-5, min(5, int(squid_score)))

    pdp_score = 0
    for log in pdp_logs:
        raw = log.get('_raw', '')
        if "PDP Decision: ALLOW" in raw:
            pdp_score += 1
        elif "PDP Decision: DENY" in raw:
            pdp_score -= 1

    pdp_score = max(-5, min(5, pdp_score))

    total_score = snort_score + squid_score + pdp_score

    if total_score <= 1:
        final_score = 1
    elif total_score >= 5:
        final_score = 5
    else:
        final_score = total_score

    print(f"Final score for IP {ip}: {final_score}")
    return final_score

def log_decision(src_ip, score, decision):
    with open("/var/log/pdp.log", "a") as logf:
        logf.write(f"PDP Decision: {decision} | Source IP: {src_ip} | Calculated Score: {score}\n")

# --- SPLUNK QUERY SECTION ---

dotenv.load_dotenv()

SPLUNK_HOST = "https://10.10.3.200:8089"
SPLUNK_USER = os.getenv("SPLUNK_USERNAME")
SPLUNK_PASS = os.getenv("SPLUNK_PASSWORD")

def splunk_search(index, ip, limit):
    search_query = f"search index={index} {ip} | sort - _time | head {limit}"
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

def retrieve_snort_logs(ip, limit):
    return splunk_search("snort", ip, limit)

def retrieve_squid_logs(ip, limit=10):
    return splunk_search("squid", ip, limit)

def retrieve_db_logs(ip, limit=10):
    return splunk_search("postgresql", ip, limit)

def retrieve_pdp_logs(ip, limit=10):
    return splunk_search("pdp_logs", ip, limit)

def decide_for_ip(ip):
    score = calculate_combined_score(ip)
    decision = "ALLOW" if score >= 3 else "DENY"  # soglia media tra 1 e 5
    log_decision(ip, score, decision)
    response = jsonify({
        "source_ip": ip,
        "score": score,
        "decision": decision
    }), 200
    return response

@app.route('/decide', methods=['POST'])
def decide():
    data = request.get_json()
    source_ip = data.get('source_ip', '')
    #source_ip = source_ip.split(',')[0].strip()
    response, status_code = decide_for_ip(source_ip)

    # Estraggo il json dai dati di risposta per stampare
    json_data = response.get_json()
    print(f"Decision for {source_ip}: {json_data['decision']} with score {json_data['score']}")

    return response, status_code


if __name__ == "__main__":
     app.run(host='0.0.0.0', port=5001, debug=False)