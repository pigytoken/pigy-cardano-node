FROM ubuntu:20.04 as builder
LABEL Maintainer="PIGYToken <support@pigytoken.com>" \
    Description="Cardano-node" \
    version="1.0.0"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev \
    zlib1g-dev make g++ tmux git jq curl libncursesw5 libtool autoconf llvm libnuma-dev

# GHC install
WORKDIR /build/ghc

RUN curl https://downloads.haskell.org/~ghc/8.10.4/ghc-8.10.4-x86_64-deb10-linux.tar.xz | \
    tar -Jx -C /build/ghc

RUN cd ghc-8.10.4 && ./configure && make install

# Libsodium install
WORKDIR /build/libsodium
RUN git clone https://github.com/input-output-hk/libsodium
RUN cd libsodium && \
    git checkout 66f017f1 && \
    ./autogen.sh && ./configure && make && make install

ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

# Cabal install
RUN curl -L https://downloads.haskell.org/~cabal/cabal-install-3.4.0.0/cabal-install-3.4.0.0-x86_64-ubuntu-16.04.tar.xz | \
    tar -Jx -C /usr/bin/
RUN cabal update

# Cardano source
WORKDIR /build/cardano-node
RUN git clone --branch 1.30.1 https://github.com/input-output-hk/cardano-node.git && \
    cd cardano-node && \
    cabal configure --with-compiler=ghc-8.10.4 && \
    cabal build all

FROM ubuntu:20.04

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends netbase jq libnuma-dev curl nano htop bc rsync && \
    rm -rf /var/lib/apt/lists/*

# Libsodium
COPY --from=builder /usr/local/lib /usr/local/lib

ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"

COPY config/mainnet /etc/config
COPY config/testnet /etc/config

COPY --from=builder /build/cardano-node/cardano-node/dist-newstyle/build/x86_64-linux/ghc-8.10.4/cardano-node-1.30.1/x/cardano-node/build/cardano-node/cardano-node /usr/local/bin/
COPY --from=builder /build/cardano-node/cardano-node/dist-newstyle/build/x86_64-linux/ghc-8.10.4/cardano-cli-1.30.1/x/cardano-cli/build/cardano-cli/cardano-cli /usr/local/bin/

ENTRYPOINT ["bash", "-c"]