# Redis 8 with fixed test TLS certificates stored in the image.
# The CA is valid for 3650 days, until 20 Oct 2036 14:01 Europe/Paris.
# The server, client, and redis certificates are valid for 825 days,
# until 25 Jan 2029 13:01 Europe/Paris.
FROM redis:8-alpine

COPY redis/entrypoint.sh /usr/local/bin/docker-entrypoint-tls.sh
COPY redis/tls /etc/redis/tls

RUN chmod 755 /usr/local/bin/docker-entrypoint-tls.sh \
  && chown -R redis:redis /etc/redis/tls \
  && chmod 644 /etc/redis/tls/*.crt /etc/redis/tls/*.dh \
  && chmod 600 /etc/redis/tls/*.key

EXPOSE 6379

ENTRYPOINT ["docker-entrypoint-tls.sh"]
CMD ["redis-server"]
