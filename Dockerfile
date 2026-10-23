# Redis 8 with the test TLS certificates generated once at image build.
# Containers reuse /etc/redis/tls instead of running openssl on first boot.
FROM redis:8-alpine AS certs

USER root

RUN apk add --no-cache openssl

COPY redis/generate-certs.sh /tmp/generate-certs.sh

RUN sh /tmp/generate-certs.sh \
  && rm -f /tmp/generate-certs.sh

FROM redis:8-alpine

COPY redis/entrypoint.sh /usr/local/bin/docker-entrypoint-tls.sh
COPY --from=certs /etc/redis/tls /etc/redis/tls

RUN chmod 755 /usr/local/bin/docker-entrypoint-tls.sh \
  && chown -R redis:redis /etc/redis/tls \
  && mkdir -p /app/redis \
  && for cert in /etc/redis/tls/*; do \
       ln -sfn "$cert" "/app/redis/$(basename "$cert")"; \
     done

EXPOSE 6379

ENTRYPOINT ["docker-entrypoint-tls.sh"]
CMD ["redis-server"]
