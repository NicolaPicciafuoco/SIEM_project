# PEP Setup

FROM python:3.11-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-pip && \
    apt-get -y install iputils-ping iproute2 traceroute curl && \
    python3 -m pip install --no-cache-dir --upgrade pip && \
    python3 -m pip install --no-cache-dir requests && \
    python3 -m pip install --no-cache-dir dotenv && \
    python3 -m pip install --no-cache-dir flask

COPY ./pep.py /usr/local/bin/pep.py
COPY ./init-routes.sh /init-routes.sh

RUN chmod +x /init-routes.sh
RUN /init-routes.sh

CMD ["python3", "-u", "/usr/local/bin/pep.py"]