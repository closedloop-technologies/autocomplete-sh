# Use the official Ubuntu base image
FROM ubuntu:latest

# Set the maintainer label
LABEL maintainer="sean@closedloop.tech"

# Update the package list and install the toolchain needed by the offline
# Bats suite: both runtimes (bash/zsh), network mocks (curl/wget/jq/bc),
# bash-completion (lazy-load fixtures) and the test runner (bats).
RUN apt-get update && \
    apt-get install -y bash zsh curl wget jq bc bash-completion vim bats && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy the BATS tests to the container
COPY tests tests
# Copy the repo runtime scripts and installer to the image root so the
# containerized suite can stage them into isolated temp HOMEs (tests resolve
# the repo root relative to the tests/ directory).
COPY autocomplete.sh autocomplete.zsh /
COPY docs /docs

# Add bash-completion sourcing to .bashrc
RUN echo "\nif [ -f /etc/bash_completion ] && ! shopt -oq posix; then\n    . /etc/bash_completion\nfi"  >> /root/.bashrc

# Set the entrypoint to run BATS tests
ENTRYPOINT ["bats"]
CMD ["tests"]