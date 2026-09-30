---
name: onlook-local-dev
description: Autonomous installation, environment setup, database provisioning, lifecycle management, and troubleshooting guide for running Onlook (the open-source visual editor for React and Tailwind CSS) on a local machine. Covers Docker/Colima containerization, Supabase local backend initialization, Drizzle ORM migration & seeding, and Next.js dev server operations.
argument-hint: "[action: install | start | stop | status | test]"
license: Apache-2.0
metadata:
  author: axosecurity
  version: "1.1.0"
---

# Onlook Local Development & Autonomous Management Skill

This skill equips developers and AI agents with complete procedural instructions, architecture details, troubleshooting fixes, and a comprehensive **Command Reference & Help Guide** to clone, provision, run, manage, and shut down **Onlook** locally.

---

## 🏗️ Architecture Overview

Onlook is a monorepo consisting of:
1. **Web Client (`apps/web/client`)**: Next.js 16 (App Router + Turbopack) application listening on port `3000`.
2. **Preload Script / CDN Server (`apps/web/preload`)**: Bun HTTP server listening on port `8083` that bundles and serves `onlook-preload-script.js` into sandboxes and inspected applications.
3. **Local Backend (`apps/backend`)**: Supabase CLI managing local Docker containers:
   - PostgreSQL (`postgresql://postgres:postgres@127.0.0.1:54322/postgres`)
   - Kong Gateway / API (`http://127.0.0.1:54321`)
   - Supabase Studio Dashboard (`http://127.0.0.1:54323`)
   - Mailpit / Inbucket email UI (`http://127.0.0.1:54324`)
   - Storage S3 (`http://127.0.0.1:54321/storage/v1/s3`)
4. **Database Package (`packages/db`)**: Drizzle ORM schema definitions, migrations, and seed scripts.
5. **External Integrations**:
   - `OPENROUTER_API_KEY`: For AI chat and code intelligence.
   - `CSB_API_KEY`: CodeSandbox API key for running dev containers and sandboxes.

---

## 📋 Prerequisites

| Tool | Required Version | Purpose |
| :--- | :--- | :--- |
| **Bun** | >= 1.2.0 | Monorepo package manager & runtime |
| **Node.js** | >= 20.16.0 | Build scripts and compatibility |
| **Docker / Colima** | Latest | Container runtime for Supabase local stack |
| **Git** | Latest | Source control |

### Setting up Docker on macOS (via Colima without root/sudo)
If Docker Desktop is not installed:
```bash
brew install docker colima
colima start --cpu 4 --memory 6
```

#### ⚠️ Critical Colima Socket Fix
When running Supabase via Colima, Supabase CLI attempts to mount the host socket (`~/.colima/default/docker.sock`) into containers. Because macOS virtiofs doesn't expose host Unix domain sockets into the Linux VM, this causes:
`error while creating mount source path '.../docker.sock': mkdir .../docker.sock: operation not supported`

**Fix**: Run this command inside the Colima VM to link the internal docker socket:
```bash
colima ssh -- sudo sh -c "mount -t tmpfs tmpfs \$HOME/.colima/default && ln -sf /var/run/docker.sock \$HOME/.colima/default/docker.sock"
```
Verify the fix:
```bash
docker run --rm -v $HOME/.colima/default/docker.sock:/var/run/docker.sock alpine ls -la /var/run/docker.sock
```

---

## 🚀 Step-by-Step Installation & Setup

### Step 1: Clone and Install
```bash
cd /Users/solaman/tool
git clone https://github.com/onlook-dev/onlook.git
cd onlook
bun install
```

### Step 2: Start Local Supabase Backend
Ensure Docker daemon is active, then:
```bash
bun backend:start
```
*Note*: If prompted `Bucket preview_images already exists. Do you want to overwrite its properties? [Y/n]`, send `Y`.

### Step 3: Extract Backend Credentials
Run the JSON status check to obtain active keys:
```bash
npx supabase status -o json --workdir apps/backend
```
Extract:
- `ANON_KEY`
- `SERVICE_ROLE_KEY`
- `PUBLISHABLE_KEY`
- `SECRET_KEY`

### Step 4: Configure Environment Variables

#### 1. Web Client Environment: `apps/web/client/.env`
```properties
# ------------- Required Keys -------------
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=<ANON_KEY>
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=<PUBLISHABLE_KEY>
SUPABASE_DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres
SUPABASE_SERVICE_ROLE_KEY=<SERVICE_ROLE_KEY>

# AI & Sandbox Integrations
OPENROUTER_API_KEY=<OPENROUTER_API_KEY>
CSB_API_KEY=<CSB_API_KEY>
```

#### 2. Database Package Environment: `packages/db/.env`
```properties
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_SERVICE_ROLE_KEY=<SERVICE_ROLE_KEY>
SUPABASE_SECRET_KEY=<SECRET_KEY>
SUPABASE_DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres
```

### Step 5: Push Database Schema
```bash
bun db:push
```
This runs `drizzle-kit push` against the local PostgreSQL container.

### Step 6: Seed Database
```bash
bun db:seed
```
This populates test users and default workspace entities.

### Step 7: Start Development Server
```bash
bun dev
```
This concurrently starts:
- Next.js web application on `http://localhost:3000`
- Preload script server on `http://localhost:8083`

---

## 📖 Help & Command Reference: Which Command to Use for What

This section is a complete manual for every command in the Onlook stack, when to run it, what it does, and how it behaves.

### ⚡ Quick Command Cheat Sheet

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

### 📘 Detailed Command Usage & Options

#### 1. Container & Daemon Management (`colima`)
- **`colima start --cpu 4 --memory 6`**:
  - *Purpose*: Boots the Linux virtual machine that hosts the Docker engine.
  - *Options*: `--cpu 4` allocates 4 cores; `--memory 6` allocates 6 GiB RAM (recommended for running Supabase with multiple containers smoothly).
- **`colima stop`**:
  - *Purpose*: Shuts down Lima VM, detaching network forwards and socket listeners.
- **`colima ssh -- <command>`**:
  - *Purpose*: Executes an arbitrary command inside the Colima Linux guest. Used for the socket tmpfs fix.

#### 2. Backend & Supabase Management (`@onlook/backend`)
- **`bun backend:start`**:
  - *Purpose*: Calls `supabase start`. Checks local Docker images, starts PostgreSQL on port 54322, Kong API gateway on 54321, and Studio on 54323.
  - *Handling prompts*: Supabase may ask `Bucket preview_images already exists. Do you want to overwrite its properties? [Y/n]`. Enter `Y` or pipe `yes Y | bun backend:start`.
- **`bun --filter @onlook/backend stop`**:
  - *Purpose*: Calls `supabase stop`. Stops and cleans up the Docker containers while preserving local Postgres database volumes.
- **`npx supabase status -o json --workdir apps/backend`**:
  - *Purpose*: Returns clean JSON containing `ANON_KEY`, `SERVICE_ROLE_KEY`, `API_URL`, `DB_URL`, etc., easily parsed in scripts.

#### 3. Database & Drizzle Operations (`packages/db`)
- **`bun db:push`**:
  - *Purpose*: Compares the Drizzle TypeScript schemas in `packages/db/src/schema` against the live PostgreSQL database and applies schema diffs without manual SQL files.
  - *When to use*: Run every time you modify files in `packages/db/src/schema/`.
- **`bun db:seed`**:
  - *Purpose*: Executes `packages/db/src/seed/seed.ts`. Seeds a default test user into Supabase Auth and inserts sample workspace projects into PostgreSQL.
  - *Credentials seeded*: Default seeded user has email `test@onlook.com` or configured credentials in the seed file.
- **`bun db:gen`**:
  - *Purpose*: Runs `drizzle-kit generate` to produce static SQL migration files in `apps/backend/supabase/migrations`.

#### 4. Frontend Application (`apps/web/client` & `apps/web/preload`)
- **`bun dev`**:
  - *Purpose*: Concurrently starts:
    1. `@onlook/web-client`: Next.js 16 app with Turbopack on `http://localhost:3000`.
    2. `@onlook/web-preload`: Preload script watcher & CDN server on `http://localhost:8083`.
  - *Stopping*: Press `Ctrl + C` or terminate with `lsof -ti :3000,8083 | xargs kill -9`.

---

## 🎯 Common Playbooks & Workflows

### Playbook A: First-Time Setup (Zero to Running)
Follow this flow when setting up a fresh machine:
```bash
# 1. Start Docker runtime
colima start --cpu 4 --memory 6

# 2. Apply Colima socket fix
colima ssh -- sudo sh -c "mount -t tmpfs tmpfs \$HOME/.colima/default && ln -sf /var/run/docker.sock \$HOME/.colima/default/docker.sock"

# 3. Clone & install
cd /Users/solaman/tool
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
When your environment is already set up and you are starting work:
```bash
# 1. Start Docker VM
colima start

# 2. Re-apply socket symlink (required once after colima reboots)
colima ssh -- sudo sh -c "mount -t tmpfs tmpfs \$HOME/.colima/default && ln -sf /var/run/docker.sock \$HOME/.colima/default/docker.sock"

# 3. Start local Supabase backend
bun backend:start

# 4. Start frontend
bun dev
# Visit http://localhost:3000 in your browser!
```

### Playbook C: Daily End / Shutdown Routine
When you are finishing work and want to free all system resources:
```bash
# 1. Stop Next.js and CDN servers (Ctrl+C or kill ports)
lsof -ti :3000,8083 | xargs kill -9 2>/dev/null

# 2. Stop Supabase local containers
bun --filter @onlook/backend stop

# 3. Stop Colima VM
colima stop
```

### Playbook D: Syncing Code Changes from Git
When you pull new commits that include dependencies or database migrations:
```bash
git pull origin main
bun install
bun backend:start
bun db:push
bun dev
```

### Playbook E: Full Reset (When Database or State is Broken)
If migrations conflict or test data becomes corrupt:
```bash
# Reset database in Supabase
cd apps/backend && bun run reset
cd ../..

# Re-push schema and re-seed
bun db:push
bun db:seed
```

---

## 🔑 Environment Variables Dictionary

| Key | File | Purpose | Source |
| :--- | :--- | :--- | :--- |
| `NEXT_PUBLIC_SUPABASE_URL` | `apps/web/client/.env` | Supabase API endpoint accessible by browser client | `http://127.0.0.1:54321` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | `apps/web/client/.env` | Public Supabase anon JWT key | Output from `bun backend:start` |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | `apps/web/client/.env` | Supabase publishable identifier | Output from `bun backend:start` |
| `SUPABASE_SERVICE_ROLE_KEY` | Both `.env` files | Supabase admin secret key (bypasses RLS) | Output from `bun backend:start` |
| `SUPABASE_DATABASE_URL` | Both `.env` files | Direct PostgreSQL connection string | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` |
| `OPENROUTER_API_KEY` | `apps/web/client/.env` | API key to talk to OpenRouter LLMs | Generated at [openrouter.ai/settings/keys](https://openrouter.ai/settings/keys) |
| `CSB_API_KEY` | `apps/web/client/.env` | CodeSandbox API key to provision sandboxes | Generated at [codesandbox.io/t/api](https://codesandbox.io/t/api) |

---

## 🔍 Verification & Health Checks

Verify all components are functional:
```bash
# 1. Web App Check
curl -I http://localhost:3000
# Expected: HTTP/1.1 200 OK

# 2. Preload CDN Script Check
curl -I http://localhost:8083/
# Expected: HTTP/1.1 200 OK (Content-Type: application/javascript)

# 3. Supabase Studio Check
curl -I http://127.0.0.1:54323/
# Expected: HTTP/1.1 307 Temporary Redirect to /project/default
```

---

## 🛠️ Common Errors & Resolution Matrix

| Symptom | Root Cause | Fix |
| :--- | :--- | :--- |
| `Cannot connect to the Docker daemon` | Colima VM not running | Run `colima start` |
| `mkdir .../docker.sock: operation not supported` | virtiofs cannot map host unix socket inside Colima | Run `colima ssh -- sudo sh -c "mount -t tmpfs tmpfs \$HOME/.colima/default && ln -sf /var/run/docker.sock \$HOME/.colima/default/docker.sock"` |
| `Bucket preview_images already exists` prompt | Supabase start interactive prompt | Send `Y` |
| Port 3000 or 8083 already in use | Previous server process hanging | `lsof -ti :3000,8083 \| xargs kill -9` |
| `drizzle-kit push` fails to connect | Supabase Postgres container down | Run `bun backend:start` and verify port 54322 is open |
| `OpenRouter API error 401` in chat | Invalid or missing `OPENROUTER_API_KEY` | Verify key in `apps/web/client/.env` |
| Sandbox fails to boot in editor | Invalid or missing `CSB_API_KEY` | Verify key in `apps/web/client/.env` |
