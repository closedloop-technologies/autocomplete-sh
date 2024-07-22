# Use the official Ubuntu base image
FROM ubuntu:latest

# Set the maintainer label
LABEL maintainer="sean@closedloop.tech"

# Update the package list and install wget and bash
RUN apt-get update && \
    apt-get install -y wget bash jq bash-completion && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add bash-completion sourcing to .bashrc
# RUN echo 'if [ -f /etc/bash_completion ]; then\n    . /etc/bash_completion\nfi' >> /root/.bashrc

# Copy the autocomplete script to /usr/local/bin
# COPY ./docs/install.sh install.sh

# Set the default command to bash
CMD ["bash"]
