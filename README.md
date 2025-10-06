# Claudebox

**Isolated Docker sandbox for running Claude Code with maximum autonomy and GitHub-enforced security.**

## What is Claudebox?

Claudebox provides a safe, isolated environment where Claude Code can work autonomously on your repositories with bypassed permissions (`--dangerously-skip-permissions`), while GitHub's server-side branch protection ensures critical operations like pushing to `main` are blocked.

**Perfect for:**
- Letting Claude work independently without constant permission prompts
- Experimenting with AI-generated code in isolation
- Protecting your main branch while enabling feature development
- Running untrusted or experimental Claude Code sessions

## Key Features

🔒 **Filesystem Isolation** - Container cannot access your host files
🚫 **Protected Branches** - GitHub blocks pushes to `main` (server-side enforcement)
✅ **Feature Branches** - Claude can create branches and pull requests
🧹 **Auto-cleanup** - Container destroyed on exit, no persistence
⚡ **Full Autonomy** - Runs with `--dangerously-skip-permissions` safely
🐳 **Docker-based** - Lightweight, portable, no complex setup

## Quick Start

### Prerequisites

- Docker installed and running
- Git configured with your name and email
- GitHub repository you want to work on

### Installation

```bash
# Clone this repository
git clone https://github.com/username/claudebox.git
cd claudebox

# Run installer
./install.sh
```

The installer will:
1. Build the Docker image with your git config
2. Generate an SSH deploy key (`~/.ssh/sandbox_deploy_key`)
3. Install the `sandbox` command to `~/bin/`
4. Display GitHub setup instructions

### GitHub Setup (One-Time)

**1. Add deploy key to your repository:**

```
Repository → Settings → Deploy keys → Add deploy key

Title: claudebox
Key: [paste contents of ~/.ssh/sandbox_deploy_key.pub]
✅ Allow write access
❌ Do NOT check "Allow this key to push to protected branches"
```

**2. Enable branch protection:**

```
Repository → Settings → Branches → Add branch protection rule

Branch pattern: main
✅ Require pull request before merging
```

### Usage

```bash
# Launch sandbox with a repository
sandbox git@github.com:username/repository.git

# Or with HTTPS
sandbox https://github.com/username/repository.git

# Enable network access (for package installation)
sandbox --network git@github.com:username/repository.git
```

Inside the sandbox:
- Claude Code launches with bypassed permissions
- Work on code, make commits
- Push feature branches, create PRs
- Exit with `Ctrl+D` - container auto-destroys

## How It Works

```
┌─────────────────────────────────────────┐
│ Your Host Machine                       │
│  - Your git credentials (full access)   │
│  - Protected from sandbox               │
└─────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│ Docker Container (Isolated)              │
│  - Clones git repo                       │
│  - Uses limited deploy key               │
│  - Claude with bypassed permissions      │
│  - Destroyed on exit                     │
└─────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│ GitHub (Server-Side Enforcement)         │
│  - Deploy key can push to branches      │
│  - Deploy key CANNOT push to main       │
│  - Branch protection enforced            │
└─────────────────────────────────────────┘
```

## Security Model

### What Claude CAN Do

✅ Read/edit/create any files in the cloned repo
✅ Run any commands (bypassed permissions enabled)
✅ Commit changes
✅ Create and push feature branches
✅ Create pull requests
✅ Install packages (with `--network` flag)

### What Claude CANNOT Do

❌ Push to `main` branch (GitHub rejects server-side)
❌ Bypass branch protection rules
❌ Access your host filesystem
❌ Access your personal git credentials
❌ Persist changes outside git commits
❌ Access network (without `--network` flag)

### Why It's Safe

**Server-side enforcement:** GitHub's branch protection is enforced on their servers, not locally. Claude cannot bypass it regardless of permissions inside the container.

**Credential isolation:** Your personal credentials never enter the sandbox. The deploy key has GitHub-enforced limitations.

**Filesystem isolation:** Docker containers cannot access parent directories. Everything is destroyed on exit.

## Documentation

- [Installation Guide](README.md#installation)
- [GitHub Setup](README.md#github-setup-one-time)
- [Usage Examples](README.md#usage)
- [Troubleshooting](README.md#troubleshooting)
- [Security Model](README.md#security-model)
- [FAQ](README.md#faq)

## Troubleshooting

### "Failed to clone repository"

**Causes:** Deploy key not added, wrong URL, or network disabled

**Solution:**
```bash
# Verify deploy key
cat ~/.ssh/sandbox_deploy_key.pub

# Try with network
sandbox --network git@github.com:user/repo.git
```

### "Permission denied (publickey)"

**Cause:** Deploy key not configured

**Solution:**
```bash
# Check key exists
ls -la ~/.ssh/sandbox_deploy_key*

# Re-add to GitHub (Settings → Deploy keys)
```

### "Protected branch update failed"

**This is expected!** Branch protection is working. Claude should push to feature branches:
```bash
git checkout -b feature-name
git push origin feature-name
```

### More Issues?

See the full [Troubleshooting section](#troubleshooting) in the documentation.

## FAQ

**Q: Can Claude access my other repositories?**
A: No. Deploy keys are per-repository. It only works where you add it.

**Q: What if I want Claude to push to main?**
A: Remove branch protection on GitHub, but this defeats the security model.

**Q: Does this work with private repos?**
A: Yes! Use the `--network` flag when cloning.

**Q: How do I create PRs from the sandbox?**
A: Claude pushes the branch, then you create the PR from GitHub UI (or authenticate `gh` CLI in container).

**Q: Can I save container state?**
A: No, by design. The container is ephemeral. Commit and push all changes.

## Uninstallation

```bash
./uninstall.sh
```

Removes Docker image, containers, and the `sandbox` command.

**Deploy key:** Preserved by default. To remove:
```bash
rm ~/.ssh/sandbox_deploy_key*
```

Don't forget to remove from GitHub: **Settings → Deploy keys → Delete**

## Contributing

Issues and pull requests welcome!

## License

MIT License - See LICENSE file for details

## Related Projects

- [Claude Code](https://claude.com/code) - Official Claude Code CLI
- [Model Context Protocol](https://modelcontextprotocol.io/) - MCP specification
