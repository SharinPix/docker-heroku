FROM node:22.21.1-bookworm AS node

# Prebuilt Ruby 4.0.7. Node and the remaining tools are added on top.
FROM ruby:4.0.7-bookworm

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node /usr/local/include/node /usr/local/include/node

RUN ln -sf node /usr/local/bin/nodejs \
  && ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
  && ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
  && ln -sf ../lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack

RUN apt-get update -qq && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    curl \
    wget \
    git \
    vim \
    nginx \
    ca-certificates \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libffi-dev \
    libyaml-dev \
    libyaml-0-2 \
    libffi8 \
    libssl3 \
    libgmp10 \
    libcrypt1 \
    libpcre2-8-0 \
  && install -d /usr/share/keyrings \
  && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg \
  && . /etc/os-release \
  && echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] https://apt.postgresql.org/pub/repos/apt ${VERSION_CODENAME}-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
  && apt-get update -qq \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    postgresql-client \
    libpq-dev \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && truncate -s 0 /var/log/*log

# UID 1000 stays stable so bind mounts from a developer machine keep working.
RUN adduser --uid 1000 --gecos '' --disabled-password user \
  && passwd -d user

RUN mkdir -p /app /nginx /bundle /home/user/.sfdx /app/.pnpm-store \
  && chown user:user /app /bundle /home/user/.sfdx /nginx /var/log/nginx /app/.pnpm-store /home/user

ARG TARGETARCH
RUN case "$TARGETARCH" in \
      amd64|arm64) ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH:-empty}" >&2; exit 1 ;; \
    esac \
  && curl -fsSL "https://github.com/heroku/heroku-buildpack-nginx/raw/refs/heads/main/nginx-heroku-24-${TARGETARCH}.tgz" \
      | tar -xz -C /nginx \
  && curl -fsSL -o /nginx/start-nginx https://raw.githubusercontent.com/heroku/heroku-buildpack-nginx/main/bin/start-nginx \
  && chmod +x /nginx/start-nginx /nginx/nginx \
  && rm -rf /tmp/* \
  && chown -R user:user /nginx

ENV PNPM_HOME="/home/user/.local/share/pnpm"
ENV PATH="${PNPM_HOME}:/home/user/.local/bin:/usr/local/bin:${PATH}:./bin:./node_modules/.bin"
ENV npm_config_store_dir="/app/.pnpm-store"

RUN printf '%s\n' \
  'export PNPM_HOME=/home/user/.local/share/pnpm' \
  'export PATH="$PNPM_HOME:/home/user/.local/bin:/usr/local/bin:./bin:$PATH:./node_modules/.bin"' \
  > /etc/profile.d/dev-tools.sh

USER user

RUN npm install --global pnpm@10.27.0 --prefix /home/user/.local \
  && pnpm config set store-dir /app/.pnpm-store \
  && SHELL=bash pnpm setup \
  && pnpm add -g @salesforce/cli \
  && rm -rf /home/user/.npm /home/user/.cache/pnpm /tmp/*

WORKDIR /app

EXPOSE 5000

CMD ["bash"]
