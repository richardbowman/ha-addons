FROM ghcr.io/browserless/chromium:latest

USER root

# jq is needed to parse /data/options.json from the HA add-on runtime
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*

COPY run.sh /run.sh
RUN chmod +x /run.sh

ENTRYPOINT ["/run.sh"]
