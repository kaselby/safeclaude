# Comprehensive Comparison: Four Approaches to Sandboxing Claude Code

## Overview Table

| Feature | **SafeClaude** | **Sculptor (Imbue)** | **ClaudeBox (RchGrav)** | **Dev Containers** |
|---------|----------------|----------------------|-------------------------|-------------------|
| **Primary Goal** | Ephemeral sandbox with GitHub security | Parallel agents with UI management | Persistent multi-project CLI | Official VS Code integration |
| **Platform** | Standalone Docker CLI | Desktop app (Electron) | Standalone Docker CLI | VS Code extension |
| **Setup Complexity** | Medium (manual GitHub config) | Low (desktop app install) | Low (uses host credentials) | Medium (VS Code required) |
| **Git Authentication** | Deploy key (per-repo) | SSH keys (likely mounted) | SSH keys (read-only mount) | SSH agent (automatic) |
| **Credential Scope** | Limited (deploy key only) | Full (assumed host keys) | Full (host SSH keys) | Full (SSH agent) |
| **Persistence** | None (ephemeral) | Per-agent (containers persist) | Full (per-project state) | Full (named volumes) |
| **Parallel Agents** | ❌ | ✅ (core feature) | ❌ | ❌ |
| **UI/UX** | CLI only | Desktop GUI | CLI only | VS Code integration |
| **Network Isolation** | Optional (default: isolated) | Network enabled (for LLM) | Firewall + allowlists | Firewall (default-deny) |
| **GitHub Setup** | Required (deploy key + protection) | None | None | None |
| **Security Model** | Server-side enforcement | Container isolation + UI controls | Container isolation | Container + firewall |

---

## 1. **SafeClaude (This Project)** 🔐

**Philosophy:** Maximum security through least-privilege credentials and server-side enforcement

### Git Authentication
- **Method:** SSH deploy key (per-repository)
- **Setup:** Generate key → Add to GitHub → Configure branch protection
- **Scope:** Single repository only
- **Permissions:** Can push to branches, BLOCKED from protected branches by GitHub

### Security Model
```
Credentials:   Limited deploy key (generated, isolated)
Enforcement:   GitHub server-side (cannot be bypassed)
Principle:     Least privilege
Trust Model:   Zero trust (even with container access)
```

### Pros
- ✅ **Most secure** - deploy key has minimal permissions
- ✅ **Server-side enforcement** - GitHub blocks protected branches
- ✅ **Cannot be bypassed** - works even if Claude compromises container
- ✅ **Credential isolation** - not your personal SSH keys
- ✅ **Per-repo control** - each repo gets separate key
- ✅ **Ephemeral** - clean slate every session
- ✅ **Simple architecture** - no complex state management

### Cons
- ⚠️ **Manual setup** - requires GitHub configuration
- ⚠️ **Per-repo setup** - must configure each repository
- ⚠️ **No persistence** - state lost on exit
- ⚠️ **Branch protection required** - relies on GitHub setup
- ⚠️ **Network limitations** - must manually enable with `--network`

### Best For
- ✨ Untrusted/experimental code
- ✨ Maximum security requirements
- ✨ One-off sandboxed sessions
- ✨ Shared environments (team/CI)
- ✨ Compliance/audit scenarios

---

## 2. **Sculptor (Imbue)** 🎨

**Philosophy:** Parallel agent workflows with UI management and isolated sandboxes

### Overview
- **Type:** Desktop application (Electron-based)
- **Released:** October 2025 (research preview/beta)
- **Developer:** Imbue (AI agent research company)
- **Website:** https://imbue.com/sculptor/
- **GitHub:** https://github.com/imbue-ai/sculptor

### Git Authentication
- **Method:** SSH keys (mounted into containers)
- **Setup:** Uses your existing SSH configuration
- **Scope:** All repositories you have access to
- **Permissions:** Same as your host account

### Security Model
```
Credentials:   Host SSH keys (mounted/copied)
Enforcement:   Container isolation + UI oversight
Principle:     Isolated parallel agents
Trust Model:   Trusted repos with container boundaries
```

### Architecture
- Each agent runs in its own Docker container
- Desktop GUI for managing multiple agents simultaneously
- **"Pairing Mode"** - bidirectional sync between agent and local IDE
- Agents work on separate git branches
- Built-in merge/discard controls in UI

### Unique Features
- ✅ **Parallel agents** - run multiple Claude instances on different tasks
- ✅ **Visual management** - see all agents, their status, and outputs
- ✅ **Branch isolation** - each agent works on its own branch
- ✅ **Pairing mode** - test agent changes locally before committing
- ✅ **Inline steering** - use TODO/FIXME comments to guide agents
- ✅ **Context compaction** - manages long conversations
- ✅ **Auto-recovery** - agents retry on errors
- ✅ **Custom devcontainer support** - bring your own Dockerfile

### Pros
- ✅ **Best for parallel work** - multiple agents on different features simultaneously
- ✅ **Visual oversight** - see what all agents are doing at once
- ✅ **Branch-based workflow** - natural git workflow with agent branches
- ✅ **User-friendly** - desktop app with polished UI
- ✅ **Merge controls** - explicit approval before merging agent changes
- ✅ **Reduces cognitive load** - offload multiple tasks to parallel agents
- ✅ **IDE integration** - pairing mode syncs with your editor
- ✅ **Safety by design** - each agent isolated in container

### Cons
- ⚠️ **Full git access** - agents can push to any branch they can access
- ⚠️ **No branch protection** - relies on container isolation only
- ⚠️ **SSH keys exposed** - containers have access to host credentials
- ⚠️ **Network required** - agents need internet for LLM API calls
- ⚠️ **Desktop app only** - not a CLI tool (macOS + Linux only currently)
- ⚠️ **Beta/preview** - relatively new, still in development
- ⚠️ **Container overhead** - running many parallel agents uses resources
- ⚠️ **Trust required** - assumes you're working on trusted codebases

### Best For
- ✨ Working on multiple features/bugs in parallel
- ✨ Teams wanting to maximize AI agent productivity
- ✨ Complex projects where parallel work accelerates development
- ✨ Users who prefer GUI over CLI
- ✨ Scenarios requiring visual oversight of multiple agents
- ✨ Workflows with frequent context switching

### Security Considerations
**From their documentation:**
> "Recommends using IDE 'untrusted mode', carefully managing secret exposure, being cautious about network access, avoiding embedding secrets in code/prompts"

Similar to other solutions, Sculptor **does not implement branch protection** - it relies entirely on:
1. Container isolation
2. User oversight via UI
3. Explicit merge approval workflow
4. Best practices around secret management

---

## 3. **ClaudeBox (RchGrav)** 🛠️

**Philosophy:** Full-featured development environment with persistent state

### Git Authentication
- **Method:** SSH agent forwarding (mounts `~/.ssh` read-only)
- **Setup:** None (uses existing host SSH keys)
- **Scope:** All repositories you have access to
- **Permissions:** Same as your host account

### Security Model
```
Credentials:   Your SSH keys (read-only mount)
Enforcement:   Container isolation only
Principle:     Trust but isolate
Trust Model:   Trusts Claude within container boundaries
```

### Pros
- ✅ **Zero setup** - works with existing credentials
- ✅ **Multi-repo** - access all your repositories
- ✅ **Persistent state** - project configs, history, auth
- ✅ **Profile system** - pre-configured environments (Python, Rust, Go, etc.)
- ✅ **Rich features** - tmux, firewall allowlists, slot management
- ✅ **Sophisticated** - handles complex multi-project workflows
- ✅ **Flexible** - admin mode for persistent changes

### Cons
- ⚠️ **Full access** - Claude has same git permissions as you
- ⚠️ **No branch protection** - can push to main if you can
- ⚠️ **Exposes SSH keys** - in container (read-only, but accessible)
- ⚠️ **Complex** - many features = more to learn
- ⚠️ **Persistence risk** - state survives between sessions
- ⚠️ **Trust required** - relies entirely on container isolation

### Best For
- ✨ Trusted projects
- ✨ Long-term development
- ✨ Multi-repository workflows
- ✨ Power users who want persistence
- ✨ Teams needing consistent environments

---

## 4. **Claude Code Dev Containers** 🏢

**Philosophy:** Official VS Code integration with opinionated security

### Git Authentication
- **Method:** SSH agent forwarding (automatic via VS Code)
- **Setup:** VS Code + Remote Containers extension
- **Scope:** All repositories accessible to your SSH agent
- **Permissions:** Same as your host account

### Security Model
```
Credentials:   SSH agent forwarded by VS Code
Enforcement:   Network firewall + container isolation
Principle:     Defense in depth
Trust Model:   Trusted repos + network restrictions
```

### Pros
- ✅ **Official solution** - maintained by Anthropic
- ✅ **Automatic auth** - SSH agent forwarding just works
- ✅ **Network firewall** - default-deny with allowlists (GitHub, npm, Claude API)
- ✅ **VS Code integration** - seamless IDE experience
- ✅ **Persistent volumes** - command history, config preserved
- ✅ **Reference implementation** - best practices from Anthropic
- ✅ **Well-documented** - official docs and support

### Cons
- ⚠️ **VS Code required** - not standalone
- ⚠️ **Full git access** - can push to main
- ⚠️ **Warning in docs** - "do not prevent a malicious project from exfiltrating anything accessible"
- ⚠️ **Network complexity** - firewall rules to manage
- ⚠️ **Less flexible** - tied to VS Code workflow
- ⚠️ **Documentation caveat** - "only using devcontainers when developing with trusted repositories"

### Best For
- ✨ VS Code users
- ✨ Trusted repositories
- ✨ Official supported workflow
- ✨ Teams wanting standardized environments
- ✨ Network-restricted environments

---

## Security Comparison

### Attack Scenarios

| Scenario | SafeClaude | Sculptor | ClaudeBox | Dev Containers |
|----------|-----------|----------|-----------|----------------|
| **Claude tries to push to main** | ❌ Blocked by GitHub | ✅ Succeeds | ✅ Succeeds | ✅ Succeeds |
| **Malicious code reads SSH keys** | ✅ Safe (deploy key only) | ⚠️ Can access | ⚠️ Can read (read-only) | ⚠️ Can access via agent |
| **Code exfiltrates data** | ⚠️ If network enabled | ⚠️ Network required | ⚠️ Via allowlisted domains | ⚠️ Via allowlisted domains |
| **Container escapes** | ✅ Safe (limited key) | ⚠️ Has your credentials | ⚠️ Has your credentials | ⚠️ Has SSH agent access |
| **Persists malware** | ✅ Safe (ephemeral) | ⚠️ Possible (per-agent) | ⚠️ Possible (persistence) | ⚠️ Possible (volumes) |
| **Parallel agent conflicts** | N/A (single agent) | ✅ Isolated by design | N/A (single agent) | N/A (single agent) |

### Security Levels

**Most Secure → Least Secure:**
1. **SafeClaude** - Server-side enforcement + limited credentials + ephemeral
2. **Dev Containers** - Network firewall + agent forwarding + VS Code controls
3. **Sculptor** - Container isolation + UI oversight + branch workflow
4. **ClaudeBox** - Container isolation only + full SSH access

---

## Automation & Ease of Use

### Setup Time

| Step | SafeClaude | Sculptor | ClaudeBox | Dev Containers |
|------|-----------|----------|-----------|----------------|
| **Install Docker** | ✓ | ✓ | ✓ | ✓ |
| **Install VS Code** | ✗ | ✗ | ✗ | ✓ Required |
| **Install app/CLI** | CLI script | Desktop app | CLI script | 0 min (clone repo) |
| **Run installer** | 1 min | 1 min | 1 min | 0 min |
| **GitHub setup** | 5 min (manual) | 0 min | 0 min | 0 min |
| **Total first-time** | ~6 min | ~2 min | ~1 min | ~2 min |
| **Per-repo setup** | 2 min (deploy key) | 0 min | 0 min | 0 min |

### Automation Opportunities for Your Project

Based on ClaudeBox's approach, you could add:

1. **GitHub API automation:**
   ```bash
   # Auto-add deploy key
   gh api repos/$OWNER/$REPO/keys -f title="claudebox" \
     -f key="$(cat ~/.ssh/sandbox_deploy_key.pub)" -F read_only=false

   # Auto-enable branch protection
   gh api repos/$OWNER/$REPO/branches/main/protection -X PUT \
     -f required_pull_request_reviews='{"required_approving_review_count":1}'
   ```

2. **Self-extracting installer** (like `claudebox.run`)

3. **Interactive repo selector** - scan GitHub for your repos, choose one

4. **Profile system** - pre-configured setups for different languages

---

## Feature Comparison

| Feature | SafeClaude | Sculptor | ClaudeBox | Dev Containers |
|---------|-----------|----------|-----------|----------------|
| **Standalone** | ✅ CLI | ✅ Desktop app | ✅ CLI | ❌ (VS Code) |
| **Parallel agents** | ❌ | ✅ | ❌ | ❌ |
| **Multi-repo support** | ❌ (one at a time) | ✅ | ✅ | ✅ |
| **Persistent state** | ❌ | ✅ (per-agent) | ✅ | ✅ (volumes) |
| **Network isolation** | ✅ (optional) | ❌ (required) | ⚠️ (firewall) | ⚠️ (firewall) |
| **Branch protection** | ✅ (GitHub) | ❌ | ❌ | ❌ |
| **SSH key isolation** | ✅ (deploy key) | ❌ (host keys) | ❌ (host keys) | ❌ (agent) |
| **Zero GitHub setup** | ❌ | ✅ | ✅ | ✅ |
| **Ephemeral sessions** | ✅ | ⚠️ (configurable) | ❌ | ❌ |
| **Visual UI** | ❌ | ✅ | ❌ | ⚠️ (VS Code) |
| **Language profiles** | ❌ | ✅ (custom) | ✅ (15+) | ⚠️ (manual) |
| **Branch workflow** | Manual | ✅ (built-in) | Manual | Manual |
| **Merge controls** | Manual | ✅ (UI) | Manual | Manual |
| **Context management** | ❌ | ✅ (compaction) | ❌ | ❌ |
| **Official support** | ❌ | ⚠️ (Imbue) | ❌ | ✅ (Anthropic) |

---

## Recommendations

### Choose **SafeClaude** if:
- 🎯 Security is paramount
- 🎯 Working with untrusted/experimental code
- 🎯 Need compliance/audit trail
- 🎯 Want true isolation with server-side guarantees
- 🎯 Prefer ephemeral, clean-slate sessions
- 🎯 Need per-repo access control
- 🎯 Running with `--dangerously-skip-permissions` in production

### Choose **Sculptor** if:
- 🎯 Need to work on multiple features/bugs simultaneously
- 🎯 Want visual oversight of parallel agents
- 🎯 Prefer GUI over command-line tools
- 🎯 Need structured branch-based workflow with UI controls
- 🎯 Working on trusted codebases
- 🎯 Want to maximize AI agent productivity through parallelism
- 🎯 Need context management for long conversations

### Choose **ClaudeBox** if:
- 🎯 Working on trusted projects
- 🎯 Need persistent development environments
- 🎯 Want multi-project workflows
- 🎯 Require language-specific profiles (Python, Rust, Go, etc.)
- 🎯 Prefer sophisticated state management
- 🎯 Comfortable with full git access in container
- 🎯 Power user who wants CLI control

### Choose **Dev Containers** if:
- 🎯 Already using VS Code
- 🎯 Want official Anthropic support
- 🎯 Need standardized team environments
- 🎯 Prefer integrated IDE experience
- 🎯 Working with trusted repositories
- 🎯 Want network firewall with allowlists

---

## Hybrid Approaches

You could combine the best features from multiple solutions:

### **SafeClaude + Sculptor Features**
```
✅ Deploy key security (SafeClaude) + Parallel agents UI (Sculptor)
✅ Server-side enforcement + Visual management
✅ Zero trust model + Productivity through parallelism
```

### **SafeClaude + ClaudeBox Automation**
```
✅ Deploy key security + Profile system
✅ GitHub API automation + Language-specific environments
✅ Branch protection + Persistent state (optional)
```

### **Ultimate Secure Workflow**
```bash
1. Deploy key (SafeClaude) - server-side security
2. GitHub API automation (ClaudeBox style) - ease of setup
3. Network firewall (Dev Containers) - defense in depth
4. Profile system (ClaudeBox) - language flexibility
5. Parallel agents (Sculptor) - productivity boost
6. UI oversight (Sculptor) - visual management
```

---

## The Branch Protection Gap

**Key Finding:** SafeClaude is the **only solution** that implements true branch protection through deploy keys and GitHub server-side enforcement.

All other solutions rely on:
- Container isolation only
- User discipline/oversight
- Post-hoc merge approval
- Trust in the codebase

While these are valid approaches for trusted environments, **none provide the guarantee that an AI agent cannot push to protected branches**, even with full container access.

---

## References

- **SafeClaude (This Project):** https://github.com/kaselby/safeclaude
- **Sculptor (Imbue):** https://github.com/imbue-ai/sculptor
  - Website: https://imbue.com/sculptor/
- **ClaudeBox (RchGrav):** https://github.com/RchGrav/claudebox
- **Claude Code Dev Containers:** https://docs.claude.com/en/docs/claude-code/devcontainer
  - Reference: https://github.com/anthropics/claude-code/tree/main/.devcontainer
