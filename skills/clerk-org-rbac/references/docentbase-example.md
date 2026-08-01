# Worked Example: DocentBase — Access Control & Authorization System (Clerk-Only, Role-Based, No DB)

This is the complete, original spec this skill was extracted from. It was written for DocentBase
(multi-tenant coaching-center SaaS, Next.js via OpenNext on Cloudflare Workers, Clerk auth, Neon
Postgres, Cloudflare R2/Queues, Resend). Use it as a template: copy the structure, swap in the new
project's roles/modules/permissions, and adapt the onboarding/metadata sections to the new domain.

> Credentials note: secrets (Clerk keys, DB connection strings, storage keys, email provider keys)
> always live in `.env` / `process.env.*`. Never hardcode, invent, print, or ask the user to paste a
> key into chat or source files. If a required env var is missing, stop and name which one — don't
> substitute a placeholder or fake key.

---

## 0. Project Context Template

- **Product:** [name] — [one-line description]
- **Stack:** Next.js (full-stack), Clerk (auth + organizations + authorization), [DB], [storage], [email]
- **Multi-tenancy model:** Each [tenant unit, e.g. "coaching center" / "workspace" / "store"] = one
  Clerk **Organization**. A user can belong to multiple organizations with a different role in each,
  but only **one organization is active** in their session at a time.
- **Goal:** Full RBAC implemented entirely inside Clerk — custom roles and custom permissions,
  resolved on every request straight from the session JWT. No custom permission database, no
  per-member overrides, no extra API calls for authorization decisions.

## 1. Core Authentication & Org-Switching Flow

1. User logs in via Clerk.
2. Clerk loads the user's organization memberships (N orgs, each with a possibly different role).
3. Exactly one organization is "active" at a time. Clerk's session JWT `org` claims encode `orgId`,
   `role`, and a permission bitmask for that role — computed and issued by Clerk itself.
4. **Frontend:** `useAuth()` / `useOrganization()` + `has({ permission })` conditionally render UI.
   Reads the decoded JWT already in memory — no network call.
5. **Backend:** `auth()` verifies the session, then `has({ permission: '...' })` gates the action
   before it runs. Local JWT decode, no Clerk API call per request. `403` if `has()` is false.
6. **Switching organizations:** `setActive({ organization: org_x })` refreshes the JWT with the new
   `orgId`/`role`/permissions. Frontend re-renders automatically; backend reflects it next request.

**Key invariants:**
- The session JWT contains only the **active** organization's role/permissions — never a mix.
- Clerk is authoritative for "what permissions does this role have" (configured once in Dashboard
  or via Backend API during setup) — never re-implemented in app code or a database.
- Every permission check is a **local JWT decode** — zero Clerk Backend API calls, zero DB queries.
- All members of a given role get identical permissions — no per-user exception in v1.

## 2. Roles (DocentBase example — 8 roles)

| Role | Summary |
|---|---|
| **Owner** | Unrestricted access to everything, including deleting the org. Exactly one per org. |
| **Admin** | Everything Owner has, except deleting the org (and cannot remove/demote the Owner). |
| **Manager** | Runs daily operations — full access to students, batches, attendance, payments, notices, notes, exams, reports. No org/member/website management. |
| **Teacher** | Academic-focused — view/update students, mark attendance, manage own notes/exams, view payments/notices/reports. No delete rights. |
| **Receptionist** | Admissions + fee collection — create/view/update students, view batches/attendance, manage payment status, view notices/reports. |
| **Accountant** | Finance-only — full payment permissions (incl. refund), view students/batches, view/export reports. |
| **Website Manager** | Only manages the org's public website — update/publish website, view notices/reports. |
| **Viewer** | Read-only across students, batches, attendance, payments, notices, notes, exams, reports. |

> Domain entities managed *by* the app (e.g. "Student") are never roles — they never get org login/permissions.
> The only lever for adjusting a person's access is `member:change_role` (whoever holds it) — moving
> them to a different role, never editing individual permissions.

## 3. Permission Catalog (DocentBase example — 44 permissions, 11 modules)

```
Organization:      org:settings, org:delete, org:branding, org:subscription
Member Management: member:view, member:invite, member:remove, member:change_role
Student Mgmt:      student:create, student:view, student:update, student:delete
Batch Mgmt:        batch:create, batch:view, batch:update, batch:delete
Attendance:        attendance:view, attendance:mark, attendance:update
Payments:          payment:view, payment:update, payment:mark_paid, payment:mark_unpaid,
                   payment:next_month, payment:need_time, payment:refund
Notice Board:      notice:create, notice:view, notice:update, notice:delete
Notes:             note:create, note:view, note:update, note:delete
Exams:             exam:create, exam:view, exam:update, exam:delete
Website:           website:update, website:publish
Reports:           report:view, report:export
```

Naming convention: `module:action`, lowercase, snake_case for multi-word actions.
Attach each permission to the appropriate role(s) directly in Clerk Dashboard (Organization
Settings → Roles & Permissions), or provision programmatically via Clerk's Backend API.

## 4. Role × Permission Matrix (DocentBase example, full)

| Permission | Owner | Admin | Manager | Teacher | Receptionist | Accountant | Website Mgr | Viewer |
|---|---|---|---|---|---|---|---|---|
| org:settings | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| org:delete | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| org:branding | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| org:subscription | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| member:view | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| member:invite | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| member:remove | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| member:change_role | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| student:create | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| student:view | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| student:update | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| student:delete | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| batch:create | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| batch:view | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| batch:update | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| batch:delete | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| attendance:view | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ |
| attendance:mark | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| attendance:update | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| payment:view | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| payment:update | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| payment:mark_paid | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| payment:mark_unpaid | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| payment:next_month | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| payment:need_time | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| payment:refund | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| notice:create | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| notice:view | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| notice:update | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| notice:delete | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| note:create | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| note:view | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| note:update | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| note:delete | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| exam:create | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| exam:view | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| exam:update | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| exam:delete | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| website:update | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| website:publish | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| report:view | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| report:export | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |

**Design principles enforced:**
- Owner has unrestricted access to everything; only Owner can delete the org.
- Admin manages the org but can never delete it, and app logic must block Admin from
  removing/demoting the Owner even though Clerk's raw permission model would technically allow it
  (`member:remove`/`member:change_role`) — this is an explicit app-level guard, since Clerk doesn't
  know about the "Owner is special" business rule.
- Every permission check must fail closed (deny by default) if `has()` returns false or is ambiguous.
- Finer-grained per-person exceptions (e.g. "this one Teacher also needs refund access") are a
  deliberate v2 decision, not an ad hoc bolt-on — implement later via a custom session claim sourced
  from that member's metadata, keeping the check a local JWT read rather than a live API call.

## 5. Organization Onboarding — Example Data Points (adapt per domain)

DocentBase collected, in flexible any-order fashion (not a locked linear wizard, minimum required
to create the org only): institution type/name/logo, location + optional Maps link, email, two
phone numbers (personal private / public), institution photos, owner info (name, phone, NID —
**NID never public**), teaching language(s), WhatsApp/Facebook links, owner's personal payment
account details (bKash/Nagad/bank — sensitive), payment gateway placeholder, QR setup, academic
info, batch info, fee policy, attendance method choice, monthly report preferences.

**Pattern to reuse regardless of domain:**
- Only the true minimum to create the org is mandatory up front; everything else is completable/
  editable later from settings, in any order, under logical field *groups* (not numbered steps).
- Track **completion per group**, not a numeric step index, so the UI can prompt to finish
  incomplete sections without forcing an order.
- Anything sensitive (government ID numbers, personal financial account numbers) must live in the
  application database — never in Clerk `publicMetadata`, never exposed via a public API or website.

## 6. Clerk Organization Metadata Structure (App Config Only — Not Authorization)

**Field-selection rule:** a field belongs in Organization `publicMetadata` only if it is (a)
actually read by the UI, and (b) changes rarely — plan tier, feature flags, branding, locale,
onboarding status. Anything that changes on every request/click (per-user UI toggles, live usage
counters) does *not* belong here.

```json
{
  "app": {
    "onboardingCompleted": false,
    "onboardingSectionsCompleted": ["institution", "contact", "academic"],
    "createdFrom": "web"
  },
  "institution": { "type": "coaching_center", "defaultLanguage": "bn", "timezone": "Asia/Dhaka", "currency": "BDT" },
  "subscription": { "plan": "starter", "status": "active", "billingCycle": "monthly", "trial": false },
  "features": {
    "attendance": true, "payments": true, "studentManagement": true, "teacherManagement": true,
    "batchManagement": true, "monthlyReports": true, "noticeBoard": true, "teacherPortal": true,
    "guardianPortal": false, "studentPortal": false, "paymentGateway": false, "sms": false,
    "email": true, "pushNotification": true
  },
  "limits": { "students": 500, "teachers": 20, "batches": 30, "branches": 1, "admins": 2, "storageGB": 5 },
  "branding": { "theme": "default", "primaryColor": "#2563EB", "darkMode": false },
  "region": { "country": "Bangladesh", "division": "Dhaka", "locale": "bn-BD", "dateFormat": "DD-MM-YYYY" }
}
```

> **`limits` vs. usage:** `limits.*` are the plan's *caps* — they only change on plan change, so
> metadata is fine. Current *usage* (e.g. "312 of 500 students") changes constantly — compute it
> from the app DB on demand behind the relevant endpoint, and combine it client-side with the
> cached `limits` number only when the relevant screen needs it. Never store live usage in metadata.

> **Never put per-user UI state here** (sidebar collapsed, compact tables, default dashboard) — it
> changes on nearly every click and isn't shared across an org's members. Every toggle would
> otherwise be a Clerk metadata write, risking rate limits for purely cosmetic per-browser state.
> Keep it in local component state or a per-user DB row keyed by `userId`.

Private metadata (server-only, keep minimal for v1): `{ "status": { "active": true, "verified": false, "suspended": false, "maintenance": false } }`.

Reserve top-level metadata namespaces up front so future additions don't collide:
`app, institution, subscription, features, limits, branding, status, security, notifications, integrations, beta, region, flags, migration, cache`.

## 7. Authorization Enforcement Architecture

```
                 USER
                   │
        ┌──────────┴──────────┐
        │                     │
        ▼                     ▼
  UI Authorization      Route Protection (middleware.ts)
   (Clerk has())          (Clerk auth().has())
        │                     │
        └──────────┬──────────┘
                    │
                    ▼
               API Request
                    │
                    ▼
       Authorization Check (requirePermission →
              Clerk auth().has())
                    │
             ┌──────┴───────┐
             │              │
           Allowed      403 Forbidden
```

### 7.1 Core Principle — Frontend Is Not a Security Boundary

The frontend's job is to make the UI *look* correct for the signed-in user's role; it is never the
thing standing between a user and unauthorized data. It reads permissions directly from the JWT
with no separate verification step — there's nothing to verify, it's a display decision, not a
security decision. A tampered client JWT might render UI it "shouldn't," and that only affects that
one user's own screen — every real mutation/read still goes through `auth().has()` on the real,
cryptographically verified session, returning `403` regardless of what the client attempted.

### 7.2 Two Gating Patterns

**`Can` — role/permission gate (org-chart boundary → hide completely).** If the role lacks the
permission, the element does not render at all. No greyed button, no lock icon, no tooltip — the
user can't self-serve past a role boundary (only an Owner/Admin can change their role), so teasing
it only produces frustration, and can read as "the system doesn't trust me."

**`PlanGate` — plan/billing gate (business boundary → show, tease, upsell).** The feature stays
fully visible to everyone who could otherwise access it by role; if the org's plan doesn't include
it, it renders locked/greyed with an "Upgrade" CTA on click — never a silent fail or hide. This is
free marketing and a natural upsell moment. Source of truth: `publicMetadata.features.*`, not the
JWT — plan flags are org-level config, not user permissions. Only meaningful for whoever could act
on it (usually Owner/Admin, who can upgrade billing); someone lacking the underlying role
permission still gets the `Can` treatment (hidden) regardless of plan.

**Precedence:** check `Can` first. Role fails → hide, full stop, regardless of plan. Only show the
`PlanGate` tease to users whose role would otherwise grant access if the plan allowed it.

### 7.3–7.5 Implementation, backend enforcement, and summary table

See `references/code-templates.md` for the full, project-agnostic code (the `useCan()` hook,
`<Can>`, `<PlanGate>`, `useOrgMetadata()` cache, `requirePermission()`, and `middleware.ts`).

Rule to enforce everywhere: if a tampered/forged client claims a permission it doesn't actually
have, the frontend might render the button — but every backend call it triggers must independently
verify against the real, cryptographically-signed session and return `403`. Must hold for 100% of
mutating/reading endpoints, with no exceptions "because the frontend already checked."

| Concern | Gate | Source of truth | Behavior when denied | Verified? |
|---|---|---|---|---|
| Role/permission | `Can` | Session JWT (`has()`) | Hidden completely | No — display only; backend re-verifies every request |
| Plan/billing | `PlanGate` | Org `publicMetadata.features` | Visible, locked, upsell CTA | No — display only; backend re-verifies the entitlement before acting |
| Actual request execution | `requirePermission()` / `middleware.ts` | Real, verified Clerk session | `403` / redirect | **Yes — the only real gate** |

## 8. Suggested File Structure

```
src/
├── lib/
│   ├── auth/
│   │   ├── permissions.ts       // Typed permission string constants (autocomplete only)
│   │   ├── roles.ts             // Role name constants
│   │   ├── can.ts               // Frontend permission helper (thin wrapper over Clerk has())
│   │   ├── requirePermission.ts // Backend guard (thin wrapper over Clerk auth().has())
│   │   └── clerk.ts             // Clerk client/helpers (setActive, etc.)
│   └── org/
│       └── useOrgMetadata.ts    // Shared 2-minute-TTL client cache over org publicMetadata
├── components/
│   └── auth/
│       ├── Can.tsx              // Role/permission wrapper (hides completely)
│       └── PlanGate.tsx         // Plan/billing wrapper (shows locked/teaser state)
├── middleware.ts                // Route protection via Clerk auth().has()
└── app/
    └── api/                     // Route handlers, each guarded by requirePermission()
```

## 9. Implementation Task List (do in order)

1. Create the roles + permissions in Clerk (Dashboard or Backend API script), attach per the matrix.
2. Verify session claims expose `orgId`/`role`/permissions so `auth().has()` works with zero extra calls.
3. Build `permissions.ts`, `roles.ts`, `can.ts`, `requirePermission.ts`, `clerk.ts` — thin wrappers, nothing else.
4. Build `<Can>` — hides completely when denied.
5. Build `<PlanGate>` — locked/teaser state with upgrade CTA when denied, reading from `useOrgMetadata()`.
5a. Build the shared `useOrgMetadata()` 2-minute-TTL cache hook; confirm every metadata consumer uses it.
6. `middleware.ts` — protect route groups by required permission.
7. Wire `requirePermission()` into every route that mutates/reads sensitive data.
8. Implement "Switch Organization" calling `setActive({ organization })`; verify both layers pick up the new active org immediately.
9. Add the explicit Owner-protection guard (or any equivalent project-specific business rule Clerk's raw model doesn't encode).
10. Build the onboarding flow collecting domain-specific data, writing sensitive fields to the app DB — never public metadata.
11. Initialize default `publicMetadata`/`privateMetadata` structures on org creation.
12. Unit test `can()`/`requirePermission()` against representative role/permission combos with a mocked `has()`.

## 10. Explicit Non-Goals for v1 (apply by default unless the project needs otherwise)

- No custom session/JWT system, no custom roles/permissions database — Clerk Organizations is the
  only identity, session, and authorization provider.
- No per-member permission overrides — access is purely role-based; adjusting access means
  changing the role, not editing individual permissions. Revisit only on genuine business need.
- No frontend-side JWT signature verification — irrelevant for a display decision; Clerk's client
  SDK already decodes claims via `has()`.
- No assumption that hiding a UI element is a security control. It never is.
