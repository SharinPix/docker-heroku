FROM ubuntu:22.04
# FROM heroku/heroku:22

RUN apt-get update -qq && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    # for ruby-dev
    curl \
    wget \
    build-essential\
    git \
    vim \
    nginx \
    ca-certificates \
    # for rbenv
    libssl-dev libreadline-dev zlib1g-dev libffi-dev libyaml-dev \
    gnupg2 lsb-release \
  && apt-get clean \
  && rm -rf /var/cache/apt/archives/* \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && truncate -s 0 /var/log/*log

RUN sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
  && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
  && apt-get update -qq \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
  postgresql-client libpq-dev \
  && apt-get clean \
  && rm -rf /var/cache/apt/archives/* \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && truncate -s 0 /var/log/*log

RUN adduser --gecos '' user && passwd -d user

RUN mkdir /app && mkdir /nginx && mkdir /bundle && mkdir /home/user/.sfdx && chown user:user /app /bundle /home/user/.sfdx /nginx /var/log/nginx

USER user

# Ruby
RUN bash -c "git clone https://github.com/rbenv/rbenv.git ~/.rbenv"
ENV PATH="/home/user/.rbenv/bin:/home/user/.rbenv/shims:$PATH"
RUN bash -c "curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash" && \
  echo 'eval "$(rbenv init -)"' >> /home/user/.bashrc && \
  bash -c "rbenv install 3.1.2" && \
  bash -c "rbenv global 3.1.2" && \
  bash -c "/home/user/.rbenv/shims/gem install bundler"

# Node
ENV NVM_DIR /home/user/.nvm
ENV PATH="$NVM_DIR/versions/node/v20.16.0/bin:$PATH"

RUN bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash" && bash -c "source $NVM_DIR/nvm.sh && nvm install 20.16.0 && npm install --global yarn@1.22.19"

ENV PATH="./bin:$PATH:./node_modules/.bin/"

# SFDX
RUN yarn global add @salesforce/cli

# Nginx
RUN git clone  --depth 1 -b patch-1 https://github.com/ombr/heroku-buildpack-nginx.git /nginx &&  \
/nginx/scripts/build_nginx /nginx/nginx.tgz && \
cat /nginx/nginx.tgz | tar -xvz -C /nginx  && \
cp /nginx/bin/start-nginx /nginx/ && \
chmod +x /nginx/start-nginx /nginx/nginx && \
rm -rvf *.tgz .git *.md

WORKDIR /app

EXPOSE 5000

CMD bash
