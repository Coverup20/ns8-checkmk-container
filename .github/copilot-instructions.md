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

**Created:** 2026-04-20  
**Last updated:** 2026-04-20
