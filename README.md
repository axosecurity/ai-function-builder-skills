# AI Skills for Developers

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![GitHub stars](https://img.shields.io/github/stars/axosecurity/ai-function-builder-skills?style=social)
![Made with Markdown](https://img.shields.io/badge/built%20with-Markdown-orange.svg)

> A curated, open-source collection of **production-ready AI skills** for LLM agents (Claude Code, opencode, Cursor, and other agent-based development tools). Each skill is a reusable, step-by-step instruction pack that turns your AI coding assistant into a specialist for a specific engineering task — from multi-tenant RBAC on Clerk to race-condition-free Redis rate limiting to zero-bandwidth, presigned-URL file uploads.

## Table of Contents

- [What Are AI Skills?](#what-are-ai-skills)
- [Why Use These Skills?](#why-use-these-skills)
- [Skill Catalog](#skill-catalog)
  - [Clerk Organization RBAC](#1-clerk-organization-rbac)
  - [Redis Token Bucket Rate Limiter](#2-redis-token-bucket-rate-limiter)
  - [Secure File Upload](#3-secure-file-upload)
- [Quick Start](#quick-start)
- [Installation Guide](#installation-guide)
- [How to Use a Skill](#how-to-use-a-skill)
- [Project Structure](#project-structure)
- [Contributing](#contributing)
- [License](#license)

---

## What Are AI Skills?

AI Skills are structured instruction files (typically a `SKILL.md` with optional reference docs) that you drop into your AI coding agent's skill directory. When you ask your assistant to do something, it matches the task against the skill's description and loads the full instructions — giving it expert-level guidance, battle-tested architecture decisions, and copy-paste-ready code templates.

**In short:** skills are how you make your AI assistant *consistently good* at hard tasks, instead of winging it from scratch every time.

## Why Use These Skills?

- **Battle-tested:** Each skill encodes patterns that have shipped to real production products (e.g. DocentBase, a multi-tenant coaching-center SaaS).
- **Security-first:** Built-in rules prevent common foot-guns — frontend-only auth checks, spoofable identity headers, and non-atomic rate-limit scripts.
- **Reusable & project-agnostic:** Swap in your domain's roles, modules, and rates; the architecture stays intact.
- **Interview-first workflow:** Skills ask the right questions before writing code, so you get a solution that fits your actual constraints.
- **Zero lock-in:** Works across agent tools that support the SKILL format (Claude Code, opencode, Cursor, etc.).

---

## Skill Catalog

### 1. Clerk Organization RBAC

**Category:** Auth & Authorization · **Stack:** Next.js + Clerk Organizations

A reusable authorization architecture for multi-tenant SaaS built on **Clerk Organizations**. Implements role-based access control (RBAC) entirely inside Clerk — custom roles, custom permissions, and **JWT-only authorization** (no auth database, no per-request Clerk API calls).

**What you get:**

- 8-role / 44-permission reference matrix from a real production system (DocentBase)
- The dual gating pattern: **`Can`** (role gate, hides UI) vs **`PlanGate`** (billing gate, upsells)
- Backend-first security model — the frontend is cosmetic, the backend is the only real gate
- Rate-limit-safe caching strategy for Organization metadata (~2 min TTL, shared per tab)
- Copy-paste templates: `useCan()`, `<Can>`, `<PlanGate>`, `useOrgMetadata()`, `requirePermission()`, `middleware.ts`
- Explicit Owner-protection guard for business rules Clerk's flat model can't express

**Key files:** [`skills/clerk-org-rbac/SKILL.md`](skills/clerk-org-rbac/SKILL.md) · [`references/code-templates.md`](skills/clerk-org-rbac/references/code-templates.md) · [`references/docentbase-example.md`](skills/clerk-org-rbac/references/docentbase-example.md)

**When to use:** Building or scaffolding a multi-tenant SaaS, implementing roles/permissions, "who can do what" questions, gating features by subscription plan vs. user role, or auditing an existing Clerk auth system for security gaps.

**Install:**

```bash
mkdir -p ~/.claude/skills/clerk-org-rbac
cp -r skills/clerk-org-rbac/* ~/.claude/skills/clerk-org-rbac/
```

---

### 2. Redis Token Bucket Rate Limiter

**Category:** Backend & API · **Stack:** Node.js / TypeScript + Redis (optimized for Upstash)

A production-grade, **race-condition-free token bucket rate limiter** backed by Redis using a single atomic Lua script. Add rate limiting, throttling, or request-quota enforcement to any API, endpoint, or backend service — with standardized `429` responses and `X-RateLimit-*` headers.

**What you get:**

- One exact Lua script that does refill, check, and deduct atomically (no race conditions across concurrent requests)
- Distributed and Redis-client-agnostic — works with Upstash, ioredis, node-redis, etc.
- **Fail Open / Fail Closed** architecture for Redis outages (ask-first for sensitive endpoints)
- Security rules: never trust spoofable client headers, JWT-based identity preferred, IP fallback warnings
- Standardized `X-RateLimit-Limit` / `X-RateLimit-Remaining` headers and `429 Too Many Requests` handling
- Self-check checklist before code is presented

**Key files:** [`skills/redis-token-bucket-rate-limiter/SKILL.md`](skills/redis-token-bucket-rate-limiter/SKILL.md)

**When to use:** Adding rate limiting / throttling / quota enforcement to an API or backend, token bucket mention, "429 Too Many Requests", abuse prevention, brute-force protection, or reviewing auth/payment/public endpoints that lack rate limiting.

**Install:**

```bash
mkdir -p ~/.claude/skills/redis-token-bucket-rate-limiter
cp -r skills/redis-token-bucket-rate-limiter/* ~/.claude/skills/redis-token-bucket-rate-limiter/
```

---

### 3. Secure File Upload

**Category:** Backend & API · **Stack:** Framework-agnostic (Next.js, Django, Rails, Go, Laravel, Express, etc.) + S3-compatible storage (S3, Cloudflare R2, Supabase Storage, Firebase, Azure Blob, GCS)

A battle-tested architecture for letting users upload files (avatars, images, documents) **directly to cloud object storage** via presigned URLs — zero server bandwidth, never trusting the client. Client-side compression and EXIF stripping, cache-busting random object keys, and a **5-layer security model**.

**What you get:**

- The **4-phase flow**: client prep → `/upload/request` (presigned PUT URL) → direct upload → `/upload/confirm` (re-verify, then atomic swap)
- **5-layer security model**: server-side validation, presigned-URL Content-Type/Length locking, HeadObject verification, magic-byte inspection via Range request, and upload-intent tracking with garbage collection
- Cache-busting object keys that stop CDNs from serving stale avatars after a re-upload
- Atomic swap that never leaves a user with a broken/missing file (old file deleted only after the new one verifies)
- Copy-paste SDK samples (AWS SDK v3), magic-byte signature table, DB schema (`users` / `upload_intents` / `audit_logs`), and step-by-step R2/S3 console setup
- A standalone reference prompt to hand to any AI agent that doesn't have this skill installed

**Key files:** [`skills/secure-file-upload/SKILL.md`](skills/secure-file-upload/SKILL.md) · [`references/architecture.md`](skills/secure-file-upload/references/architecture.md) · [`references/security-model.md`](skills/secure-file-upload/references/security-model.md) · [`references/database-schema.md`](skills/secure-file-upload/references/database-schema.md) · [`references/configuration.md`](skills/secure-file-upload/references/configuration.md) · [`references/reference-prompt.md`](skills/secure-file-upload/references/reference-prompt.md)

**When to use:** Implementing or debugging file/image/avatar/document upload, "upload to S3/R2/Supabase/Firebase/Azure Blob/GCS", presigned URL uploads, "let users upload a photo", "add a file uploader", or "profile picture won't upload right" — even when the phrase "presigned URL" is never said.

**Install:**

```bash
mkdir -p ~/.claude/skills/secure-file-upload
cp -r skills/secure-file-upload/* ~/.claude/skills/secure-file-upload/
```

---

## Quick Start

1. **Clone this repo:**

```bash
git clone https://github.com/axosecurity/ai-function-builder-skills.git
cd ai-skills
```

2. **Install one or more skills** (see [Installation Guide](#installation-guide) for per-tool paths).
3. **Ask your AI assistant** to do the task — it will auto-detect and load the right skill.
4. **Answer its questions** — the skill follows an interview-first workflow to fit your exact constraints.

Example prompts that trigger the skills:

```text
# Triggers clerk-org-rbac
"Set up multi-tenant RBAC for my Next.js SaaS using Clerk Organizations"

# Triggers redis-token-bucket-rate-limiter
"Add rate limiting to my /api/payments endpoint with a token bucket"

# Triggers secure-file-upload
"Let users upload profile photos directly to S3 with presigned URLs"
```

---

## Installation Guide

### Where Skills Live (by tool)

| Tool | Install location |
|---|---|
| **Claude Code** | `~/.claude/skills/<skill-name>/` |
| **opencode** | `~/.config/opencode/skills/<skill-name>/` or `~/.opencode/skills/<skill-name>/` |
| **Cursor / other SKILL-based agents** | check your tool's docs; commonly a `skills/` or `.cursor/skills/` directory |

> Each skill is just a folder named after the skill containing a `SKILL.md` (and optional `references/`). Copy the whole folder.

### Manual Install (any tool)

```bash
# Example for Claude Code — repeat for each skill you want
mkdir -p ~/.claude/skills
cp -r skills/clerk-org-rbac ~/.claude/skills/
cp -r skills/redis-token-bucket-rate-limiter ~/.claude/skills/
cp -r skills/secure-file-upload ~/.claude/skills/
```

### Install with the helper script

We include a small installer that detects your agent tool and copies the skills into the right place:

```bash
bash scripts/install.sh
```

Pass `--skills "clerk-org-rbac redis-token-bucket-rate-limiter secure-file-upload"` to install only specific skills, or `--all` (default) for everything.

### Verify Installation

Confirm the folder structure exists and contains a `SKILL.md`:

```bash
ls ~/.claude/skills/clerk-org-rbac
# SKILL.md  references/
```

Then start a new session with your agent and use one of the example prompts above. The agent should acknowledge loading the skill.

---

## How to Use a Skill

1. **Invoke naturally:** Describe the task in plain language. The skill's `description` field is matched against your request automatically.
2. **Follow the interview:** The skill may ask clarifying questions (roles & permissions, rate limits, fail-open vs fail-closed). Answering them yields a much better result.
3. **Review the checklist:** Skills ship with built-in self-checks that the agent runs before presenting code.

---

## Project Structure

```text
ai-skills/
├── README.md                          # This file
├── LICENSE                            # MIT
├── AGENTS.md                          # Governing instructions for AI agents
├── scripts/
│   └── install.sh                     # Cross-tool installer
├── docs/
│   └── INSTALLATION.md                # Detailed per-tool install docs
├── web/
│   ├── index.html                     # Marketing landing page (SEO + JSON-LD)
│   ├── assets/
│   │   ├── styles.css                 # Landing page styles
│   │   └── main.js                    # Nav, tabs, scroll-reveal
│   ├── CNAME                          # Custom domain: ai-function-builder-skills.axosolaman.online
│   ├── robots.txt
│   ├── sitemap.xml
│   └── 404.html
└── skills/
    ├── clerk-org-rbac/
    │   ├── SKILL.md                   # Skill instructions + workflow
    │   └── references/
    │       ├── code-templates.md      # Copy-paste code templates
    │       └── docentbase-example.md  # Full worked production example
    └── redis-token-bucket-rate-limiter/
        └── SKILL.md                   # Skill instructions + workflow
    └── secure-file-upload/
        ├── SKILL.md                   # Skill instructions + workflow
        └── references/
            ├── architecture.md        # Sequence diagram + trade-offs
            ├── security-model.md      # 5-layer security model + SDK samples
            ├── database-schema.md     # upload_intents state machine + audit logs
            ├── configuration.md       # R2 / S3 console setup + CORS
            └── reference-prompt.md    # Standalone prompt for other agents
```

---

## Contributing

Contributions are welcome! If you have a battle-tested skill to share:

1. Fork the repo.
2. Add your skill as a folder under `skills/<skill-name>/` with a `SKILL.md` (frontmatter `name` + `description` required) and optional `references/`.
3. Add it to the catalog in this README.
4. Open a pull request.

Please keep skills security-first, reusable, and project-agnostic.

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details. You're free to use, modify, and redistribute these skills in personal and commercial projects.

---

*Keywords: AI skills, agent skills, Claude Code skills, opencode skills, LLM agent instructions, Clerk RBAC, multi-tenant authorization, role-based access control, Next.js SaaS, Redis rate limiter, token bucket, Upstash Redis, API rate limiting, 429 Too Many Requests, secure file upload, presigned URL, S3, Cloudflare R2, avatar upload, magic bytes, EXIF stripping, zero-bandwidth upload, developer tooling, open source*
