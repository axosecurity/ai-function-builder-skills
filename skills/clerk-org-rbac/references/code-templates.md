# Code Templates — Clerk Organization RBAC

Project-agnostic versions of every file in the architecture. Replace bracketed placeholders
(`[MODULE]`, `[feature]`, etc.) with the new project's actual modules/permissions/features.

## `src/lib/auth/can.ts` — frontend hook, reads JWT claims directly, no verification

```ts
'use client'
import { useAuth } from '@clerk/nextjs'

/**
 * Reads the permission straight from the already-decoded session JWT
 * (Clerk's has() does this internally — no network call, no verification
 * step here; this is a display decision, not a security decision).
 */
export function useCan(permission: string): boolean {
  const { has, isLoaded } = useAuth()
  if (!isLoaded) return false
  return has?.({ permission }) ?? false
}
```

## `src/components/auth/Can.tsx` — role gate, hides completely

```tsx
'use client'
import { useCan } from '@/lib/auth/can'

export function Can({
  permission,
  children,
}: {
  permission: string
  children: React.ReactNode
}) {
  const allowed = useCan(permission)
  if (!allowed) return null
  return <>{children}</>
}
```

Usage:
```tsx
<Can permission="[module]:[action]">
  <SomeNavItemOrButton />
</Can>
```

## `src/lib/org/useOrgMetadata.ts` — shared 2-minute-TTL cache over org publicMetadata

```ts
'use client'
import { useOrganization } from '@clerk/nextjs'
import { useEffect, useRef, useState } from 'react'

const REFRESH_INTERVAL_MS = 2 * 60 * 1000 // 2 minutes — safe margin under Clerk's rate limits

type PublicMetadata = Record<string, unknown>

// Module-level, shared by every component instance in this tab — mounting
// <Can>/<PlanGate> in many places reads the same cached value instead of
// each triggering its own reload.
let cachedOrgId: string | null = null
let lastFetchedAt = 0
let reloadInFlight: Promise<void> | null = null

export function useOrgMetadata(): PublicMetadata | undefined {
  const { organization, isLoaded } = useOrganization()
  const [, tick] = useState(0)
  const intervalRef = useRef<ReturnType<typeof setInterval>>()

  useEffect(() => {
    if (!isLoaded || !organization) return

    const maybeRefresh = () => {
      const stale = cachedOrgId !== organization.id || Date.now() - lastFetchedAt > REFRESH_INTERVAL_MS
      if (!stale || reloadInFlight || document.visibilityState === 'hidden') return
      reloadInFlight = organization.reload().then(() => {
        cachedOrgId = organization.id
        lastFetchedAt = Date.now()
        reloadInFlight = null
        tick((n) => n + 1)
      })
    }

    maybeRefresh()
    intervalRef.current = setInterval(maybeRefresh, REFRESH_INTERVAL_MS)
    return () => clearInterval(intervalRef.current)
  }, [isLoaded, organization])

  return organization?.publicMetadata as PublicMetadata | undefined
}
```

Usage:
```tsx
const metadata = useOrgMetadata()
const featureEnabled = Boolean(metadata?.features?.[featureName])
```

## `src/components/auth/PlanGate.tsx` — plan gate, shows a locked/teaser state

```tsx
'use client'
import { useState } from 'react'
import { useOrgMetadata } from '@/lib/org/useOrgMetadata'
import { UpgradeModal } from '@/components/billing/UpgradeModal' // build per project

export function PlanGate({
  feature,
  children,
}: {
  feature: string // key under publicMetadata.features
  children: React.ReactNode
}) {
  const metadata = useOrgMetadata()
  const [showUpgrade, setShowUpgrade] = useState(false)

  const enabled = Boolean((metadata as any)?.features?.[feature])

  if (enabled) return <>{children}</>

  return (
    <>
      <div className="opacity-50 cursor-pointer relative" onClick={() => setShowUpgrade(true)}>
        {children}
        {/* Replace with your lock icon component */}
      </div>
      <UpgradeModal open={showUpgrade} feature={feature} onClose={() => setShowUpgrade(false)} />
    </>
  )
}
```

Usage — role gate wraps plan gate (role fails → hidden regardless of plan; plan fails but role
passes → teaser shown):
```tsx
<Can permission="org:subscription">
  <PlanGate feature="[featureName]">
    <SomeGatedFeatureComponent />
  </PlanGate>
</Can>
```

## `src/lib/auth/requirePermission.ts` — backend guard, the only real gate

```ts
import { auth } from '@clerk/nextjs/server'

export async function requirePermission(permission: string) {
  const { has, userId } = await auth()
  if (!userId) throw new Response('Unauthorized', { status: 401 })
  if (!has({ permission })) {
    throw new Response('Forbidden', { status: 403 })
  }
}
```

Usage in a route handler:
```ts
// app/api/[resource]/route.ts
export async function PATCH(req: Request) {
  await requirePermission('[module]:[action]') // real, server-verified check
  // ... proceed
}
```

## `middleware.ts` — route-group protection

```ts
import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server'

const isProtectedRoute = createRouteMatcher(['/dashboard/settings/[section](.*)'])

export default clerkMiddleware(async (auth, req) => {
  if (isProtectedRoute(req)) {
    const { has } = await auth()
    if (!has({ permission: '[module]:[action]' })) {
      return Response.redirect(new URL('/dashboard', req.url))
    }
  }
})
```

## Owner-protection guard pattern (any business rule Clerk's raw model can't express)

Clerk's permission model is flat — it doesn't know "the Owner is special." If the project has a
rule like "only the true Owner can remove/demote the Owner," enforce it as an explicit app-level
check inside the relevant route handler, on top of (not instead of) the normal `requirePermission()`
call:

```ts
export async function DELETE(req: Request, { params }: { params: { memberId: string } }) {
  await requirePermission('member:remove')
  const targetMember = await getMember(params.memberId) // however the project fetches this
  if (targetMember.role === 'owner') {
    throw new Response('Cannot remove the organization Owner', { status: 403 })
  }
  // ... proceed
}
```

## Provisioning script skeleton (Clerk Backend API)

For projects that want roles/permissions created via script rather than the Dashboard:

```ts
// scripts/provision-clerk-rbac.ts
// Pseudocode — check Clerk's current Backend API for the exact organization-role/permission
// endpoints at implementation time, since this surface has changed across Clerk SDK versions.
const roles = [/* role definitions with permission keys attached, per the project's matrix */]
for (const role of roles) {
  // create or update the custom role, attach its permission set
}
```
