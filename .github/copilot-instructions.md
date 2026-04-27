# GitHub Copilot Instructions - ns8-checkmk-container

## MANDATORY PRELIMINARY RULE

**BEFORE STARTING ANY WORK:**

- **ALWAYS read THIS file** (`.github/copilot-instructions.md`) at the beginning of EVERY conversation
- **ALWAYS consult** this file before starting any task
- This file contains **ALL rules, workflows and mandatory procedures**
- **DO NOT start work** without reading and understanding the instructions

**MANDATORY: At the start of EVERY conversation, use the memory tool to read these repository memory files:**
- `/memories/repo/git-push-policy.md` → Git commit format, versioning (v0.0.x), tag + release workflow (CRITICAL)

---

## Repository Information

**Repository:** `Coverup20/ns8-checkmk-container`  
**Type:** Owned repository (not a fork)  
**Purpose:** Podman container for CheckMK agent with FRPC tunnel on NethServer 8

---

## MANDATORY GENERAL RULES

### File language (script, code, comments, documentation)

- **ALL text in files must be in English**: comments, docstrings, log messages, descriptive variables, README, doc
- **New files**: write directly in English
- **Modified existing files**: Translate the touching parts into English
- **NEVER add Italian text** to code or documentation files

### Chat communications

- **Communications between us in chat always remain in Italian**

### No personal names or brand names in files

- **NEVER include names of people** (real names, usernames, GitHub handles, etc.) in any file
- **NEVER include internal brand names, customer names, or project codenames** in files
- Use generic references: "Nethesis style", "upstream standard", "reference codebase"

### No hardcoded environment data in files

- **NEVER hardcode** IP addresses, hostnames, domain names, ports, URLs, credentials, tokens, API keys

---

## Container Best Practices

- **Base images**: Use specific tags, never `:latest`
- **Multi-stage builds**: Separate build and runtime stages when applicable
- **Non-root user**: Always run containers as non-root unless strictly necessary
- **Security**: Drop capabilities, use read-only filesystems where possible
- **Health checks**: Always include health checks in production containers

---

## Workflow

**ALWAYS follow git-push-policy.md** for commit, tag, and release workflow.

**Every change requires:**
1. Test (local build + deployment on test host if applicable)
2. Commit with format: `type(scope): component v0.0.x - lowercase description`
3. Tag with same version: `git tag v0.0.x`
4. Push: `git push && git push origin --tags`
5. Release: `gh release create v0.0.x --title "v0.0.x" --notes "Uppercase description..."`

---

## MANDATORY POST-JOB RETROSPECTIVE — AUTOMATIC — NO EXCEPTIONS

> **"Ogni lavoro difficile risolto = oro da conservare. Se non lo scrivi, lo perdi."**

**This rule is AUTOMATIC and NON-NEGOTIABLE. Do NOT wait for the user to ask "memorizza".**

### TRIGGER — apply when the completed task involved ANY of:

- At least one command/approach that failed before finding the correct one
- An API error requiring investigation (unexpected HTTP codes, wrong params, wrong URL)
- Authentication or permission problems that required specific steps
- Quoting/encoding issues in SSH/bash requiring a workaround
- A non-obvious sequence of operations to achieve the goal
- A script that required multiple iterations before working

### MANDATORY ACTIONS (before saying "done"):

1. **List every difficulty encountered** in the completed task
2. **For each difficulty** → write a Q&A entry in `/memories/repo/qa-troubleshooting.md`:
   - Question: "How do I do X / What causes error Y?"
   - Answer: exact working solution with commands/code
   - Include: what was wrong, what the fix was, why it works
3. **For new scripts/tools created** → add entry in `/memories/repo/copilot-scripts-index.md`
4. **For host-specific quirks** → update relevant host section in memory files
5. **NEVER skip this step** — as mandatory as syntax validation before push

---

**Created:** 2026-04-20  
**Last updated:** 2026-04-23
