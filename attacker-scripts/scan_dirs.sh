#!/bin/bash


TARGET_IP="10.10.4.100"
WORDLIST_FILE="/attacker-scripts/common_dirs.txt"
SERVER_URL="http://${TARGET_IP}"

echo "--- Inizio scansione directory su ${SERVER_URL} da $(hostname) ---"

if [ ! -f "$WORDLIST_FILE" ]; then
    echo "Errore: Wordlist '$WORDLIST_FILE' non trovata dentro il container! Assicurati che il volume sia montato correttamente."
    exit 1
fi

while IFS= read -r directory; do
    if [[ -z "$directory" || "$directory" =~ ^# ]]; then
        continue
    fi

    TEST_URL="${SERVER_URL}/${directory}/"
    STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$TEST_URL")
.
    if [[ "$STATUS_CODE" != "404" && "$STATUS_CODE" != "000" ]]; then
        echo "  Trovato: ${TEST_URL} [Status: ${STATUS_CODE}]"
    fi

done < "$WORDLIST_FILE"

echo "--- Scansione directory completata da $(hostname) ---"