# docker-elasticsearch

Minimal Elasticsearch OSS 7.10.2 image for local and CI compose stacks.

## Defaults

The image is configured for single-node test use out of the box:

- `discovery.type: single-node`
- HTTP/transport bound on `0.0.0.0`
- `node.store.allow_mmap: false` (avoids Lucene mmap failures on fuse-overlayfs / Docker Desktop / many CI hosts)
- Heap `512m` via `ES_JAVA_OPTS` and `jvm.options.d`
- Healthcheck against `http://127.0.0.1:9200`

The distribution type is still `tar`, so dotted environment variables such as
`discovery.type=single-node` are ignored. Prefer the baked config, `-E` flags, or
`elasticsearch.yml` mounts.

## Example

```yaml
elasticsearchtest:
  image: sharinpix/docker-elasticsearch:latest
  expose:
    - "9200"
  environment:
    - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
  healthcheck:
    test: ["CMD-SHELL", "curl -sf http://127.0.0.1:9200 >/dev/null"]
    interval: 5s
    timeout: 5s
    retries: 24
    start_period: 30s
```

Command-line `-E` overrides remain supported when you need to customize further.
