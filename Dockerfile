FROM ubuntu:18.04

ENV DEBIAN_FRONTEND noninteractive

ARG GITHUB_TOKEN
ARG NODE_VERSION=12.18.3
ENV NODE_VERSION $NODE_VERSION
ENV YARN_VERSION 1.13.0

# use "latest" or "next" version for Theia packages
ARG version=latest

# Optionally build a striped Theia application with no map file or .ts sources.
# Makes image ~150MB smaller when enabled
ARG strip=false
ENV strip=$strip

# Unminimize
RUN yes | unminimize \
 && apt-get install -yq man-db manpages manpages-posix \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

#Common deps
RUN apt-get update && \
    apt-get -y install build-essential \
                       curl \
                       git \
                       gpg \
                       python \
                       wget \
                       xz-utils \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

#Install node and yarn
#From: https://github.com/nodejs/docker-node/blob/6b8d86d6ad59e0d1e7a94cec2e909cad137a028f/8/Dockerfile

# gpg keys listed at https://github.com/nodejs/node#release-keys
RUN set -ex \
    && for key in \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    77984A986EBC2AA786BC0F66B01FBB92821C587A \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    ; do \
    gpg --batch --keyserver ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver pgp.mit.edu --recv-keys "$key" || \
    gpg --batch --keyserver keyserver.pgp.com --recv-keys "$key" || \
    gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" ; \
    done

RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" \
    && case "${dpkgArch##*-}" in \
    amd64) ARCH='x64';; \
    ppc64el) ARCH='ppc64le';; \
    s390x) ARCH='s390x';; \
    arm64) ARCH='arm64';; \
    armhf) ARCH='armv7l';; \
    i386) ARCH='x86';; \
    *) echo "unsupported architecture"; exit 1 ;; \
    esac \
    && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
    && curl -SLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
    && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
    && ln -s /usr/local/bin/node /usr/local/bin/nodejs


RUN set -ex \
    && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
    ; do \
    gpg --batch --keyserver ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver pgp.mit.edu --recv-keys "$key" || \
    gpg --batch --keyserver keyserver.pgp.com --recv-keys "$key" || \
    gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" ; \
    done \
    && curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
    && curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
    && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
    && mkdir -p /opt/yarn \
    && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/yarn --strip-components=1 \
    && ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn \
    && ln -s /opt/yarn/bin/yarn /usr/local/bin/yarnpkg \
    && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz

#Developer tools

## Git and sudo (sudo needed for user override)
RUN apt-get update && apt-get -y install git sudo \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

#LSPs

##GO
ENV GO_VERSION=1.15 \
    GOOS=linux \
    GOARCH=amd64 \
    GOROOT=/usr/local/go \
    GOPATH=/usr/local/go-packages
ENV PATH=$GOPATH/bin:$GOROOT/bin:$PATH

# install Go
RUN curl -fsSL https://storage.googleapis.com/golang/go$GO_VERSION.$GOOS-$GOARCH.tar.gz | tar -C /usr/local -xzv

# install VS Code Go tools: https://github.com/Microsoft/vscode-go/blob/058eccf17f1b0eebd607581591828531d768b98e/src/goInstallTools.ts#L19-L45
RUN go get -u -v github.com/mdempsky/gocode && \
    go get -u -v github.com/uudashr/gopkgs/cmd/gopkgs && \
    go get -u -v github.com/ramya-rao-a/go-outline && \
    go get -u -v github.com/acroca/go-symbols && \
    go get -u -v golang.org/x/tools/cmd/guru && \
    go get -u -v golang.org/x/tools/cmd/gorename && \
    go get -u -v github.com/fatih/gomodifytags && \
    go get -u -v github.com/haya14busa/goplay/cmd/goplay && \
    go get -u -v github.com/josharian/impl && \
    go get -u -v github.com/tylerb/gotype-live && \
    go get -u -v github.com/rogpeppe/godef && \
    go get -u -v github.com/zmb3/gogetdoc && \
    go get -u -v golang.org/x/tools/cmd/goimports && \
    go get -u -v github.com/sqs/goreturns && \
    go get -u -v winterdrache.de/goformat/goformat && \
    go get -u -v golang.org/x/lint/golint && \
    go get -u -v github.com/cweill/gotests/... && \
    go get -u -v github.com/alecthomas/gometalinter && \
    go get -u -v honnef.co/go/tools/... && \
    GO111MODULE=on go get github.com/golangci/golangci-lint/cmd/golangci-lint && \
    go get -u -v github.com/mgechev/revive && \
    go get -u -v github.com/sourcegraph/go-langserver && \
    go get -u -v github.com/go-delve/delve/cmd/dlv && \
    go get -u -v github.com/davidrjenni/reftools/cmd/fillstruct && \
    go get -u -v github.com/godoctor/godoctor && \
    go get -u -v -d github.com/stamblerre/gocode && \
    go build -o $GOPATH/bin/gocode-gomod github.com/stamblerre/gocode && \
    rm -rf $HOME/.cache

ENV PATH=$PATH:$GOPATH/bin


#Java
RUN apt-get update && apt-get -y install openjdk-11-jdk maven gradle \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*


#C/C++
# public LLVM PPA, development version of LLVM
ARG LLVM=12

RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
    echo "deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic main" > /etc/apt/sources.list.d/llvm.list && \
    apt-get update && \
    apt-get install -y \
                       clang-tools-$LLVM \
                       clangd-$LLVM \
                       clang-tidy-$LLVM \
                       gcc-multilib \
                       g++-multilib \
                       gdb && \
    ln -s /usr/bin/clang-$LLVM /usr/bin/clang && \
    ln -s /usr/bin/clang++-$LLVM /usr/bin/clang++ && \
    ln -s /usr/bin/clang-cl-$LLVM /usr/bin/clang-cl && \
    ln -s /usr/bin/clang-cpp-$LLVM /usr/bin/clang-cpp && \
    ln -s /usr/bin/clang-tidy-$LLVM /usr/bin/clang-tidy && \
    ln -s /usr/bin/clangd-$LLVM /usr/bin/clangd \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

# Install latest stable CMake
ARG CMAKE_VERSION=3.18.1

RUN wget "https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-Linux-x86_64.sh" && \
    chmod a+x cmake-$CMAKE_VERSION-Linux-x86_64.sh && \
    ./cmake-$CMAKE_VERSION-Linux-x86_64.sh --prefix=/usr/ --skip-license && \
    rm cmake-$CMAKE_VERSION-Linux-x86_64.sh


#Python 2-3
RUN apt-get update \
    && apt-get install -y software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get install -y python-dev python-pip \
    && apt-get install -y python3.8 python3-dev python3-pip \
    && apt-get remove -y software-properties-common \
    && python -m pip install --upgrade pip --user \
    && python3.8 -m pip install --upgrade pip --user \
    && pip install python-language-server flake8 autopep8 \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    PATH=$PATH:/home/${user}/.local/bin


#Ruby
RUN apt-get update && apt-get -y install ruby ruby-dev zlib1g-dev && \
    gem install solargraph \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*


#Docker
# https://docs.docker.com/engine/install/ubuntu/
RUN apt-get update \
 && apt-get remove docker docker-engine docker.io containerd runc \
 && apt-get update \
 && apt-get install -yq apt-transport-https ca-certificates curl gnupg-agent software-properties-common \
 && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
 && echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -yq docker-ce docker-ce-cli containerd.io \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* \
 && curl -fsSL "https://github.com/docker/compose/releases/download/1.27.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
 && chmod 755 /usr/local/bin/docker-compose


# Zsh
RUN apt-get update \
 && apt-get install -yq zsh \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*


# Theia application
##Needed for node-gyp, nsfw build
RUN apt-get update && apt-get install -y python build-essential && \
  apt-get clean && \
  apt-get autoremove -y && \
  rm -rf /var/cache/apt/* && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /tmp/*

# Tools
RUN apt-get update && apt-get -y install vim jq htop tmux screen tree dos2unix \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*


ARG user=theia
ARG group=theia
ARG uid=1000
ARG gid=1000

## User account
RUN mkdir -p /home/${user} \
  && chown ${uid}:${gid} /home/${user} \
  && groupadd -g ${gid} ${group} \
  && useradd -d /home/${user} -u ${uid} -g ${gid} -G sudo -m -s /usr/bin/zsh ${user} \
  && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
ADD settings.json /home/${user}/.theia/

RUN chmod g+rw /home && \
    mkdir -p /home/project && \
    mkdir -p /home/${user}/.pub-cache/bin && \
    mkdir -p /usr/local/cargo && \
    mkdir -p /usr/local/go && \
    mkdir -p /usr/local/go-packages && \
    chown -R ${user}:${group} /home/${user} && \
    chown -R ${user}:${group} /home/project && \
    chown -R ${user}:${group} /usr/local/cargo && \
    chown -R ${user}:${group} /usr/local/go && \
    chown -R ${user}:${group} /usr/local/go-packages

USER ${user}
WORKDIR /home/${user}
ADD $version.package.json ./package.json

RUN if [ "$strip" = "true" ]; then \
yarn --pure-lockfile && \
    NODE_OPTIONS="--max_old_space_size=4096" yarn theia build && \
    yarn theia download:plugins && \
    yarn --production && \
    yarn autoclean --init && \
    echo *.ts >> .yarnclean && \
    echo *.ts.map >> .yarnclean && \
    echo *.spec.* >> .yarnclean && \
    yarn autoclean --force && \
    yarn cache clean \
;else \
yarn --cache-folder ./ycache && rm -rf ./ycache && \
     NODE_OPTIONS="--max_old_space_size=4096" yarn theia build && yarn theia download:plugins \
;fi

# Change permissions to make the `yang-language-server` executable.
RUN chmod +x ./plugins/yangster/extension/server/bin/yang-language-server

EXPOSE 3000
# configure Theia
ENV SHELL=/usr/bin/zsh \
    THEIA_DEFAULT_PLUGINS=local-dir:/home/${user}/plugins  \
    # configure user Go path
    GOPATH=/home/project

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Oh My Zsh
RUN curl -fsSL "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" | sh - \
 && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k \
 && $HOME/.oh-my-zsh/custom/themes/powerlevel10k/gitstatus/install

COPY --chown=${user}:${group} dot-zshrc /home/${user}/.zshrc
COPY --chown=${user}:${group} dot-p10k.zsh /home/${user}/.p10k.zsh

RUN printf '\n\n# Force ZSH\nif [ "$SHLVL" -eq 1 ] ; then exec zsh ; fi\n\n' >> $HOME/.bashrc

ENTRYPOINT exec node "$HOME/src-gen/backend/main.js" /home/project --hostname=0.0.0.0
