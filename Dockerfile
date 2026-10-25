FROM alpine:3.16

ENV ES_VERSION=7.10.2
ENV ES_HOME=/usr/share/elasticsearch
ENV JAVA_HOME=/usr/lib/jvm/default-jvm

# openjdk11-jre-headless keeps the image small; gcompat provides glibc bindings for JNA
RUN apk add --no-cache openjdk11-jre-headless bash curl gcompat su-exec && \
    addgroup -g 1000 -S elasticsearch && \
    adduser -u 1000 -S elasticsearch -G elasticsearch -h ${ES_HOME}

RUN mkdir -p ${ES_HOME} && \
    curl -fsSL https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-oss-${ES_VERSION}-no-jdk-linux-x86_64.tar.gz \
    | tar -xz --strip-components=1 -C ${ES_HOME} && \
    chown -R elasticsearch:elasticsearch ${ES_HOME}

WORKDIR ${ES_HOME}
USER elasticsearch

EXPOSE 9200 9300
CMD ["./bin/elasticsearch"]
