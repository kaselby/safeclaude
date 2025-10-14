# SafeClaude

Run Claude Code in an isolated Docker container with GitHub-enforced security restrictions.

## Overview

SafeClaude provides a safe environment for Claude to work autonomously on your code with minimal permission prompts, while ensuring critical protections through GitHub's server-side branch protection rules.

**Key Features:**
- 🔒 **Per-project deploy keys**: Isolated credentials for each repository
- 🚫 **Protected branches**: GitHub blocks pushes to `main` (enforced server-side)
- ✅ **Multi-project support**: Manage multiple repositories with ease
- 🔄 **Parallel agents**: Run multiple Claude instances simultaneously
- 💾 **Optional persistence**: Save Claude config between sessions
- 🧹 **Ephemeral workspaces**: Code deleted on exit (security feature)
- ⚡ **Full autonomy**: Runs with `--dangerously-skip-permissions` safely

## How It Works

```
┌─────────────────────────────────────────┐
│ Your Host Machine                       │
│  - Per-project deploy keys              │
│  - Project registry                     │
│  - Protected from sandbox               │
└─────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│ Docker Container (Isolated)              │
│  - Clones git repo                       │
│  - Uses project-specific deploy key      │
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

## Prerequisites

- **Docker** installed and running ([Get Docker](https://docs.docker.com/get-docker/))
- **Git** configured with your name and email
- **GitHub CLI** (`gh`) installed and authenticated ([Get gh](https://cli.github.com/))
- **jq** for JSON processing (`brew install jq` or `apt-get install jq`)

## Installation

1. **Run the installer:**
   ```bash
   cd safeclaude
   ./install.sh
   ```

2. **The installer will:**
   - Build the Docker image with your git config
   - Create `~/.safeclaude/` directory structure
   - Install the `safeclaude` command to `~/bin/`
   - Initialize project registry

3. **Add to PATH** (if needed):
   ```bash
   echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc  # or ~/.zshrc
   source ~/.bashrc
   ```

4. **Authenticate with GitHub:**
   ```bash
   gh auth login
   ```

---

## Quick Start

### 1. Setup a Project

```bash
safeclaude setup myrepo git@github.com:user/myrepo.git
```

This will:
- Generate a unique deploy key for this project
- Automatically add the deploy key to GitHub
- Enable branch protection on `main`
- Save the project to your registry

### 2. Run Claude Code

```bash
safeclaude run myrepo
```

That's it! Claude Code launches in an isolated container with your project code.

### 3. Using Tmux for Shell Access

Claude runs inside a tmux session, giving you the ability to switch between Claude and a shell without exiting the container.

**Common tmux keybindings:**
- `Ctrl+B C` - Create a new shell window
- `Ctrl+B N` - Switch to next window
- `Ctrl+B P` - Switch to previous window
- `Ctrl+B D` - Detach from tmux (container keeps running)
- `Ctrl+B ?` - Show all keybindings

**Example workflow:**
1. Start Claude: `safeclaude run myrepo`
2. Press `Ctrl+B C` to open a shell window
3. Explore the container: `ls ~/.claude/projects/`, `ps aux`, etc.
4. Press `Ctrl+B P` to switch back to Claude
5. Press `Ctrl+B D` to detach (container stays alive)
6. Reattach later: `docker exec -it safeclaude-myrepo-<id> tmux attach-session -t claude`

**Note**: When you detach with `Ctrl+B D`, the container continues running. When Claude exits (from any window), the tmux session ends and the container auto-removes as usual.

---

## Command Reference

### Project Management

#### Setup a New Project
```bash
safeclaude setup <name> <repo-url>
```

Generates deploy key, adds it to GitHub, enables branch protection, and saves to registry.

**Example:**
```bash
safeclaude setup myapi git@github.com:user/myapi.git
```

#### List All Projects
```bash
safeclaude list
```

Shows all configured projects with their GitHub URLs and last used timestamps.

#### Remove a Project
```bash
safeclaude remove <name>
```

Removes project from registry and deletes local deploy key. (Deploy key on GitHub must be removed manually.)

---

### Running Projects

#### Basic Run
```bash
safeclaude run <name>
```

Launches Claude Code in an isolated container for the specified project.

#### Run with Options
```bash
safeclaude run <name> --network --persist
```

**Options:**
- `--network`: Enable network access in container (disabled by default for security)
- `--persist`: Persist Claude's config and conversation history between sessions
- `--use-host-prompt=true/false`: Copy CLAUDE.md (default: true)
- `--use-host-agents=true/false`: Copy agents/ directory (default: true)
- `--use-host-commands=true/false`: Copy commands/ directory (default: true)

**Examples:**
```bash
# Basic run (network isolated, ephemeral, with host config)
safeclaude run myrepo

# Enable network (for installing packages)
safeclaude run myrepo --network

# Enable persistence (Claude remembers context)
safeclaude run myrepo --persist

# Disable copying slash commands (useful if they depend on MCP tools)
safeclaude run myrepo --use-host-commands=false

# Disable all host config for this run
safeclaude run myrepo --use-host-prompt=false --use-host-agents=false --use-host-commands=false

# Set permanent defaults via config
safeclaude config set use_host_commands false
safeclaude run myrepo  # Will use config default
```

---

### Parallel & Background Mode

#### Start in Background
```bash
safeclaude start <project-name> <agent-name>
```

Starts Claude running in the background (detached container).

**Example:**
```bash
safeclaude start myrepo agent-1
```

#### Attach to Running Agent
```bash
safeclaude attach <agent-name>
```

Connect to a running background agent. Press `Ctrl+P`, `Ctrl+Q` to detach without stopping.

**Example:**
```bash
safeclaude attach myrepo-agent-1
```

#### View Agent Logs
```bash
safeclaude logs <agent-name> [-f]
```

View logs from a running agent. Use `-f` to follow logs in real-time.

**Example:**
```bash
safeclaude logs myrepo-agent-1 -f
```

#### List Running Containers
```bash
safeclaude ps
```

Shows all running SafeClaude containers.

#### Stop an Agent
```bash
safeclaude stop <agent-name>
```

Stops and removes a background agent.

**Example:**
```bash
safeclaude stop myrepo-agent-1
```

---

## Workflows

### Working on Multiple Projects

```bash
# Setup projects once
safeclaude setup frontend git@github.com:user/frontend.git
safeclaude setup backend git@github.com:user/backend.git
safeclaude setup mobile git@github.com:user/mobile.git

# Later, easy to switch
safeclaude list               # See what you have
safeclaude run frontend       # Work on frontend
safeclaude run backend        # Work on backend
```

### Parallel Work on Same Project

```bash
# Terminal 1: Work on feature A
safeclaude run myrepo

# Terminal 2: Work on feature B (automatically gets unique container)
safeclaude run myrepo
```

### Background Agents

```bash
# Start multiple agents
safeclaude start myrepo auth-feature
safeclaude start myrepo ui-feature

# Check what's running
safeclaude ps

# View logs
safeclaude logs myrepo-auth-feature -f

# Attach to one
safeclaude attach myrepo-ui-feature

# Stop when done
safeclaude stop myrepo-auth-feature
safeclaude stop myrepo-ui-feature
```

### Persistent Context

```bash
# Day 1
safeclaude run myrepo --persist
# Claude learns about your codebase
# Exit

# Day 2
safeclaude run myrepo --persist
# Claude remembers previous conversation
# Continues where you left off
```

---

## Host Configuration Copying

By default, SafeClaude copies your host `~/.claude/` configuration into the container so Claude has access to your preferences, custom agents, and slash commands.

### What Gets Copied

✅ **CLAUDE.md** - Your global instructions and coding preferences
  - SafeClaude appends sandbox-specific instructions about branch protection and PRs

✅ **agents/** - Custom agents (e.g., research-librarian, elite-code-reviewer)
  - Enables Agent Research Library and other custom agents

✅ **commands/** - Slash commands (e.g., /commit, /review-pr)
  - Your custom workflows available in the sandbox

### What Doesn't Get Copied

❌ **config.json** - Host-specific settings (incompatible with container environment)

❌ **mcp_config.json** - MCP tools configuration
  - Reason: MCP servers run on host and can't be accessed from isolated container
  - Future: May add MCP support with in-container servers

❌ **Conversation history and cache** - Fresh start each session (unless `--persist` is used)

### Fine-Grained Control

You can selectively enable/disable which host config gets copied:

```bash
# Disable only slash commands (keep prompt and agents)
safeclaude run myrepo --use-host-commands=false

# Disable prompt but keep agents and commands
safeclaude run myrepo --use-host-prompt=false

# Completely clean environment
safeclaude run myrepo --use-host-prompt=false --use-host-agents=false --use-host-commands=false
```

**Set permanent defaults:**

```bash
# Disable slash commands by default (e.g., if they depend on MCP tools)
safeclaude config set use_host_commands false

# View current config
safeclaude config list

# Override config for a single run
safeclaude run myrepo --use-host-commands=true
```

This is useful for:
- Disabling MCP-dependent slash commands
- Testing with vanilla Claude Code settings
- Avoiding conflicts with host-specific instructions
- Debugging issues related to custom config

### Custom Sandbox Instructions

SafeClaude appends custom instructions to your `CLAUDE.md` to inform Claude about the sandbox environment (branch protection, ephemeral filesystem, etc.).

**Default instructions** are stored in `~/.safeclaude/sandbox_instructions.md` (created during installation from `default_instructions.md`).

**Customize the instructions:**

```bash
# Edit the instructions file directly
nano ~/.safeclaude/sandbox_instructions.md

# Or use your own file
safeclaude config set sandbox_instructions_file /path/to/your/instructions.md
```

**Example custom instructions:**

```markdown
# My Custom Sandbox Instructions

## Important Reminders
- Always run tests before committing
- Follow the project's coding style guide
- Document all new functions

## Workflow
1. Create a feature branch
2. Make changes
3. Run `npm test`
4. Push and create PR
```

The instructions are appended to your `CLAUDE.md` when the container starts, so Claude sees both your global instructions and the sandbox-specific context.

---

## Security Model

### What Claude CAN Do in Sandbox

✅ Read/edit/create any files in the cloned repo
✅ Run any commands (`--dangerously-skip-permissions` enabled)
✅ Commit changes
✅ Create and push feature branches
✅ Create pull requests (if `gh` is authenticated)
✅ Install packages (with `--network` flag)
✅ Use your custom agents and slash commands (via `--host-config`)

### What Claude CANNOT Do

❌ Push to `main` branch (GitHub rejects it server-side)
❌ Bypass branch protection rules
❌ Access your host filesystem
❌ Access your personal git credentials
❌ Persist changes outside of git commits
❌ Access network without `--network` flag

### Why It's Safe

**Server-side enforcement:** GitHub's branch protection is enforced on their servers. Even if Claude tries to bypass restrictions inside the container, GitHub will reject the push.

**Per-project credentials:** Each project has its own isolated deploy key. If one key is compromised, only that project is affected.

**Ephemeral workspaces:** The code directory is deleted when the container exits (even with `--persist`). Only Claude's config persists, not the code.

**Container isolation:** Docker containers cannot access parent directories on the host. The container is destroyed on exit, so no local state persists.

**No bypass possible:** The security model doesn't rely on local permissions or git hooks (which can be bypassed). It relies on GitHub's authentication and authorization system.

---

## Directory Structure

```
~/.safeclaude/
  ├── config.json            # User preferences
  ├── projects.json          # Project registry
  └── keys/                  # Per-project deploy keys
      ├── myrepo/
      │   ├── deploy_key     # Private key for myrepo
      │   └── deploy_key.pub # Public key for myrepo
      └── other-repo/
          ├── deploy_key
          └── deploy_key.pub
```

---

## Configuration

User preferences are stored in `~/.safeclaude/config.json`:

```json
{
  "default_persist": false,
  "default_network": false,
  "auto_setup_branch_protection": true
}
```

**Options:**
- `default_persist`: Set to `true` to make `--persist` the default
- `default_network`: Set to `true` to make `--network` the default
- `auto_setup_branch_protection`: Whether to automatically enable branch protection during setup

---

## Troubleshooting

### "Failed to clone repository"

**Causes:**
- Deploy key not added to GitHub
- Wrong repository URL
- Network disabled (use `--network` flag)

**Solution:**
```bash
# Verify deploy key was added
safeclaude list

# Try with network enabled
safeclaude run myrepo --network

# Re-setup if needed
safeclaude setup myrepo git@github.com:user/repo.git
```

### "Permission denied (publickey)"

**Cause:** Deploy key not properly configured

**Solution:**
```bash
# Check deploy key exists
ls -la ~/.safeclaude/keys/myrepo/

# Re-setup the project
safeclaude setup myrepo git@github.com:user/repo.git
```

### "Protected branch update failed"

**This is expected!** It means branch protection is working correctly. Claude tried to push to `main` and GitHub rejected it.

**Solution:** Claude should push to a feature branch instead:
```bash
git checkout -b feature-name
git push origin feature-name
```

### "jq: command not found"

**Cause:** jq is not installed

**Solution:**
```bash
# macOS
brew install jq

# Linux
apt-get install jq
# or
yum install jq
```

### Container won't start

**Check Docker is running:**
```bash
docker ps
```

**Check image exists:**
```bash
docker images | grep claude-sandbox
```

**Rebuild if needed:**
```bash
./install.sh
```

---

## Advanced Usage

### Custom Deploy Key Location

Projects are stored in `~/.safeclaude/` by default. To change this, edit the `SAFECLAUDE_DIR` variable in the library files.

### Manual Deploy Key Management

```bash
# Keys are stored per-project
~/.safeclaude/keys/<project-name>/deploy_key
~/.safeclaude/keys/<project-name>/deploy_key.pub

# To manually add a key to GitHub:
gh repo deploy-key add ~/.safeclaude/keys/myrepo/deploy_key.pub \
  --allow-write \
  --title "safeclaude-myrepo" \
  --repo user/repo
```

### Custom Docker Image

To add more tools to the sandbox:
1. Edit `Dockerfile` to add packages
2. Rebuild: `./install.sh`

---

## Uninstallation

```bash
./uninstall.sh
```

This removes:
- Docker image
- Running/stopped containers
- `~/bin/safeclaude` command
- Library files

**Preserved (must remove manually if desired):**
- `~/.safeclaude/` directory (contains deploy keys and project registry)

To remove everything:
```bash
./uninstall.sh
rm -rf ~/.safeclaude
```

**Don't forget:** Remove deploy keys from GitHub repositories:
- **Repository → Settings → Deploy keys → Delete**

---

## FAQ

**Q: Can Claude access my other repositories?**
A: No. Each deploy key is added per-repository on GitHub. It only works for repos where you explicitly add it during setup.

**Q: What if I want Claude to push to main?**
A: Remove the branch protection rule on GitHub. But this defeats the purpose of the sandbox security model.

**Q: Can I use this for private repositories?**
A: Yes! The deploy key works for private repos.

**Q: Does this work with GitLab or Bitbucket?**
A: The concept is the same (deploy keys + branch protection), but you'll need to adapt the GitHub-specific CLI commands.

**Q: How do I create PRs from the sandbox?**
A: Either:
1. Claude pushes the branch and you create PR from GitHub UI
2. Claude can use `gh pr create` if network is enabled

**Q: Can I save the container state?**
A: By design, no (security feature). The workspace is ephemeral. All changes should be committed and pushed to GitHub. Use `--persist` to save Claude's config only.

**Q: What gets persisted with --persist?**
A: Only Claude's conversation history and config (in `.claude/`). The code workspace is ALWAYS ephemeral and deleted on exit.

**Q: Can I run multiple agents on different projects?**
A: Yes! Each project is isolated:
```bash
safeclaude run project1    # Terminal 1
safeclaude run project2    # Terminal 2
```

---

## Comparison with Other Tools

See [COMPARISON.md](./COMPARISON.md) for a detailed comparison with ClaudeBox, Sculptor, and Claude Code Dev Containers.

**SafeClaude's unique advantages:**
- ✅ Per-project deploy keys (best isolation)
- ✅ GitHub branch protection (server-side enforcement)
- ✅ Multi-project support with easy switching
- ✅ Parallel agents support
- ✅ Pure CLI (no GUI required)
- ✅ Automated GitHub setup

---

## License

MIT License - see [LICENSE](./LICENSE) for details.

---

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
