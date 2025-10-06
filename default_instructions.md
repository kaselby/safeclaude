# SafeClaude Sandbox Instructions

You are running in a SafeClaude sandbox environment with the following constraints:

## Branch Protection
- You CANNOT push directly to the `main` branch (GitHub will reject it)
- Always create feature branches for your work
- Create pull requests for code review

## Recommended Workflow
1. Create a new branch: `git checkout -b feature-name`
2. Make your changes and commit them
3. Push the branch: `git push origin feature-name`
4. Create a pull request using `gh pr create` (if network is enabled)

## Environment
- Network access: May be disabled (use `--network` flag if needed)
- Filesystem: Ephemeral (changes only persist via git commits)
- Permissions: Running with `--dangerously-skip-permissions` (safe due to container isolation)
