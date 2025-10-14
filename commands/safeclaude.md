Find the conversation history file for THIS specific Claude Code session and prepare it for transfer to a SafeClaude container with metadata for easy identification.

**Usage:**
- `/safeclaude <project-name>` - Auto-generate summary from conversation context
- `/safeclaude <project-name> <summary>` - Use user-provided summary

**Steps:**
1. Identify the current conversation file by verifying assistant messages against your memory:
   - Get current working directory and convert to Claude project path format (/ → -)
   - Check files for one whose contents match your memory of this conversation
   - An easy way to check is to use grep to extract assistant messages - for example:
     ```bash
     grep '"type":"assistant"' <file> | tail -5 | jq -r '.message.content[] | select(.type=="text") | .text' | head -c 400
     ```
   - Check the 3-5 most recent .jsonl files (sorted by mtime)
   - Once you find a file where the assistant messages clearly match your conversation memory, that's the file - proceed immediately
   - Only ask user if you can't find a match in the top 3-4 files (very rare)
2. Generate or use provided summary:
   - If summary provided: use it
   - If not: analyze conversation and create concise 1-2 sentence summary
3. Extract the last 2-3 user/assistant message snippets (first 80 chars each) for preview
4. Generate metadata JSON with:
   - format_version: "1.0"
   - project name
   - conversation ID
   - timestamp (epoch seconds)
   - summary (user-provided or auto-generated)
   - last message snippets for preview
   - ISO timestamp
5. Copy conversation file to: `~/.safeclaude/transfer/<project>-<timestamp>.jsonl`
6. Save metadata to: `~/.safeclaude/transfer/<project>-<timestamp>.json`
7. Set secure permissions: `chmod 600` on both files
8. Display the summary and simple instructions

**Arguments:**
- PROJECT_NAME: {PROJECT_NAME}
- SUMMARY: {SUMMARY} (optional - you'll generate one if not provided)

**Technical details:**
- Use $PWD to determine project directory path
- Convert path format: /Users/name/path → -Users-name-path
- Search ~/.claude/projects/<converted-path>/ for .jsonl files
- Sort by modification time (mtime) - most recent first
- Read last 5-10 lines of top candidates with `tail` and parse with jq
- Verify messages match this conversation's context
- Use high-precision timestamp (date +%s%N on Linux, python time on macOS) for unique filenames
- Extract conversation ID from filename (UUID before .jsonl extension)

**After creating transfer files, tell the user:**
```
Conversation prepared for transfer!

To continue in SafeClaude:
  safeclaude resume <project-name>

To exit: Press Ctrl+D
```
