
import requests
import json
import time
import re
import os
import dotenv
from flask import Flask, request, jsonify

# Aggiungiamo una costante per la finestra temporale, così è facile da modificare
LOG_TIME_WINDOW = "-2m"  # Esempio: analizza i log degli ultimi 15 minuti

app = Flask(__name__)

# Existing interface weights and scoring logic from your file
INTERFACE_WEIGHTS = {
    'mgmt_net': 1.0,
    'eth_net': 0.8,
    'guest_net': 0.7,
    'int_net': 0.6
}

def get_interface_weight(ip):
    if ip.startswith("10.10.1."):
        return INTERFACE_WEIGHTS['guest_net']
    elif ip.startswith("10.10.2."):
        return INTERFACE_WEIGHTS['mgmt_net']
    elif ip.startswith("10.10.3."):
        return INTERFACE_WEIGHTS['eth_net']
    elif ip.startswith("10.10.5."):
        return INTERFACE_WEIGHTS['int_net']
    else:
        return 0.5  # peso default

def calculate_combined_score(ip):
    base_score = 5.0
    
    # MODIFICA: Passiamo la finestra temporale alle funzioni di recupero log
    snort_logs = retrieve_snort_logs(ip, limit=20, earliest_time=LOG_TIME_WINDOW)
    squid_logs = retrieve_squid_logs(ip, limit=20, earliest_time=LOG_TIME_WINDOW)
    pdp_logs = retrieve_pdp_logs(ip, limit=20, earliest_time=LOG_TIME_WINDOW)
    db_logs = retrieve_db_logs(ip, limit=20, earliest_time=LOG_TIME_WINDOW)

    snort_score = sum(1 for log in snort_logs if re.search(r'Priority:\s*(1|2)', log.get('_raw', '')))
    print(f"Number of snort_logs in the last '{LOG_TIME_WINDOW}': {len(snort_logs)}")
    base_score -= snort_score
    print(f"Base score after snort logs: {base_score} (Snort score: {snort_score})")
    
    print(f"Number of squid_logs in the last '{LOG_TIME_WINDOW}': {len(squid_logs)}")
    for log in squid_logs:
        raw = log.get('_raw', '')
        if "TCP_DENIED/403" in raw or "TCP_FORBIDDEN/403" in raw:
            base_score -= 1
        elif "TCP_MISS/200" in raw:
            base_score += 1
    print(f"Base score after squid logs: {base_score}")
    
    print(f"Number of pdp_logs in the last '{LOG_TIME_WINDOW}': {len(pdp_logs)}")
    for log in pdp_logs:
        raw = log.get('_raw', '')
        if "PDP Decision: ALLOW" in raw:
            base_score += 1
        elif "PDP Decision: DENY" in raw:
            base_score -= 1
    print(f"Base score after PDP logs: {base_score}")
    
    print(f"Number of db_logs in the last '{LOG_TIME_WINDOW}': {len(db_logs)}")
    for log in db_logs:
        raw = log.get('_raw', '')
        print(f"DB log raw: {raw}")
        if "permission denied" in raw:
            base_score -= 1
            print("Detected DB Access DENIED, decreasing score")
        elif '"error":null' in raw:
            base_score += 1
            print("Detected DB Access ALLOWED, increasing score")

    print(f"Base score after db_logs: {base_score}")
    
    weight = get_interface_weight(ip)
    print(f"get_interface_weight('{ip}') = {get_interface_weight(ip)}")
    
    total_score = weight * base_score
    print(f"Base score for IP {ip}: {base_score}, Weighted score: {total_score}")
    
    if total_score <= 2.5:
        final_decision = "DENY"
    else:
        final_decision = "ALLOW"

    print(f"Total score: {total_score}, Final decision: {final_decision}")

    return total_score, final_decision

def log_decision(src_ip, score, decision):
    with open("/var/log/pdp.log", "a") as logf:
        logf.write(f"PDP Decision: {decision} | Source IP: {src_ip} | Calculated Score: {score}\n")

# --- SPLUNK QUERY SECTION ---

dotenv.load_dotenv()

SPLUNK_HOST = "https://10.10.3.200:8089"
SPLUNK_USER = os.getenv("SPLUNK_USERNAME")
SPLUNK_PASS = os.getenv("SPLUNK_PASSWORD")

# MODIFICA: La funzione ora accetta un parametro 'earliest_time' opzionale
def splunk_search(index, ip, limit, earliest_time=None):
    # Costruiamo il filtro temporale solo se 'earliest_time' è specificato
    time_filter = ""
    if earliest_time:
        # La query ora include earliest e latest per definire l'intervallo
        time_filter = f' earliest="{earliest_time}" latest="now"'
    
    # La query viene composta includendo il filtro temporale (se presente)
    search_query = f'search index={index} {ip}{time_filter} | sort - _time | head {limit}'
    print(f"Executing Splunk Query: {search_query}") # Utile per il debug

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

    results_resp = requests.get(
        f"{SPLUNK_HOST}/services/search/jobs/{sid}/results",
        params={"output_mode": "json"},
        auth=(SPLUNK_USER, SPLUNK_PASS),
        verify=False
    )
    return results_resp.json()["results"]

# MODIFICA: Le funzioni wrapper ora accettano e passano 'earliest_time'
def retrieve_snort_logs(ip, limit, earliest_time=None):
    return splunk_search("snort", ip, limit, earliest_time)

def retrieve_squid_logs(ip, limit, earliest_time=None):
    return splunk_search("squid", ip, limit, earliest_time)

def retrieve_db_logs(ip, limit, earliest_time=None):
    return splunk_search("queries", ip, limit, earliest_time)

def retrieve_pdp_logs(ip, limit, earliest_time=None):
    return splunk_search("pdp_logs", ip, limit, earliest_time)

def decide_for_ip(ip):
    score, decision = calculate_combined_score(ip)
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
    if not source_ip:
        return jsonify({"error": "source_ip is required"}), 400
        
    response, status_code = decide_for_ip(source_ip)

    json_data = response.get_json()
    print(f"Decision for {source_ip}: {json_data['decision']} with score {json_data['score']}")

    return response, status_code

if __name__ == "__main__":
     # Disabilita i messaggi di warning per le richieste HTTPS non verificate
    #  import urllib3
    #  urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
     app.run(host='0.0.0.0', port=5001, debug=False)
