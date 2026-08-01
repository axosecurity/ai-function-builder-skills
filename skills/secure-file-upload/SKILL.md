---
name: secure-file-upload
description: Implements a production-grade, zero-server-bandwidth file/image/avatar upload system using presigned URLs to S3-compatible storage (S3, Cloudflare R2, etc.), with client-side compression, EXIF stripping, cache-busting object keys, and a 5-layer security model (input validation, presigned-URL locks, HeadObject verification, magic-byte inspection, upload-intent tracking). Use whenever the user asks to implement, add, fix, or debug file/image/avatar/document upload, "upload to S3/R2/Supabase/Firebase/Azure Blob/GCS", presigned URL upload, or wants secure file handling. Trigger even without the phrase "presigned URL" — e.g. "let users upload a photo", "add a file uploader", "profile picture won't upload right". Framework-agnostic (Next.js, Django, Rails, Go, Laravel, Express, etc.).
---

# Secure File Upload

A battle-tested architecture for letting users upload files (avatars, images, documents) directly to cloud object storage — without ever routing file bytes through your own server, and without trusting the client.

Read this file first. It contains the full workflow. The `references/` files are deep-dives — pull them in only when you need the detail (e.g. writing the actual security-check code, or walking a user through R2/S3 console setup).

## Why this architecture ("perfect" = no shortcuts that cause bugs later)

Most AI-generated upload code fails in one of these predictable ways: it proxies file bytes through the app server (slow, expensive, times out on large files); it trusts the client-reported MIME type (lets a `.exe` renamed to `.jpg` through); it uses a deterministic object key like `userId.jpg` (CDN then caches the *old* image and the user sees a stale photo for hours); or it deletes the old file before confirming the new one uploaded (user ends up with no avatar at all if anything fails midway). This skill exists specifically to prevent all four.

Core principle: **the client is never trusted**. Every claim the client makes (file size, MIME type, "the upload succeeded") is independently re-verified server-side before anything is persisted.

## The 4-Phase Flow

```
Phase 1 — CLIENT PREP:      Compress the file + strip EXIF/metadata client-side (worker thread if available)
Phase 2 — REQUEST:          Client asks server for permission; server validates, records an "intent", returns a presigned PUT URL
Phase 3 — DIRECT UPLOAD:    Client PUTs the file straight to storage (S3/R2/etc.) using that URL — server bandwidth: zero
Phase 4 — CONFIRM & SWAP:   Client tells server it's done; server re-verifies the object, THEN swaps it in atomically, THEN deletes the old one
```

See `references/architecture.md` for the full sequence diagram and the pros/cons trade-offs to mention to the user (mainly: 3 network round-trips instead of 1, and the need for a cleanup job for abandoned uploads).

## Step-by-step: what to do when this skill triggers

### 1. Gather requirements first — don't guess

Before writing any code, confirm (infer from context where possible, otherwise ask in one batch):
- **Stack**: language/framework, and does a database already exist for tracking upload state?
- **Storage provider**: S3, Cloudflare R2 (recommended — zero egress fees), Supabase Storage, Firebase, Azure Blob, or GCS? (All support presigned/signed URLs; see `references/configuration.md` for R2/S3 specifics.)
- **File type**: avatars/images only, or arbitrary documents too? This changes the magic-byte whitelist and size limits.
- **Size limit** and **allowed MIME types** (default suggestion for images: 10MB max, whitelist `image/jpeg, image/png, image/webp, image/gif, image/avif`).
- **Auth**: how are users authenticated already (session, JWT, etc.) — reuse it, don't invent a new one.

If the user has already answered these in their prompt, don't re-ask — proceed.

### 2. Design the object key — never deterministic

Generate a random, URL-safe key per upload (e.g. 7+ random chars: `avatars/aB3_x9Z.jpg`). Never use `{userId}.jpg` or any other deterministic name — CDNs cache by URL, so a deterministic name means the old (stale) image keeps being served after a new upload. Randomizing the key is what makes the swap cache-safe for free.

### 3. Implement Phase 1 — client-side prep

- Resize/compress before upload (e.g. `browser-image-compression` in JS, or platform equivalent) to cut bandwidth and storage cost.
- Strip EXIF/metadata during compression — this is also a privacy requirement (EXIF can contain GPS coordinates).
- Do this off the main thread (Web Worker or equivalent) so the UI doesn't freeze on large files.

### 4. Implement Phase 2 — the `/upload/request` endpoint

Server-side, in order:
1. **Validate input** (Layer 1 of security model) — reject if size or MIME type falls outside the whitelist. Use the strictest schema/validation tool idiomatic to the stack (Zod, Pydantic, struct tags, form_request, etc.).
2. **Insert an "upload intent" row** in the DB with status `pending` — this is what makes cleanup of abandoned uploads possible later. See `references/database-schema.md` for the exact schema.
3. **Generate the random object key.**
4. **Generate a presigned PUT URL** that cryptographically locks `Content-Type` and `Content-Length` to the validated values (Layer 2 — see `references/security-model.md` for the exact SDK call). This is what stops a client from swapping in a different/larger file at the storage layer, with zero work from your server.
5. Return the presigned URL + intent ID to the client.

### 5. Implement Phase 3 — direct upload

Client does a `PUT` straight to the presigned URL with the exact `Content-Type`/`Content-Length` it requested. No server code needed here — this is the "zero bandwidth" step.

### 6. Implement Phase 4 — the `/upload/confirm` endpoint

This is where most "AI-generated" upload systems cut corners. Do not skip any of these:
1. **HeadObject verification** (Layer 3): query storage for the actual uploaded object's size/type and compare against the intent record. Mismatch → reject, delete the object, mark intent `failed`.
2. **Magic-byte verification** (Layer 4): fetch *only* the first 16 bytes via an HTTP Range request and check the real file signature against the declared type (e.g. JPEG must start `FF D8 FF`). This is the layer that catches a renamed `.exe`. Full table of signatures is in `references/security-model.md`.
3. **Atomic swap**: fetch the user's *current* file URL from the DB, but do not delete it yet.
4. **Delete the old object** from storage — only now, after the new one passed verification.
5. **Update the DB record** to point at the new file, and mark the intent `completed`.
6. Return the new file's public URL to the client.

If verification fails at any point, delete the newly-uploaded (bad) object and leave the user's existing file untouched — never leave the user in a broken/no-file state.

### 7. Add the cleanup job (Layer 5)

A scheduled job (cron, queued task, whatever's idiomatic to the stack) that finds intents still `pending` after ~5 minutes and deletes the corresponding orphaned storage objects. Without this, abandoned uploads (browser closed mid-upload) silently accumulate storage cost forever.

### 8. Set response headers / error codes correctly

- Confirm success → return the new object's public URL.
- Any verification failure → clear error response (4xx), never a silent partial success.

## Final verification checklist — run through this before showing the user code

- [ ] Object keys are random, not deterministic (`{userId}.ext`)
- [ ] Presigned URL locks both Content-Type AND Content-Length
- [ ] `/confirm` does HeadObject verification, not just trusting the client's "done" signal
- [ ] `/confirm` does magic-byte inspection (first bytes only, via Range request) — not just trusting the extension/MIME
- [ ] Old file is deleted only *after* the new file passes all checks (never before)
- [ ] There's an intent-tracking table/record with a `pending → completed/failed/expired` state machine
- [ ] A cleanup mechanism exists for abandoned `pending` intents
- [ ] Size/MIME whitelist enforced server-side (not just in client UI)
- [ ] EXIF/metadata stripped client-side before upload
- [ ] Auth reused from the existing app, not reinvented

If any box can't be checked, say so explicitly to the user rather than presenting the code as complete — that's the difference between "no bugs" and "looks done."

## Reference files (load as needed)

- `references/architecture.md` — full sequence diagram, pros/cons to explain to the user
- `references/security-model.md` — all 5 layers in depth, with SDK code samples (presigned URL locking, magic-byte signature table)
- `references/database-schema.md` — the `users` / `upload_intents` / `audit_logs` schema and state-machine lifecycle
- `references/configuration.md` — step-by-step Cloudflare R2 and AWS S3 console setup (bucket creation, API keys, CORS policy) to hand to the user
- `references/reference-prompt.md` — a copy-paste, stack-agnostic prompt version of this whole skill, for handing to *another* AI agent that doesn't have this skill loaded
