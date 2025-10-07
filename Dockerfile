# Claude Code Sandbox Container
# Isolated environment for running Claude Code with generous permissions
# Security enforced by GitHub branch protection rules

FROM node:20-slim

# Install required packages
RUN apt-get update && apt-get install -y \
    git \
    openssh-client \
    curl \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI globally via npm
RUN npm install -g @anthropic-ai/claude-code

# Accept git config as build arguments
ARG GIT_USER_NAME
ARG GIT_USER_EMAIL

# Configure git with user's identity
RUN git config --global user.name "${GIT_USER_NAME}" && \
    git config --global user.email "${GIT_USER_EMAIL}"

# Create workspace directory
WORKDIR /workspace

# Set up SSH directory for node user (non-root)
RUN mkdir -p /home/node/.ssh && chmod 700 /home/node/.ssh && chown -R node:node /home/node/.ssh

# Set up workspace for node user
RUN chown -R node:node /workspace

# Allow node user to chown the .claude directory (for volume ownership fix)
RUN echo "node ALL=(root) NOPASSWD: /bin/chown -R node\\:node /home/node/.claude" > /etc/sudoers.d/node-claude

# Switch to non-root user (required for --dangerously-skip-permissions)
USER node

# Default to bash shell
CMD ["/bin/bash"]
