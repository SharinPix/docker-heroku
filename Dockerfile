# Redis 8 TLS server without the Redis Stack modules.
# X.509 dates cannot go past 9999, so every certificate expires at
# 9999-12-31 23:59:59Z, the latest value the format can store.
FROM redis:8-alpine AS redis

FROM alpine:3.23 AS certs

RUN apk add --no-cache openssl

RUN <<'EOF'
set -eu
mkdir -p /etc/redis/tls
cd /etc/redis/tls

openssl genrsa -out ca.key 4096
openssl req \
  -x509 -new -nodes -sha256 \
  -key ca.key \
  -not_after 99991231235959Z \
  -subj '/O=Redis Test/CN=Certificate Authority' \
  -out ca.crt

cat > openssl.cnf <<'CNF'
[ server_cert ]
keyUsage = digitalSignature, keyEncipherment
nsCertType = server
[ client_cert ]
keyUsage = digitalSignature, keyEncipherment
nsCertType = client
CNF

generate_cert() {
  name=$1
  cn=$2
  shift 2

  openssl genrsa -out "${name}.key" 2048
  openssl req \
    -new -sha256 \
    -subj "/O=Redis Test/CN=${cn}" \
    -key "${name}.key" \
    -out "${name}.csr"
  openssl x509 \
    -req -sha256 \
    -in "${name}.csr" \
    -CA ca.crt \
    -CAkey ca.key \
    -CAserial ca.txt \
    -CAcreateserial \
    -not_after 99991231235959Z \
    "$@" \
    -out "${name}.crt"
  rm -f "${name}.csr"
  openssl verify -CAfile ca.crt "${name}.crt"
}

generate_cert server "Server-only" -extfile openssl.cnf -extensions server_cert
generate_cert client "Client-only" -extfile openssl.cnf -extensions client_cert
generate_cert redis "Generic-cert"

openssl dhparam -out redis.dh 2048
rm -f openssl.cnf ca.txt
chmod 644 ./*.crt ./redis.dh
chmod 600 ./*.key
EOF

FROM alpine:3.23

RUN apk add --no-cache libssl3 setpriv \
  && addgroup -g 1000 -S redis \
  && adduser -S -D -H -u 999 -G redis redis \
  && mkdir -p /data /usr/local/etc/redis /usr/local/lib/redis/modules \
  && chown redis:redis /data

COPY --from=redis \
  /usr/local/bin/redis-server \
  /usr/local/bin/redis-cli \
  /usr/local/bin/docker-entrypoint.sh \
  /usr/local/bin/
COPY --from=certs --chown=redis:redis /etc/redis/tls /etc/redis/tls

RUN <<'EOF'
set -eu
chmod 644 /etc/redis/tls/*.crt /etc/redis/tls/*.dh
chmod 600 /etc/redis/tls/*.key
cat > /usr/local/etc/redis/redis.conf <<'CNF'
tls-port 6379
port 0
tls-cert-file /etc/redis/tls/redis.crt
tls-key-file /etc/redis/tls/redis.key
tls-ca-cert-file /etc/redis/tls/ca.crt
tls-dh-params-file /etc/redis/tls/redis.dh
requirepass pass
tls-auth-clients optional
appendonly yes
appendfsync always
CNF
chown redis:redis /usr/local/etc/redis/redis.conf
chmod 640 /usr/local/etc/redis/redis.conf
EOF

VOLUME /data
WORKDIR /data

EXPOSE 6379

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["redis-server", "/usr/local/etc/redis/redis.conf"]
