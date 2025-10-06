# Claude Code Sandbox Container
# Isolated environment for running Claude Code with generous permissions
# Security enforced by GitHub branch protection rules

FROM node:20-slim

# Install required packages
RUN apt-get update && apt-get install -y \
    git \
    openssh-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI
RUN npm install -g @anthropic/claude-code

# Accept git config as build arguments
ARG GIT_USER_NAME
ARG GIT_USER_EMAIL

# Configure git with user's identity
RUN git config --global user.name "${GIT_USER_NAME}" && \
    git config --global user.email "${GIT_USER_EMAIL}"

# Create workspace directory
WORKDIR /workspace

# Set up SSH directory for deploy key
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# Default to bash shell
CMD ["/bin/bash"]
