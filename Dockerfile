FROM eclipse-temurin:11-jre-alpine

ENV ES_VERSION=7.10.2
RUN wget -qO- https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-oss-${ES_VERSION}-no-jdk-linux-x86_64.tar.gz \
    | tar -xz -C /usr/share && \
    mv /usr/share/elasticsearch-${ES_VERSION} /usr/share/elasticsearch

WORKDIR /usr/share/elasticsearch
EXPOSE 9200 9300
CMD ["./bin/elasticsearch"]
