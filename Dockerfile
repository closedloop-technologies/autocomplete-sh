FROM ubuntu:24.04

LABEL maintainer="sean@closedloop.tech"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        bash-completion \
        bats \
        bc \
        ca-certificates \
        curl \
        jq \
        shellcheck \
        wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY autocomplete.sh README.md run_tests.sh ./
COPY docs ./docs
COPY tests ./tests

RUN chmod +x autocomplete.sh run_tests.sh docs/install.sh

ENTRYPOINT ["./run_tests.sh"]
