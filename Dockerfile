FROM alpine:3.16

ENV ES_VERSION=7.10.2
ENV ES_HOME=/usr/share/elasticsearch
ENV JAVA_HOME=/usr/lib/jvm/default-jvm
ENV ES_JAVA_OPTS="-Xms512m -Xmx512m"

# openjdk11-jre-headless keeps the image small; gcompat provides glibc bindings for JNA
RUN apk add --no-cache openjdk11-jre-headless bash curl gcompat su-exec && \
    addgroup -g 1000 -S elasticsearch && \
    adduser -u 1000 -S elasticsearch -G elasticsearch -h ${ES_HOME}

# The OSS no-jdk tarball is Java-only (no ELF natives), so the x86_64 artifact
# works on both amd64 and arm64 with the platform JDK from apk.
RUN mkdir -p ${ES_HOME} && \
    curl -fsSL https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-oss-${ES_VERSION}-no-jdk-linux-x86_64.tar.gz \
    | tar -xz --strip-components=1 -C ${ES_HOME} && \
    mkdir -p ${ES_HOME}/data ${ES_HOME}/logs && \
    # Single-node test defaults: bind on all interfaces, skip mmap (fuse-overlayfs /
    # Docker Desktop / many CI hosts cannot support Lucene's mmap reliably), and
    # keep heap at 512m so AlwaysPreTouch fits typical compose memory limits.
    printf '%s\n' \
      'cluster.name: docker-cluster' \
      'network.host: 0.0.0.0' \
      'http.host: 0.0.0.0' \
      'transport.host: 0.0.0.0' \
      'discovery.type: single-node' \
      'node.store.allow_mmap: false' \
      'bootstrap.memory_lock: false' \
      > ${ES_HOME}/config/elasticsearch.yml && \
    sed -i 's/^-Xms1g$/-Xms512m/; s/^-Xmx1g$/-Xmx512m/' ${ES_HOME}/config/jvm.options && \
    printf '%s\n' \
      '-Xms512m' \
      '-Xmx512m' \
      > ${ES_HOME}/config/jvm.options.d/heap.options && \
    chown -R elasticsearch:elasticsearch ${ES_HOME}

WORKDIR ${ES_HOME}
USER elasticsearch

EXPOSE 9200 9300

# Use IPv4 loopback: "localhost" can flap between ::1 and 127.0.0.1 in Alpine.
HEALTHCHECK --interval=5s --timeout=5s --start-period=30s --retries=24 \
  CMD curl -sf http://127.0.0.1:9200 >/dev/null || exit 1

CMD ["./bin/elasticsearch"]
