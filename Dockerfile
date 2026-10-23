# Redis 8 with test TLS certificates generated when the image is built.
# X.509 dates cannot go past 9999, so every certificate expires at
# 9999-12-31 23:59:59Z, the latest value the format can store.
FROM redis:8-alpine AS certs

USER root

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

FROM redis:8-alpine

COPY --from=certs --chown=redis:redis /etc/redis/tls /etc/redis/tls

RUN <<'EOF'
set -eu
chmod 644 /etc/redis/tls/*.crt /etc/redis/tls/*.dh
chmod 600 /etc/redis/tls/*.key
mkdir -p /usr/local/etc/redis
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

EXPOSE 6379

CMD ["redis-server", "/usr/local/etc/redis/redis.conf"]
