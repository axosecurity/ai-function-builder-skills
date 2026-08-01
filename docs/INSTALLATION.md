# Installation Guide

This guide explains how to install the AI skills from this repository into your AI coding agent so they are automatically discovered and used.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Method 1: Helper Script (Recommended)](#method-1-helper-script-recommended)
- [Method 2: Manual Install](#method-2-manual-install)
- [Install Locations by Tool](#install-locations-by-tool)
- [Verifying Installation](#verifying-installation)
- [Updating Skills](#updating-skills)
- [Uninstalling Skills](#uninstalling-skills)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

- **Git** to clone the repository
- An AI coding agent that supports the **SKILL format** (`SKILL.md` files with YAML frontmatter containing `name` and `description`). Supported tools include:
  - Claude Code
  - opencode
  - Cursor (and other SKILL-based agents)

---

## Method 1: Helper Script (Recommended)

The helper script detects which agent tool you use and copies skills into the correct directory automatically.

### Install everything

```bash
git clone https://github.com/axosecurity/ai-skills.git
cd ai-skills
bash scripts/install.sh --all
```

### Install only specific skills

```bash
bash scripts/install.sh --skills "clerk-org-rbac redis-token-bucket-rate-limiter secure-file-upload"
```

### Options

| Flag | Description | Default |
|---|---|---|
| `--all` | Install all skills | used when `--skills` is omitted |
| `--skills "a b c"` | Install only the listed skills | none |
| `--target <dir>` | Override the target skills directory | auto-detected |

---

## Method 2: Manual Install

Each skill is a folder containing a `SKILL.md` (and optionally a `references/` subfolder). To install, copy the whole folder into your agent's skills directory.

### Claude Code

```bash
mkdir -p ~/.claude/skills
cp -r skills/clerk-org-rbac ~/.claude/skills/
cp -r skills/redis-token-bucket-rate-limiter ~/.claude/skills/
cp -r skills/secure-file-upload ~/.claude/skills/
```

### opencode

```bash
mkdir -p ~/.config/opencode/skills
cp -r skills/clerk-org-rbac ~/.config/opencode/skills/
cp -r skills/redis-token-bucket-rate-limiter ~/.config/opencode/skills/
cp -r skills/secure-file-upload ~/.config/opencode/skills/
```

> Alternatively, `~/.opencode/skills/` also works for opencode.

### Cursor (or other agents)

Check your tool's documentation. Common locations include:

```bash
# Cursor
.cursor/skills/
# Generic
skills/
```

---

## Install Locations by Tool

| Tool | Install directory |
|---|---|
| Claude Code | `~/.claude/skills/<skill-name>/` |
| opencode | `~/.config/opencode/skills/<skill-name>/` |
| Cursor / other | `.cursor/skills/<skill-name>/` or `skills/<skill-name>/` |

**Important:** Copy the skill *folder itself* (e.g. `clerk-org-rbac/`) so that `SKILL.md` sits directly inside it, not nested one level deeper.

---

## Verifying Installation

### 1. Check the folder structure

```bash
ls ~/.claude/skills/clerk-org-rbac
```

You should see:

```text
SKILL.md
references/
```

### 2. Check the frontmatter

Open `SKILL.md` and confirm it starts with valid YAML frontmatter:

```yaml
---
name: clerk-org-rbac
description: ...
---
```

The `name` must match the folder name for the agent to discover it.

### 3. Test with your agent

Start a new session and describe a task that should trigger the skill, for example:

> "Add rate limiting to my /api/payments endpoint using a token bucket."

Your agent should load the `redis-token-bucket-rate-limiter` skill and begin its interview-first workflow.

For example, "Let users upload profile photos directly to S3 with presigned URLs" should load the `secure-file-upload` skill.
---

## Updating Skills

To update to the latest versions:

```bash
git -C ai-skills pull origin main
bash ai-skills/scripts/install.sh --all
```

The script overwrites existing copies with the latest content.

---

## Uninstalling Skills

Remove the skill folder from your agent's skills directory:

```bash
rm -rf ~/.claude/skills/clerk-org-rbac
```

---

## Troubleshooting

### "Agent doesn't recognize the skill"

- Confirm the folder name matches the `name:` in the `SKILL.md` frontmatter.
- Confirm you copied the whole folder (not just `SKILL.md`).
- Restart your agent session — skills are usually loaded at startup.

### "Skill loads but reference files are missing"

- Make sure the `references/` subfolder was copied along with `SKILL.md`.

### "I don't know which skills directory my agent uses"

- Run the helper script; it auto-detects. If it can't detect your tool, pass `--target <dir>` explicitly.
