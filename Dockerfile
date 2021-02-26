FROM heroku/heroku:20

RUN apt-get update -qq && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    # ruby-dev
    build-essential\
    git \
    vim \
    # rbenv
    libssl-dev libreadline-dev zlib1g-dev \
    # postgres
    libpq-dev \
    # Nokogiri
    libxml2-dev \
    libxslt1-dev \
  && apt-get clean \
  && rm -rf /var/cache/apt/archives/* \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && truncate -s 0 /var/log/*log

RUN adduser --gecos '' user && passwd -d user

USER user

ENV PATH="/home/user/.rbenv/bin:/home/user/.rbenv/shims:$PATH"
RUN bash -c "curl -fsSL https://github.com/rbenv/rbenv-installer/raw/master/bin/rbenv-installer | bash" && \
  bash -c "rbenv install 2.6.6"
RUN echo 'eval "$(rbenv init -)"' >> /home/user/.bashrc
RUN bash -c "rbenv global 2.6.6"
RUN bash -c "/home/user/.rbenv/shims/gem install bundler:1.17.3"

ENV NVM_DIR /home/user/.nvm
RUN bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash" && bash -c "source $NVM_DIR/nvm.sh && nvm install 12.18.2 && npm install --global yarn@1.22.4"

WORKDIR /home/user/app

EXPOSE 5000

CMD bash
