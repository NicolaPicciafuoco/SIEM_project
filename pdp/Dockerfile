# PDP Setup

FROM python:3.11-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-pip && \
    python3 -m pip install --no-cache-dir --upgrade pip && \
    python3 -m pip install --no-cache-dir requests && \
    python3 -m pip install --no-cache-dir dotenv

COPY ./pdp.py /usr/local/bin/pdp.py

CMD ["python3", "-u", "/usr/local/bin/pdp.py"]