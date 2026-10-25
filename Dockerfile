FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends chromium chromium-driver ca-certificates \
 && rm -rf /var/lib/apt/lists/*
EXPOSE 9515
CMD ["chromedriver", "--port=9515", "--allowed-ips=", "--allowed-origins=*"]
