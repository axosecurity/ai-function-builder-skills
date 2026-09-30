# Onlook Local Development & Autonomous Management Skill

> **Turn any AI coding agent into an autonomous operator for installing, provisioning, running, debugging, and managing Onlook on local machines.**

---

## 📖 Overview

[Onlook](https://github.com/onlook-dev/onlook) is the open-source visual editor for React and Tailwind CSS. Running Onlook locally requires coordinating a monorepo across multiple services: a Next.js 16 web client with Turbopack, a standalone CDN preload script server, a full Supabase container cluster (PostgreSQL, Kong, Auth, Studio, Mailpit, S3), and a Drizzle ORM database layer.

This skill packages the complete operational blueprint, rootless Docker workarounds, command cheatsheet, and automated workflows into a reusable instruction pack for AI agents and human developers.

---

## 🎯 What Problem Does This Skill Solve?

When developers or AI agents attempt to set up Onlook locally, they commonly run into several complex roadblocks:
1. **Docker Runtime & Socket Mount Pitfalls**: On macOS systems without Docker Desktop, running rootless container engines like Colima fails because Supabase CLI attempts to mount host Unix domain sockets across `virtiofs`, throwing `operation not supported`.
2. **Interactive CLI Stalls**: `supabase start` prompts interactively regarding existing storage bucket properties, which causes autonomous agent tasks to hang indefinitely.
3. **Multi-Environment Desynchronization**: Missing keys between `apps/web/client/.env` and `packages/db/.env` cause silent API and database connectivity failures.
4. **Database Schema Drift**: Developers forget to run `bun db:push` and `bun db:seed`, leading to runtime GraphQL and database crashes.

**With this skill loaded**, your AI assistant or agent:
- Detects the container engine and autonomously applies the Colima tmpfs socket fix.
- Starts and provisions the Supabase cluster with zero manual intervention.
- Automatically queries and populates all `.env` files with generated keys.
- Executes Drizzle schema migrations and seeds default test users.
- Boots the development server and validates all health endpoints.

---

## ⚡ Quick Command Reference

| Command | Where to Run | What It Does | When to Use It |
| :--- | :--- | :--- | :--- |
| `colima start --cpu 4 --memory 6` | Anywhere | Starts the lightweight Linux VM with Docker daemon. | First step before running any backend or database command. |
| `colima stop` | Anywhere | Gracefully shuts down the Colima VM and frees all RAM/CPU. | When done developing to save machine battery/memory. |
| `colima status` | Anywhere | Checks if the Docker engine VM is running or stopped. | Troubleshooting container connection errors. |
| `bun install` | Repository root | Installs all monorepo dependencies across apps and packages. | After initial clone or after `git pull`. |
| `bun backend:start` | Repository root | Spawns local Supabase Docker containers (Postgres, Auth, Storage, Studio). | Daily startup before launching `bun dev`. |
| `bun --filter @onlook/backend stop` | Repository root | Stops all local Supabase containers and backs up volumes. | End of workday or before switching tasks. |
| `bun --filter @onlook/backend status` | Repository root | Prints Supabase endpoints, connection strings, and API keys. | To inspect URLs or copy JWT/anon/service keys. |
| `bun db:push` | Repository root | Synchronizes Drizzle schema directly to PostgreSQL. | Initial setup, or when table definitions in `packages/db` change. |
| `bun db:seed` | Repository root | Inserts test users and sample projects into PostgreSQL. | First-time setup or after resetting database. |
| `bun db:gen` | Repository root | Generates Drizzle migration files based on schema changes. | When preparing new schema migrations for source control. |
| `cd apps/backend && bun run reset` | Repository root | Completely resets the local Supabase database to blank state. | When local database state is corrupt or testing clean setup. |
| `bun dev` | Repository root | Starts Next.js app (port 3000) and Preload CDN (port 8083). | Daily development server. |
| `bun run build` | Repository root | Builds production client bundle. | Validating production build integrity. |
| `bun run typecheck` | Repository root | Runs TypeScript compilation check across client app. | Verifying zero type errors before commits. |
| `bun run lint` | Repository root | Runs ESLint across all workspaces. | Code style and syntax validation. |

---

## 🛠️ Step-by-Step Playbooks

### Playbook A: First-Time Setup (From Zero to Running)
```bash
# 1. Start Docker runtime (Colima)
colima start --cpu 4 --memory 6

# 2. Apply Colima socket fix for virtiofs compatibility
colima ssh -- sudo sh -c "mount -t tmpfs tmpfs \$HOME/.colima/default && ln -sf /var/run/docker.sock \$HOME/.colima/default/docker.sock"

# 3. Clone & install
git clone https://github.com/onlook-dev/onlook.git
cd onlook
bun install

# 4. Start backend
bun backend:start

# 5. Extract keys & populate .env files in apps/web/client/.env & packages/db/.env

# 6. Apply schema and seed initial data
bun db:push
bun db:seed

# 7. Start dev server
bun dev
```

### Playbook B: Daily Start Routine
```bash
colima start
colima ssh -- sudo sh -c "mount -t tmpfs tmpfs \$HOME/.colima/default && ln -sf /var/run/docker.sock \$HOME/.colima/default/docker.sock"
bun backend:start
bun dev
```

### Playbook C: Daily Shutdown Routine
```bash
lsof -ti :3000,8083 | xargs kill -9 2>/dev/null
bun --filter @onlook/backend stop
colima stop
```

---

## 🔑 Key Files

- [`SKILL.md`](SKILL.md) — The operational skill specification loaded directly by AI agents.

---

## 🚀 How to Install & Trigger

### Install to your Agent Skills Directory
```bash
# Claude Code / opencode / Antigravity
cp -r skills/onlook-local-dev ~/.claude/skills/
# or
cp -r skills/onlook-local-dev ~/.gemini/config/skills/
```

### Sample Trigger Prompts
- *"Set up Onlook locally on my machine and start all services."*
- *"Debug my local Onlook Supabase connection and restart the containers."*
- *"Shut down the Onlook dev server and Colima container runtime."*
