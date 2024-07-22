# Use the official Ubuntu base image
FROM ubuntu:latest

# Set the maintainer label
LABEL maintainer="sean@closedloop.tech"

# Update the package list and install wget and bash
RUN apt-get update && \
    apt-get install -y bash curl wget jq bc bash-completion vim bats && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create directory for tests
RUN mkdir tests
# Copy the BATS tests to the container
COPY tests tests

# Add bash-completion sourcing to .bashrc
RUN echo "\nif [ -f /etc/bash_completion ] && ! shopt -oq posix; then\n    . /etc/bash_completion\nfi"  >> /root/.bashrc

# Set the entrypoint to run BATS tests
ENTRYPOINT ["bats"]
CMD ["tests"]