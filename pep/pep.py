from flask import Flask, request, jsonify
import requests
import logging
import os

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# Configuration
PDP_URL = os.getenv('PDP_URL', 'http://pdp:5001/decide')
DB_URL = os.getenv('DB_URL', 'http://core-server/query.php')
TIMEOUT = float(os.getenv('TIMEOUT', '30.0'))

@app.route('/access', methods=['GET'])
def handle_access_request():
    """
    PEP endpoint that receives requests from server
    """
    try:
        req_data = request.args.to_dict()
        req_params = request.args
        source_ip = request.headers.get('X-Forwarded-For', "10.10.5.0")
        logging.info(f"Received DB access request from {source_ip}")
        
        pdp_payload = {
            "source_ip": source_ip,
            "db_user": req_params.get('user', 'siem_user'),
            "request": req_data,
            "timestamp": request.headers.get('X-Request-Time')
        }
        
        try:
            pdp_response = requests.post(
                PDP_URL,
                json=pdp_payload,
                timeout=TIMEOUT
            )
        except requests.exceptions.RequestException as e:
            logging.error(f"PDP communication failed: {str(e)}")
            return jsonify({"error": "Policy service unavailable"}), 503


        if pdp_response.status_code == 200:
            decision = pdp_response.json().get('decision')
            #decision = "ALLOW"  # Simulating decision for testing purposes
            if decision == "ALLOW":
                logging.info(f"Allowing request from {source_ip}")
                db_response = requests.post(
                    DB_URL,
                    json=req_data,
                    headers={'X-Forwarded-For': source_ip},
                    timeout=TIMEOUT
                )
                return jsonify(db_response.json()), db_response.status_code
            else:
                logging.warning(f"Denying request from {source_ip}")
                return jsonify({"error": "Access denied"}), 403 #non può entrareeee
        else:
            logging.error(f"Unexpected PDP response: {pdp_response.status_code}")
            return jsonify({"error": "Internal service error"}), 500

    except Exception as e:
        logging.error(f"Error processing request: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500 #internal error

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
