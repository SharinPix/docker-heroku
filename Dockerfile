FROM node:22.21.1-alpine AS node

# Prebuilt Ruby 4.0.6 on Alpine 3.24. Node 22.21.1 is copied from the
# official Alpine image instead of being compiled in this build.
FROM ruby:4.0.6-alpine

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node /usr/local/include/node /usr/local/include/node

RUN ln -sf node /usr/local/bin/nodejs \
  && ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
  && ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
  && ln -sf ../lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack

# Alpine equivalents of the Ubuntu build packages. libstdc++ is required by
# the musl Node binary. postgresql18-client and libpq-dev replace the
# Ubuntu postgresql-client and libpq-dev packages.
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    build-base \
    linux-headers \
    git \
    vim \
    ca-certificates \
    openssl \
    openssl-dev \
    readline-dev \
    zlib-dev \
    libffi-dev \
    yaml-dev \
    gnupg \
    postgresql18-client \
    libpq \
    libpq-dev \
    libstdc++ \
    tar \
    gzip \
    xz \
    coreutils \
    findutils \
    procps \
    patch \
    autoconf \
    bison \
    pkgconf \
    bzip2-dev \
    gdbm-dev \
    ncurses-dev \
    python3

# Alpine has no default ubuntu user. Create node with UID 1000 so bind
# mounts from a typical developer host do not hit permission conflicts.
RUN adduser -D -u 1000 -s /bin/bash node

RUN mkdir -p /app /nginx /bundle /home/node/.sfdx /home/node/npm /app/.pnpm-store /app/ember/tmp /var/log/nginx \
  && chown -R node:node /app /bundle /home/node/.sfdx /nginx /var/log/nginx /home/node /app/.pnpm-store /app/ember

# Alpine's /etc/profile replaces PATH on login shells.
RUN printf '%s\n' \
  'export PNPM_HOME=/home/node/.local/share/pnpm' \
  'export PATH="$PNPM_HOME:/home/node/.local/bin:/usr/local/bin:$PATH"' \
  > /etc/profile.d/dev-tools.sh

ENV PNPM_HOME="/home/node/.local/share/pnpm"
ENV PATH="${PNPM_HOME}:/home/node/.local/bin:/usr/local/bin:${PATH}:./bin:./node_modules/.bin"
ENV npm_config_store_dir="/app/.pnpm-store"
ENV npm_config_cache="/home/node/npm"

USER node

RUN npm install --global pnpm@10.27.0 --prefix /home/node/.local \
  && pnpm config set store-dir /app/.pnpm-store \
  && SHELL=bash pnpm setup \
  && pnpm add -g @salesforce/cli \
  && find /home/node/npm -mindepth 1 -delete \
  && rm -rf /home/node/.npm /home/node/.cache/pnpm /tmp/*

# Nginx (build_nginx defaults to zlib 1.3.1; zlib.net no longer hosts that tarball — use 1.3.2)
RUN git clone --depth 1 -b patch-1 https://github.com/ombr/heroku-buildpack-nginx.git /nginx && \
  ZLIB_VERSION=1.3.2 /nginx/scripts/build_nginx /nginx/nginx.tgz && \
  cat /nginx/nginx.tgz | tar -xvz -C /nginx && \
  cp /nginx/bin/start-nginx /nginx/ && \
  chmod +x /nginx/start-nginx /nginx/nginx && \
  rm -rf /nginx/.git /nginx/nginx.tgz /nginx/*.md /tmp/*

WORKDIR /app

EXPOSE 5000

CMD ["bash"]
