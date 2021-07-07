FROM heroku/heroku:20

RUN apt-get update -qq && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    # for ruby-dev
    build-essential\
    git \
    vim \
    # for rbenv
    libssl-dev libreadline-dev zlib1g-dev \
    # for postgres
    libpq-dev \
  && apt-get clean \
  && rm -rf /var/cache/apt/archives/* \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && truncate -s 0 /var/log/*log

RUN adduser --gecos '' user && passwd -d user

RUN mkdir /app && mkdir /bundle && mkdir /home/user/.sfdx && mkdir /home/user/sfdx && chown user:user /app /bundle /home/user/.sfdx /home/user/sfdx

USER user

ENV PATH="/home/user/.rbenv/bin:/home/user/.rbenv/shims:$PATH"
RUN bash -c "curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash" && \
  bash -c "rbenv install 2.7.3" && \
  echo 'eval "$(rbenv init -)"' >> /home/user/.bashrc && \
  bash -c "rbenv global 2.7.3" && \
  bash -c "/home/user/.rbenv/shims/gem install bundler:1.17.3"

ENV NVM_DIR /home/user/.nvm
ENV PATH="$NVM_DIR/versions/node/v14.17.0/bin:$PATH"
RUN bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash" && bash -c "source $NVM_DIR/nvm.sh && nvm install 14.17.0 && npm install --global yarn@1.22.4"

# https://thoughtbot.com/blog/git-safe
ENV PATH="./.git/safe/../../bin:$PATH"
# for sfdx
ENV PATH="/home/user/sfdx/bin:$PATH"

WORKDIR /app

EXPOSE 5000

CMD bash
