# AGENTS.md — Governing Instructions for AI Agents

This file is the **main prompt every agent working in this repository must obey**. It defines the project's conventions and the exact workflow for the most common task here: **adding a new AI skill to the collection**.

## Project Overview

This repo (`axosecurity/ai-skills`) is a curated, open-source collection of **production-ready AI skills** — reusable instruction packs that turn LLM coding agents (Claude Code, opencode, Cursor, etc.) into specialists for specific engineering tasks.

- Each skill lives in `skills/<skill-name>/` as a `SKILL.md` (with YAML frontmatter) plus optional `references/` deep-dive docs.
- Existing skills: `clerk-org-rbac`, `redis-token-bucket-rate-limiter`, `secure-file-upload`.
- The public surface of the repo is `README.md` (catalog) and `docs/INSTALLATION.md`. The installer (`scripts/install.sh`) auto-discovers skills from the `skills/` directory — it does **not** need editing when a skill is added.

## Non-Negotiable Rules

1. **`SKILL.md` frontmatter is required** — must contain at least `name` and `description`. The `name` **must match the folder name** exactly, or agents won't discover the skill.
2. **Never commit `.skill` files** — they are gitignored (`*.skill`). They are only an *input* format (zip archives) that gets extracted.
3. **Skills are security-first, reusable, and project-agnostic** — no hardcoded domain details in `SKILL.md`; put worked examples in `references/`.
4. **Keep the README catalog in sync** — every skill must be listed. Never add a skill without updating the docs that reference it.
5. **Do not commit secrets** — check env vars, keys, and tokens stay out of all files.
6. **Do not commit unless the user explicitly asks.** When committing, use a concise message matching the repo style (see `git log`).

## Workflow: Adding a New Skill

New skills usually arrive as a `.skill` **zip archive** at the repo root. Follow these steps in order:

### 1. Inspect the archive (don't trust filenames)

```bash
file <skill-name>.skill                 # confirm it's a Zip archive
unzip -l <skill-name>.skill             # list contents before extracting
```

If it's not a zip, inspect the raw file. Extract into a temp dir first to review contents before placing them in the repo:

```bash
mkdir -p /tmp/skill-extract && unzip -o <skill-name>.skill -d /tmp/skill-extract
```

### 2. Place the skill in the repo

```bash
unzip -o -q <skill-name>.skill -d skills/
# result: skills/<skill-name>/SKILL.md [+ skills/<skill-name>/references/*]
```

Then **delete the `.skill` archive** from the repo root (it's gitignored; the extracted folder is what gets committed).

### 3. Validate the skill

- [ ] `skills/<skill-name>/SKILL.md` exists with valid frontmatter: `name` and `description`.
- [ ] `name:` in frontmatter == folder name (`skills/<skill-name>/`).
- [ ] `description` explains **when to trigger** (scenarios, "use when the user asks…") and **what it implements**.
- [ ] `references/` files are linked from `SKILL.md` (paths relative to the skill folder).
- [ ] No `.skill` archive, `.DS_Store`, or temp files inside `skills/`.
- [ ] Read the `SKILL.md` thoroughly and summarize the skill's purpose so the README entry is accurate — don't guess from the folder name.

### 4. Update the README

In `README.md`, update **every** place skills are enumerated (see the [README conventions](#readme-conventions) below):

- [ ] **Table of Contents** — add the new skill link.
- [ ] **Skill Catalog** — add a numbered section matching the existing style: `### N. <Skill Name>`, with **Category · Stack**, description, **What you get** bullets, **Key files** links, **When to use**, and **Install** block.
- [ ] **Example prompts** (Quick Start) — add a `# Triggers <skill-name>` example.
- [ ] **Manual install** example — add a `cp -r skills/<skill-name> ~/.claude/skills/` line.
- [ ] **Helper script** line — include `<skill-name>` in the `--skills "…"` list.
- [ ] **Project structure** tree — add the skill folder and its files.
- [ ] **Keywords** line — add relevant keywords for discoverability.

### 5. Update the docs

In `docs/INSTALLATION.md`, update skill enumerations:

- [ ] `--skills "…"` install-only example.
- [ ] Claude Code and opencode manual `cp -r` examples.
- [ ] Optionally, a trigger example in the "Test with your agent" section.

### 6. Verify before finishing

- [ ] `git status` shows only intended changes (skill folder + README + docs).
- [ ] README links to `skills/<skill-name>/…` resolve to real files.
- [ ] The installer auto-detects the new skill (it lists every folder under `skills/`):
  ```bash
  find skills -mindepth 1 -maxdepth 1 -type d -exec basename {} \;
  ```
- [ ] If you fixed or changed anything beyond the addition (e.g. a bug in `scripts/install.sh`), flag it to the user rather than silently expanding scope.

### 7. Commit and push (only when asked)

```bash
git add skills/<skill-name> README.md docs/INSTALLATION.md
git status                                  # review staged files
git commit -m "Add <skill-name> skill: <one-line summary>"
git push origin main
```

Match the commit style in `git log` (imperative, summarizes what the skill does). Never include the `.skill` archive in the commit.

## README Conventions

- Catalog entries are numbered sequentially (`1.`, `2.`, …). Insert the new skill after existing ones and re-number if the order changes.
- `**Category:**` is a short label (e.g. `Auth & Authorization`, `Backend & API`).
- `**Stack:**` lists frameworks/libraries the skill targets.
- `**Key files:**` links relative paths from repo root, e.g. [`skills/<name>/SKILL.md`](skills/<name>/SKILL.md) · [`references/<file>.md`](skills/<name>/references/<file>.md).
- `**When to use:**` mirrors the skill's trigger description in plain language.
- Keep tone consistent: bullet-driven, no fluff, security-first.

## Verification Commands

- List all skills: `find skills -mindepth 1 -maxdepth 1 -type d -exec basename {} \;`
- Check a skill's frontmatter: `head -4 skills/<skill-name>/SKILL.md`
- Review what's tracked/ignored: `git status`, `git check-ignore -v <file>`
