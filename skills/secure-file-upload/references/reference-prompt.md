# Standalone Prompt (for other AI agents / tools that don't have this skill installed)

When the user wants to hand this architecture to a different AI tool (ChatGPT, a coding agent CLI, etc.) rather than have Claude implement it directly, give them this block to copy-paste. Fill in their stack/DB before sending.

---

```text
Implement a "Secure File Upload System" for my project. Stack: [FRAMEWORK], Database: [DATABASE], Storage: [S3 / Cloudflare R2 / other].

Build a multi-layered, zero-server-bandwidth upload system with this exact architecture. Do not take shortcuts — each numbered requirement below exists because a specific bypass or bug happens if it's skipped.

PHASE 1 — Client-side prep:
- Compress the file and strip EXIF/metadata client-side (off the main thread) before requesting an upload.

PHASE 2 — Request (server endpoint):
- Client sends fileName, fileSize, mimeType.
- Server validates these against a strict whitelist (e.g. max 10MB, only image/jpeg|png|webp|gif|avif) — reject anything else.
- Server inserts an "upload intent" DB row, status='pending'.
- Server generates a RANDOM object key (e.g. 7+ url-safe chars) — never a deterministic name like {userId}.jpg, since that causes CDNs to keep serving the stale cached file after every re-upload.
- Server generates a presigned PUT URL that cryptographically locks Content-Type and Content-Length to the validated values.
- Server returns the presigned URL + intent ID.

PHASE 3 — Direct upload:
- Client PUTs the file straight to storage using the presigned URL. Server touches zero file bytes.

PHASE 4 — Confirm (server endpoint):
- Server does a HeadObject call on storage and verifies the real size/type match the intent record exactly. Mismatch → delete the object, mark intent 'failed', reject.
- Server fetches ONLY the first 16 bytes via an HTTP Range request and checks the file's magic-byte signature against the declared type (e.g. JPEG must start FF D8 FF) — this catches a renamed .exe that passed the Content-Type check. Mismatch → delete object, log it, reject.
- Server fetches the user's CURRENT file URL from the DB, but does not delete it yet.
- Only after both checks pass: delete the old storage object, update the DB to point at the new file, mark the intent 'completed'.
- Return the new file's public URL.

REQUIRED — cleanup job:
- A scheduled job that finds intents still 'pending' after ~5 minutes and deletes the orphaned storage objects (handles browser-closed-mid-upload cases).

Non-negotiable rules:
- Never trust the client's claim that "the upload succeeded" — always independently re-verify via HeadObject + magic bytes.
- Never delete the old file before the new one is fully verified.
- Never use a deterministic object key.
- All size/type validation must happen server-side, not just in the UI.

Before showing me the finished code, verify against this checklist and tell me if anything can't be checked:
- [ ] Object keys are random, not deterministic
- [ ] Presigned URL locks both Content-Type and Content-Length
- [ ] Confirm endpoint does HeadObject verification
- [ ] Confirm endpoint does magic-byte inspection via Range request
- [ ] Old file deleted only after new file passes all checks
- [ ] Intent-tracking table with pending/completed/failed/expired states
- [ ] Cleanup job for abandoned pending intents
- [ ] Size/MIME whitelist enforced server-side
- [ ] EXIF stripped client-side

Start by giving me an implementation plan (API routes, DB schema changes, client components) for my specific stack before writing code.
```
