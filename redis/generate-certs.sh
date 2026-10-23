#!/bin/sh
# Build-time TLS material for the local Redis test server.
# Matches the certificates previously created on first container start.
set -eu

cert_dir=/etc/redis/tls
rm -rf "$cert_dir"
mkdir -p "$cert_dir"
cd "$cert_dir"

openssl genrsa -out ca.key 4096
openssl req \
  -x509 -new -nodes -sha256 \
  -key ca.key \
  -days 3650 \
  -subj '/O=Redis Test/CN=Certificate Authority' \
  -out ca.crt

cat > openssl.cnf <<'EOF'
[ server_cert ]
keyUsage = digitalSignature, keyEncipherment
nsCertType = server
[ client_cert ]
keyUsage = digitalSignature, keyEncipherment
nsCertType = client
EOF

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
  # shellcheck disable=SC2086
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

echo "Generating DH parameters"
openssl dhparam -out redis.dh 2048

chmod 644 ./*.crt ./*.dh openssl.cnf ca.txt
chmod 600 ./*.key
