FROM alpine:3.24

# Alpine equivalents of the Ubuntu build packages. libstdc++ is required by
# the musl Node binaries. postgresql18-client and libpq-dev replace the
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

RUN mkdir -p /app /nginx /bundle /home/node/.sfdx /var/log/nginx \
  && chown -R node:node /app /bundle /home/node/.sfdx /nginx /var/log/nginx /home/node

RUN mkdir -p /home/node/npm /app/.pnpm-store /app/ember/tmp && chown -R node:node /home/node/npm /app/.pnpm-store /app/ember/tmp /app/ember

USER node

# Ruby
RUN bash -c "git clone https://github.com/rbenv/rbenv.git ~/.rbenv"
ENV PATH="/home/node/.rbenv/bin:/home/node/.rbenv/shims:$PATH"
RUN bash -c "curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash" && \
  echo 'eval "$(rbenv init -)"' >> /home/node/.bashrc && \
  MAKE_OPTS="-j2" bash -c "rbenv install 4.0.6" && \
  bash -c "rbenv global 4.0.6" && \
  bash -c "/home/node/.rbenv/shims/gem install bundler" && \
  rm -rf /home/node/.rbenv/cache /tmp/*

# Node. Official nodejs.org tarballs are glibc-linked and do not run on
# Alpine, so install the musl builds. v22.21.1 is published for both
# x64-musl and arm64-musl.
ENV NVM_DIR=/home/node/.nvm
ENV NVM_NODEJS_ORG_MIRROR=https://unofficial-builds.nodejs.org/download/release
ENV PATH="$NVM_DIR/versions/node/v22.21.1/bin:$PATH"
ENV npm_config_cache=/home/node/npm

RUN bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | bash && source $NVM_DIR/nvm.sh && nvm install 22.21.1 && npm install --global pnpm@10.27.0 && SHELL=bash pnpm setup && pnpm config set store-dir /app/.pnpm-store && npm cache clean --force && rm -rf /home/node/.cache/pnpm /tmp/* && mkdir -p /home/node/npm"

# Set environment
ENV PATH="./bin:$PATH:./node_modules/.bin/"
ENV PNPM_HOME="/home/node/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# SFDX
RUN bash -c "source $NVM_DIR/nvm.sh && pnpm add -g @salesforce/cli && rm -rf /home/node/.cache/pnpm /tmp/*"

# Nginx (build_nginx defaults to zlib 1.3.1; zlib.net no longer hosts that tarball — use 1.3.2)
RUN git clone --depth 1 -b patch-1 https://github.com/ombr/heroku-buildpack-nginx.git /nginx && \
  ZLIB_VERSION=1.3.2 /nginx/scripts/build_nginx /nginx/nginx.tgz && \
  cat /nginx/nginx.tgz | tar -xvz -C /nginx && \
  cp /nginx/bin/start-nginx /nginx/ && \
  chmod +x /nginx/start-nginx /nginx/nginx && \
  rm -rf /nginx/.git /nginx/nginx.tgz /nginx/*.md /tmp/*

# Alpine's /etc/profile replaces PATH on login shells, which drops rbenv,
# Node, and pnpm. Put them back before the rbenv snippet in ~/.bash_profile.
RUN printf '%s\n' 'export PATH="/home/node/.local/share/pnpm:/home/node/.nvm/versions/node/v22.21.1/bin:/home/node/.rbenv/bin:/home/node/.rbenv/shims:$PATH"' \
  | cat - /home/node/.bash_profile > /home/node/.bash_profile.new \
  && mv /home/node/.bash_profile.new /home/node/.bash_profile

WORKDIR /app/ember

EXPOSE 5000

CMD ["bash"]
