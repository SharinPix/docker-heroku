FROM heroku/heroku:20
MAINTAINER Luc Boissaye <luc@boissaye.fr>

RUN apt update -qq && \
  DEBIAN_FRONTEND=noninteractive apt install -y -qq --no-install-recommends \
    build-essential\
    libpq-dev\
    libxml2-dev\
    libxslt1-dev\
    qt5-default\
    libqt5webkit5-dev\
    gstreamer1.0-plugins-base\
    gstreamer1.0-tools\
    gstreamer1.0-x\
    tar \
    ruby-dev \
    libnss3 \
    libgconf-2-4 \
    sudo \
  && apt autoremove \
  && apt autoclean \
  && rm -rf /var/lib/apt/lists/* \
  && truncate -s 0 /var/log/*log


# RUN apt update -qq \
#   && wget -q https://s3.amazonaws.com/sharinpix-chrome/chrome62.deb -O chrome.deb \
#   && apt install -y -qq ./chrome.deb \
#   && rm chrome.deb \
#   && apt-get autoremove \
#   && apt-get autoclean \
#   && rm -rf /var/lib/apt/lists/* \
#   && truncate -s 0 /var/log/*log \
#   && google-chrome --version

# Ruby heroku
RUN apt remove -y --purge ruby && curl -s --retry 3 -L https://heroku-buildpack-ruby.s3.amazonaws.com/heroku-18/ruby-2.6.6.tgz | tar -xz && \
  bundle config --global silence_root_warning 1

RUN curl -s --retry 3 -L https://s3.amazonaws.com/heroku-nodebin/yarn/release/yarn-v1.22.4.tar.gz | tar -xz -C / --strip-components=1

# Node heroku
RUN export NODE_VERSION=12.18.2 && curl -s --retry 3 -L https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.gz | tar -xz -C / --strip-components=1

RUN mkdir sfdx_install && \
    wget -qO- https://developer.salesforce.com/media/salesforce-cli/sfdx-linux-amd64.tar.xz | tar xJ -C sfdx_install --strip-components 1 && \
    ./sfdx_install/install && \
    export PATH=./sfdx_install/$(pwd):$PATH

RUN rm -rvf sfdx-waw-plugin \
  && git clone -b connected-app-canvas --single-branch https://github.com/SharinPix/sfdx-waw-plugin.git \
  && cd sfdx-waw-plugin && npm install \
  && sfdx plugins:link .

RUN adduser --gecos '' user && passwd -d user && adduser user sudo

RUN mkdir -p /bundle
RUN chown user:user /bundle
RUN chown user:user /lib/node_modules
RUN chown user:user /sfdx-waw-plugin

USER user

ENV BUNDLE_PATH=/bundle \
    BUNDLE_BIN=/bundle/bin \
    GEM_HOME=/bundle

ENV PATH="/home/user/bin:$PATH"

WORKDIR /home/user

EXPOSE 5000

CMD bash
