# Use the official Ubuntu base image
FROM ubuntu:latest

# Set the maintainer label
LABEL maintainer="sean@closedloop.tech"

# Update the package list and install wget and bash
RUN apt-get update && \
    apt-get install -y wget bash && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set the default command to bash
CMD ["bash"]
