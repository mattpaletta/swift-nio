ARG ubuntu_version=16.04
FROM ubuntu:$ubuntu_version as swift_builder
# needed to do again after FROM due to docker limitation
ARG ubuntu_version

ARG DEBIAN_FRONTEND=noninteractive
# do not start services during installation as this will fail and log a warning / error.
RUN echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d

# basic dependencies
RUN apt-get update && apt-get install -y wget git build-essential software-properties-common pkg-config locales libicu-dev libblocksruntime0 lsof dnsutils netcat-openbsd net-tools # used by integration tests

# local
RUN locale-gen en_US.UTF-8 && locale-gen en_US en_US.UTF-8 && dpkg-reconfigure locales && echo 'export LANG=en_US.UTF-8' >> $HOME/.profile && echo 'export LANGUAGE=en_US:en' >> $HOME/.profile && echo 'export LC_ALL=en_US.UTF-8' >> $HOME/.profile

# known_hosts
RUN mkdir -p $HOME/.ssh && touch $HOME/.ssh/known_hosts && ssh-keyscan github.com 2> /dev/null >> $HOME/.ssh/known_hosts

# clang
RUN apt-get update && apt-get install -y clang-3.9 && update-alternatives --install /usr/bin/clang clang /usr/bin/clang-3.9 100 && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-3.9 100

# modern curl, if needed
ARG install_curl_from_source
RUN [ ! -z $install_curl_from_source ] || { apt-get update && apt-get install -y curl libcurl4-openssl-dev libz-dev; }
RUN [ -z $install_curl_from_source ] || { apt-get update && apt-get install -y libssl-dev; }
RUN [ -z $install_curl_from_source ] || mkdir $HOME/.curl
RUN [ -z $install_curl_from_source ] || wget -q https://curl.haxx.se/download/curl-7.50.3.tar.gz -O $HOME/curl.tar.gz
RUN [ -z $install_curl_from_source ] || tar xzf $HOME/curl.tar.gz --directory $HOME/.curl --strip-components=1
RUN [ -z $install_curl_from_source ] || ( cd $HOME/.curl && ./configure --with-ssl && make && make install && cd - )
RUN [ -z $install_curl_from_source ] || ldconfig

# ruby and jazzy for docs generation
ARG skip_ruby_from_ppa
RUN [ -n "$skip_ruby_from_ppa" ] || apt-add-repository -y ppa:brightbox/ruby-ng
RUN [ -n "$skip_ruby_from_ppa" ] || { apt-get update && apt-get install -y ruby2.4 ruby2.4-dev; }
RUN [ -z "$skip_ruby_from_ppa" ] || { apt-get update && apt-get install -y ruby ruby-dev; }
RUN apt-get update && apt-get install -y libsqlite3-dev
RUN gem install jazzy --no-ri --no-rdoc

# swift
ARG swift_version=4.0.3
ARG swift_flavour=RELEASE

RUN mkdir $HOME/.swift && wget -q https://swift.org/builds/swift-${swift_version}-$(echo $swift_flavour | tr A-Z a-z)/ubuntu$(echo $ubuntu_version | sed 's/\.//g')/swift-${swift_version}-${swift_flavour}/swift-${swift_version}-${swift_flavour}-ubuntu${ubuntu_version}.tar.gz -O $HOME/swift.tar.gz && tar xzf $HOME/swift.tar.gz --directory $HOME/.swift --strip-components=1 && echo 'export PATH="$HOME/.swift/usr/bin:$PATH"' >> $HOME/.profile && echo 'export LINUX_SOURCEKIT_LIB_PATH="$HOME/.swift/usr/lib"' >> $HOME/.profile

# script to allow mapping framepointers on linux
RUN mkdir -p $HOME/.scripts && wget -q https://raw.githubusercontent.com/apple/swift/master/utils/symbolicate-linux-fatal -O $HOME/.scripts/symbolicate-linux-fatal && chmod 755 $HOME/.scripts/symbolicate-linux-fatal && echo 'export PATH="$HOME/.scripts:$PATH"' >> $HOME/.profile

