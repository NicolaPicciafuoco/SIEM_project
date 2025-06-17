import requests
import json
import time
import re
import os
import dotenv
from flask import Flask, request, jsonify
# Importa urllib3 per gestire i warning SSL, se necessario
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

LOG_TIME_WINDOW = "-2m"  # Esempio: analizza i log degli ultimi 2 minuti

app = Flask(__name__)

INTERFACE_WEIGHTS = {
    'mgmt_net': 2.0,
    'eth_net': 0.8,
    'guest_net': 0.7,
    'int_net': 0.6
}

SNORT_PRIORITY_PENALTIES = {
    1: 1.0,  # Priority 1: Molto alta penalità
    2: 0.6,  # Priority 2: Alta penalità
    3: 0.2,  # Priority 3: Media penalità
    4: 0.1,  # Priority 4: Bassa penalità
}
# Regex per estrarre il numero di priorità dai log Snort
SNORT_PRIORITY_PATTERN = re.compile(r'\[Priority:\s*(\d+)\]')


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

    snort_logs = retrieve_snort_logs(ip, limit=20, earliest_time=LOG_TIME_WINDOW)
    squid_logs = retrieve_squid_logs(ip, limit=20, earliest_time=LOG_TIME_WINDOW)
    pdp_logs = retrieve_pdp_logs(ip, limit=20, earliest_time=LOG_TIME_WINDOW)
    db_logs = retrieve_db_logs(ip, limit=20, earliest_time=LOG_TIME_WINDOW)

    print(f"Number of snort_logs in the last '{LOG_TIME_WINDOW}': {len(snort_logs)}")
    total_snort_penalty = 0
    for log in snort_logs:
        raw = log.get('_raw', '')
        match = SNORT_PRIORITY_PATTERN.search(raw)
        if match:
            try:
                priority = int(match.group(1))
                penalty = SNORT_PRIORITY_PENALTIES.get(priority, 0)  # Default a 0 se priorità non definita
                total_snort_penalty += penalty
                print(f"  Snort log with Priority {priority} found, adding penalty: -{penalty}")
            except ValueError:
                print(f"  Warning: Could not parse priority number from log: {raw}")
        else:
            print(f"  Warning: Priority pattern not found in log: {raw}")

    base_score -= total_snort_penalty
    print(f"Total snort penalty applied: -{total_snort_penalty}")
    print(f"Base score after snort logs: {base_score}")

    print(f"Number of squid_logs in the last '{LOG_TIME_WINDOW}': {len(squid_logs)}")
    for log in squid_logs:
        raw = log.get('_raw', '')
        if "TCP_DENIED/403" in raw or "TCP_FORBIDDEN/403" in raw:
            base_score -= 1
            print(f"  Squid DENIED found, decreasing score by 1. Current score: {base_score}")
        elif "TCP_MISS/200" in raw:
            base_score += 1
            print(f"  Squid ALLOWED (TCP_MISS/200) found, increasing score by 1. Current score: {base_score}")
    print(f"Base score after squid logs: {base_score}")

    print(f"Number of pdp_logs in the last '{LOG_TIME_WINDOW}': {len(pdp_logs)}")
    for log in pdp_logs:
        raw = log.get('_raw', '')
        if "PDP Decision: ALLOW" in raw:
            base_score += 1
            print(f"  PDP ALLOW found, increasing score by 1. Current score: {base_score}")
        elif "PDP Decision: DENY" in raw:
            base_score -= 1
            print(f"  PDP DENY found, decreasing score by 1. Current score: {base_score}")
    print(f"Base score after PDP logs: {base_score}")

    print(f"Number of db_logs in the last '{LOG_TIME_WINDOW}': {len(db_logs)}")
    for log in db_logs:
        raw = log.get('_raw', '')
        if "permission denied" in raw:
            base_score -= 1.5
            print("  Detected DB Access DENIED, decreasing score by 1.5")
        elif '"error":null' in raw or (
                "query successful" in raw.lower() and "permission denied" not in raw.lower()):
            base_score += 1
            print("  Detected potential DB Access ALLOWED/SUCCESS, increasing score by 1")

    print(f"Base score after db_logs: {base_score}")

    weight = get_interface_weight(ip)
    print(f"get_interface_weight('{ip}') = {get_interface_weight(ip)}")

    total_score = weight * base_score
    print(f"Base score for IP {ip}: {base_score}, Weighted score: {total_score}")

    if total_score <= 2.5:  # Soglia di DENY
        final_decision = "DENY"
    else:
        final_decision = "ALLOW"

    print(f"Total score: {total_score}, Final decision: {final_decision}")

    return total_score, final_decision


def log_decision(src_ip, score, decision):
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    with open("/var/log/pdp.log", "a") as logf:
        logf.write(
            f"{timestamp} - PDP Decision: {decision} | Source IP: {src_ip} | Calculated Score: {score:.2f}\n")  # Formattiamo lo score



dotenv.load_dotenv()

SPLUNK_HOST = os.getenv("SPLUNK_HOST", "https://10.10.3.200:8089")  # Default
SPLUNK_USER = os.getenv("SPLUNK_USERNAME")
SPLUNK_PASS = os.getenv("SPLUNK_PASSWORD")

# Verifichiamo che le credenziali siano caricate
if not SPLUNK_USER or not SPLUNK_PASS:
    print("Errore: Variabili d'ambiente SPLUNK_USERNAME o SPLUNK_PASSWORD non caricate!")


# La funzione di ricerca Splunk (presa dalla tua versione)
def splunk_search(index, ip_term, limit, earliest_time=None):
    time_filter = ""
    if earliest_time:
        # La query ora include earliest e latest per definire l'intervallo
        time_filter = f' earliest="{earliest_time}" latest="now"'


    search_query = f'search index={index} {ip_term}{time_filter} | sort - _time | head {limit}'
    print(f"Executing Splunk Query: {search_query}")  # Utile per il debug

    try:
        # Aggiungiamo timeout alla richiesta iniziale
        resp = requests.post(
            f"{SPLUNK_HOST}/services/search/jobs",
            data={"search": search_query, "output_mode": "json"},
            auth=(SPLUNK_USER, SPLUNK_PASS),
            verify=False,
            timeout=30  # Aggiunge un timeout
        )
        resp.raise_for_status()  # Solleva un'eccezione per stati di errore HTTP (4xx o 5xx)

        sid_data = resp.json()
        if "sid" not in sid_data:
            print(f"Errore Splunk: SID non ricevuto. Risposta: {sid_data}")
            return []  # Ritorna lista vuota in caso di errore

        sid = sid_data["sid"]

        start_polling_time = time.time()
        polling_timeout = 60  # Timeout totale per il polling in secondi
        while time.time() - start_polling_time < polling_timeout:
            job_resp = requests.get(
                f"{SPLUNK_HOST}/services/search/jobs/{sid}",
                params={"output_mode": "json"},
                auth=(SPLUNK_USER, SPLUNK_PASS),
                verify=False,
                timeout=10  # Timeout per ogni richiesta di polling
            )
            job_resp.raise_for_status()

            job_status = job_resp.json()
            if job_status["entry"][0]["content"]["isDone"]:
                break
            time.sleep(1)
        else:
            print(f"Timeout waiting for Splunk job {sid} to complete after {polling_timeout} seconds.")
            # Potresti voler cancellare il job qui se necessario
            return []

        # Recupera i risultati (con aggiunta di timeout)
        results_resp = requests.get(
            f"{SPLUNK_HOST}/services/search/jobs/{sid}/results",
            params={"output_mode": "json"},
            auth=(SPLUNK_USER, SPLUNK_PASS),
            verify=False,
            timeout=30  # Timeout per la richiesta dei risultati
        )
        results_resp.raise_for_status()

        results = results_resp.json().get("results", [])
        return results

    except requests.exceptions.Timeout:
        print(f"Errore: Timeout durante la comunicazione con Splunk job {sid}.")
        return []
    except requests.exceptions.RequestException as e:
        print(f"Errore di rete o HTTP durante la comunicazione con Splunk job {sid}: {e}")
        return []  # Ritorna lista vuota in caso di errore
    except json.JSONDecodeError:
        print(f"Errore nel decodificare la risposta JSON da Splunk job {sid}.")
        return []
    except Exception as e:
        print(f"Errore generico durante la ricerca Splunk per SID {sid}: {e}")
        return []


# Le funzioni wrapper ora passano semplicemente l'IP come termine di ricerca
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

    try:
        json_data = response.get_json()
        formatted_score = f"{json_data.get('score', 'N/A'):.2f}" if isinstance(json_data.get('score'),
                                                                               (int, float)) else json_data.get('score',
                                                                                                                'N/A')
        print(f"Decision for {source_ip}: {json_data.get('decision', 'N/A')} with score {formatted_score}")
    except Exception as e:
        print(f"Could not log decision details for {source_ip}: {e}")

    return response, status_code


if __name__ == "__main__":
    if not SPLUNK_USER or not SPLUNK_PASS:
        print(
            "\n!!!! ERRORE CRITICO: CREDENZIALI SPLUNK MANCANTI. L'applicazione potrebbe non funzionare correttamente. !!!!\n")

    else:
        print("Credenziali Splunk caricate con successo.")

    app.run(host='0.0.0.0', port=5001, debug=False)