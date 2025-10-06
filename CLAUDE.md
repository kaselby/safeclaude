# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

SafeClaude is a secure sandbox system for running Claude Code in isolated Docker containers with GitHub-enforced security restrictions. It uses per-project SSH deploy keys and Docker containerization to provide a safe environment for autonomous AI coding.

## Architecture

### Core Components

1. **Main Script (`safeclaude`)**: Command-line interface that orchestrates all operations
2. **Library Modules (`lib/`)**: Modular bash functions for specific domains:
   - `registry.sh`: Project database management (stores projects in `~/.safeclaude/projects.json`)
   - `keys.sh`: SSH deploy key generation and management
   - `docker.sh`: Docker command construction with security constraints
   - `container.sh`: Container lifecycle management (start, stop, attach, logs)

3. **Docker Image**: Node.js 20 slim base with Claude Code CLI, git, GitHub CLI, and SSH client
4. **User Data Directory (`~/.safeclaude/`)**: Persistent storage for keys, projects, and config

### Security Model

- **Per-project deploy keys**: Each project gets an isolated ed25519 SSH key stored in `~/.safeclaude/keys/<project>/`
- **GitHub branch protection**: Server-side enforcement prevents pushing to `main` even with `--dangerously-skip-permissions`
- **Container isolation**: Docker provides filesystem isolation; network disabled by default
- **Ephemeral workspaces**: Code directories deleted on container exit (even with `--persist`)
- **Read-only key mounting**: Deploy keys mounted with `:ro` flag in containers

### Data Flow

```
Host → Docker Container → GitHub
     ↓                    ↑
deploy key          branch protection
(per-project)       (server-side)
```

## Development Commands

### Build and Install
```bash
./install.sh              # Build Docker image and install CLI
```

This script:
- Builds Docker image with your git config
- Creates `~/.safeclaude/` directory structure
- Installs `safeclaude` command to `~/bin/`
- Copies library files to `~/bin/lib/`

### Uninstall
```bash
./uninstall.sh            # Remove Docker image, containers, and binaries
```

Note: This preserves `~/.safeclaude/` directory. Delete manually if needed.

### Testing

There are no automated tests in this repository. Testing is manual:

```bash
# Test project setup
safeclaude setup test-project git@github.com:user/test-repo.git

# Test running
safeclaude run test-project

# Test background agents
safeclaude start test-project agent-1
safeclaude logs test-project-agent-1 -f
safeclaude stop test-project-agent-1

# Cleanup
safeclaude remove test-project
```

## Code Structure

### Container Name Generation (`lib/docker.sh:80-95`)

- **Foreground containers**: Auto-generated unique names using `date +%s` and `$$` to allow parallel sessions
- **Background containers**: Require stable names via `--name` flag for attachment
- **Name prefix**: Always prefixed with `safeclaude-` to identify project containers

### Security Features

#### Input Validation (`safeclaude:147-201`)
- Project names: alphanumeric, hyphens, underscores only; max 64 chars
- Agent names: same validation as project names (lines 425-436)
- Repository URLs: validated against GitHub URL patterns with regex
- Owner/repo extraction uses bash regex with format validation

#### Secure File Operations (`lib/registry.sh:47-79`)
All JSON operations use:
- Temporary files with unique names (`mktemp`)
- Proper permissions (`chmod 600`)
- Atomic moves (`mv -f`)
- Cleanup on error (`trap`)

#### Command Injection Prevention (`lib/docker.sh:136-137`)
Repository URLs passed as environment variables (`REPO_URL`), not command arguments, to prevent shell injection in docker run.

### API Key Management (`lib/registry.sh:194-258`)

Two storage options:
1. **Environment variable** (more secure): `export ANTHROPIC_API_KEY='sk-ant-...'`
2. **Config file** (convenient): `~/.safeclaude/config.json`

Priority: env var checked first, then config file (`safeclaude:348-366`).

### Host Configuration Copying (`lib/docker.sh:118-197`)

The system copies host `~/.claude/` config into containers with fine-grained control:

**What gets copied**:
- `CLAUDE.md` (if `--use-host-prompt=true`): Appended with sandbox-specific instructions from `~/.safeclaude/sandbox_instructions.md`
- `agents/` directory (if `--use-host-agents=true`): Custom agents like research-librarian
- `commands/` directory (if `--use-host-commands=true`): Slash commands

**What doesn't get copied**:
- `config.json` (incompatible with container environment)
- `mcp_config.json` (MCP servers can't be accessed from isolated container)
- Conversation history (unless `--persist` is used)

**Control flags**:
- Set defaults in config: `safeclaude config set use_host_commands false`
- Override per-run: `safeclaude run project --use-host-commands=false`
- Disable all: `safeclaude run project --no-host-config`

## Common Workflows

### Adding New Commands

1. Add command function in `safeclaude` (e.g., `cmd_newcommand()`)
2. Add case in `main()` dispatcher (`safeclaude:731-776`)
3. Update `usage()` function with help text (`safeclaude:33-103`)
4. If adding Docker options, update `build_docker_command()` in `lib/docker.sh`

### Modifying Docker Image

Edit `Dockerfile` to add tools:
```dockerfile
RUN apt-get update && apt-get install -y \
    newtool \
    && rm -rf /var/lib/apt/lists/*
```

Then rebuild:
```bash
./install.sh
```

### Adding Project Metadata

Projects stored as JSON objects in `~/.safeclaude/projects.json`:
```json
{
  "project-name": {
    "url": "git@github.com:user/repo.git",
    "owner_repo": "user/repo",
    "key_path": "/path/to/deploy_key",
    "default_branch": "main",
    "created_at": "2024-10-06T12:00:00Z",
    "last_used": "2024-10-06T12:00:00Z"
  }
}
```

To add fields, modify `add_project()` in `lib/registry.sh:37-79`.

### Adding Config Options

1. Add default value in `init_safeclaude_dir()` (`lib/registry.sh:20-35`)
2. Parse option in `build_docker_command()` (`lib/docker.sh:29-78`)
3. Update `cmd_config()` help text (`safeclaude:659-665`)
4. Update README.md with new option

## Important Constraints

### Docker Image Naming
Uses `safeclaude-$(whoami)/claude-sandbox` to prevent namespace collisions on shared systems (`lib/docker.sh:7`).

### Volume Naming
Persistent volumes use project name prefix: `safeclaude-${project_name}-config` and `safeclaude-${project_name}-history` (`lib/docker.sh:146-147`).

### Container Naming Convention
- Prefix: `safeclaude-`
- Foreground format: `safeclaude-<project>-<timestamp>-<pid>` (auto-generated)
- Background format: `safeclaude-<project>-<agent>` (user-specified)
- Functions auto-add prefix if missing (see `lib/container.sh:21-23`, `lib/container.sh:47-50`)

### SSH Key Format
Always uses ed25519 keys (`ssh-keygen -t ed25519`) for better security and performance (`lib/keys.sh:20`).

## Debugging

### Check Docker image exists
```bash
docker images | grep "safeclaude-$(whoami)"
```

### Inspect running containers
```bash
docker ps -a --filter "name=safeclaude-"
```

### View container logs
```bash
safeclaude logs <container-name> -f
```

### Check project registry
```bash
cat ~/.safeclaude/projects.json | jq
```

### Verify deploy key permissions
```bash
ls -la ~/.safeclaude/keys/<project>/
# Should show: -rw------- (600) for private key
```

### Debug startup script
The startup script is embedded in `lib/docker.sh:160-224` (foreground) and `lib/docker.sh:228-251` (background). To debug:

1. Check container logs: `docker logs <container-name>`
2. Look for "Failed to clone repository" errors
3. Verify deploy key exists and has correct permissions
4. Test network connectivity with `--network` flag

## Security Considerations

When modifying this codebase:

1. **Never bypass GitHub authentication**: Security depends on GitHub's server-side branch protection
2. **Validate all user input**: Project names, agent names, repo URLs (see input validation patterns in `safeclaude:147-201`)
3. **Use temp files atomically**: For JSON writes to prevent corruption (pattern in `lib/registry.sh:51-78`)
4. **Mount keys read-only**: Always use `:ro` flag when mounting deploy keys (`lib/docker.sh:116`)
5. **Sanitize shell inputs**: Use environment variables instead of direct string interpolation in commands (`lib/docker.sh:136-142`)
6. **Preserve file permissions**: Ensure keys are 600, config is 600, public keys are 644

## Dependencies

- **Docker**: Container runtime
- **jq**: JSON processing (required)
- **gh** (GitHub CLI): For automated deploy key and branch protection setup
- **git**: Repository operations
- **ssh-keygen**: Deploy key generation
- **bash 4+**: For associative arrays and advanced features
