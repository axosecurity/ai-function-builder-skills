---
name: clerk-org-rbac
description: Implements multi-tenant role-based access control (RBAC) for Next.js SaaS apps using Clerk Organizations — custom roles, custom permissions, JWT-only authorization (no auth database, no per-request Clerk API calls), the dual Can/PlanGate frontend gating pattern, and a rate-limit-safe caching strategy for Organization metadata. Use this skill whenever the user is building or scaffolding a multi-tenant SaaS product, mentions Clerk Organizations/roles/permissions, asks about access control, RBAC, permission gating, "who can do what," admin/teacher/staff-style roles, or gating a feature by subscription plan vs. by user role — even if they don't say "Clerk" or "RBAC" explicitly. Also trigger when reviewing or debugging an existing Clerk-based authorization system for security gaps (e.g. frontend-only checks, missing backend guards, per-member overrides creeping into a role-based model).
---

# Clerk Organization RBAC

A reusable authorization architecture for multi-tenant Next.js SaaS products built on Clerk Organizations. This is the same pattern used for DocentBase (coaching-center SaaS) — apply it to any new project (Conversora, or future products) without re-deriving the design from scratch.

## Core architecture (non-negotiable, applies to every project)

1. **Clerk is the only authorization store.** Custom roles and custom permissions live entirely in Clerk (Dashboard or Backend API provisioning script) — never a custom permissions table, never per-member overrides in v1. Every member's access = their one assigned role's permission set. Full stop.
2. **Authorization checks are always a local JWT decode.** Every check — frontend or backend — resolves through Clerk's `has({ permission })`, which reads the session JWT already in memory/verified server-side. Zero Clerk Backend API calls and zero database queries for the yes/no decision itself, on every request.
3. **Frontend is cosmetic, backend is the only real gate.** The frontend never performs verification — it just renders differently based on JWT claims. If a user tampers with their own client, the frontend might show something it shouldn't; that's fine, because every mutating/reading endpoint independently calls `auth().has()` on the real, cryptographically verified session and returns `403` regardless of what the client displayed or attempted. Document this loudly in code near the gating components so nobody mistakes hidden UI for security.
4. **Two distinct gates — do not conflate them:**
   - **`Can` (role gate):** hides the element completely when the role lacks the permission. No greyed-out button, no tooltip. Used for org-chart boundaries (e.g. Teacher shouldn't see Website management) — the user can't self-serve their way past it, so teasing it only frustrates.
   - **`PlanGate` (billing gate):** keeps the element visible but locked/greyed with an upgrade CTA when the org's plan doesn't include the feature. Used for business/billing boundaries (e.g. Payment Gateway is Premium-only) — this is a natural upsell moment, so show it.
   - **Precedence when both could apply:** check `Can` first. If role fails, hide — full stop, regardless of plan. Only show the `PlanGate` tease to users whose role would otherwise grant access if the plan allowed it.
5. **Organization `publicMetadata`/`privateMetadata` = app config, never authorization.** Plan tier, feature flags, branding, onboarding progress — yes. NID, personal bank/payment account numbers, anything sensitive — no, those go in the app database (Neon/Postgres or equivalent). Metadata is for things that change rarely and are read by the UI; per-user or per-click state (sidebar collapsed, live usage counters) never belongs here — keep that in local state or a per-user DB row.
6. **Metadata reads are cached client-side (~2 min TTL), shared per tab.** `useOrganization()` already has metadata in memory for free; the refresh interval only exists to catch server-side changes (an admin upgraded billing, a webhook fired) while the tab stays open. One shared module-level cache per tab — mounting the same gate in ten places must not trigger ten reloads. Never call Clerk's Backend API per-request just to render UI data.

## Workflow for a new project

When the user wants this system in a new or existing Next.js + Clerk project:

1. **Gather the project's roles and permissions.** Ask (don't assume) for:
   - The list of org-level roles (e.g. Owner, Admin, Manager, Teacher... — or whatever fits the domain)
   - The domain's core entities/modules (e.g. student, batch, payment — or invoice, contact, campaign, whatever the product is)
   - For each module: which actions exist (create/view/update/delete, plus any domain-specific ones like `payment:refund` or `notice:publish`)
   - Which features are plan-gated (billing-tier limited) vs. purely role-gated
   If the user already has a similar system in another project (check memory/past conversations — e.g. DocentBase's matrix), offer to adapt that matrix rather than starting blank.

2. **Produce the permission catalog and role × permission matrix** as an explicit table (see `references/docentbase-example.md` for the full worked example — 8 roles × 44 permissions across 11 modules). Naming convention: `module:action`, all lowercase, snake_case multi-word actions (`payment:mark_paid`).

3. **Scaffold the code** using the templates in `references/code-templates.md`:
   - `src/lib/auth/permissions.ts`, `roles.ts` — typed constants for autocomplete only, not enforcement
   - `src/lib/auth/can.ts` — frontend `useCan()` hook, thin wrapper over Clerk's `has()`
   - `src/lib/auth/requirePermission.ts` — backend guard, thin wrapper over `auth().has()`, throws 403
   - `src/components/auth/Can.tsx` — role gate component (hides completely)
   - `src/components/auth/PlanGate.tsx` — plan gate component (locked/teaser state)
   - `src/lib/org/useOrgMetadata.ts` — shared 2-minute-TTL metadata cache hook
   - `middleware.ts` — route-group protection via `auth().has()`

4. **Wire it in, in this order** (matches the DocentBase implementation task list):
   1. Provision roles + permissions in Clerk (Dashboard or Backend API script)
   2. Confirm session JWT actually exposes `orgId`/`role`/permissions so `has()` works with zero extra calls
   3. Core lib files → `<Can>` → `<PlanGate>` → `useOrgMetadata()` cache
   4. `middleware.ts` route-group protection
   5. `requirePermission()` guards in every API route that mutates/reads sensitive data
   6. Org-switching flow via `setActive({ organization })`
   7. Any project-specific business-rule guard Clerk's raw model can't express (e.g. "only the true Owner can remove/demote the Owner," even though `member:remove`/`member:change_role` would technically allow Admin to do it) — add these explicitly, don't assume Clerk encodes them
   8. Populate default `publicMetadata`/`privateMetadata` structure on org creation
   9. Unit test `can()`/`requirePermission()` against representative role/permission combos with a mocked `has()`

5. **Sanity-check before calling it done:**
   - Does *every* API route/handler independently call `requirePermission()` — none relying on "the frontend already checked"?
   - Is anything sensitive (IDs, payment account numbers, personal contact info) sitting in `publicMetadata`? Move it to the database.
   - Is any per-user or per-click UI state (sidebar state, dashboard prefs) leaking into Organization metadata? Move it to local/component state or a per-user DB row.
   - Does a `PlanGate` ever get shown to a role that shouldn't even see the feature? Check `Can` wraps `PlanGate`, not the other way around.
   - Are per-member permission overrides being requested? Treat as a deliberate v2 decision (custom session claim from member metadata, still a local JWT read) — don't bolt on ad hoc per-member exceptions to a role-based model.

## Reference files

- `references/docentbase-example.md` — the complete, fully worked DocentBase spec (8 roles, 44 permissions across 11 modules, full onboarding metadata schema, all component code). Use as the template to adapt for a new project rather than writing from scratch.
- `references/code-templates.md` — copy-pasteable, project-agnostic versions of every file in the architecture (`can.ts`, `requirePermission.ts`, `Can.tsx`, `PlanGate.tsx`, `useOrgMetadata.ts`, `middleware.ts`) with placeholders to fill in per-project.
