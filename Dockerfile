FROM --platform=linux/amd64 ubuntu:22.04
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
    # for rbenv
    libssl-dev libreadline-dev zlib1g-dev \
    # for postgres
    libpq-dev \
    ca-certificates \
  && apt-get clean \
  && rm -rf /var/cache/apt/archives/* \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && truncate -s 0 /var/log/*log

RUN adduser --gecos '' user && passwd -d user

RUN mkdir /app && mkdir /bundle && mkdir /home/user/.sfdx && chown user:user /app /bundle /home/user/.sfdx

RUN mkdir -p /nginx && cd /nginx && \
  wget -q --tries 3 -L https://raw.githubusercontent.com/heroku/heroku-buildpack-nginx/main/bin/start-nginx && \
  chmod +x /nginx/start-nginx && \
  chown -R user:user /nginx

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
ENV PATH="$NVM_DIR/versions/node/v18.16.0/bin:$PATH"
RUN /bin/bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash" && bash -c "source $NVM_DIR/nvm.sh && nvm install 18.16.0 && npm install --global yarn@1.22.19"

ENV PATH="./bin:$PATH:./node_modules/.bin/"

# SFDX
RUN npm install -g @salesforce/cli

WORKDIR /app

EXPOSE 5000

CMD bash
