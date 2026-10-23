# Redis 8 with test TLS certificates generated when the image is built.
# The CA is valid for 3650 days from the build. The server, client, and
# redis certificates are valid for 825 days from the build.
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
  -days 3650 \
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
    -days 825 \
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

COPY redis/entrypoint.sh /usr/local/bin/docker-entrypoint-tls.sh
COPY --from=certs --chown=redis:redis /etc/redis/tls /etc/redis/tls

RUN chmod 755 /usr/local/bin/docker-entrypoint-tls.sh \
  && chmod 644 /etc/redis/tls/*.crt /etc/redis/tls/*.dh \
  && chmod 600 /etc/redis/tls/*.key

EXPOSE 6379

ENTRYPOINT ["docker-entrypoint-tls.sh"]
CMD ["redis-server"]
