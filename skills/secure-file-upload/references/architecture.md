# Architecture & Flow

Full end-to-end lifecycle of a secure, direct-to-storage file upload.

```mermaid
sequenceDiagram
    participant C as Client (Browser/App)
    participant A as API (your server)
    participant D as Database
    participant S as Storage (S3 / R2 / etc.)

    Note over C: User selects file
    C->>C: Compress + strip EXIF (worker thread)

    Note over C, A: Phase 1: Request
    C->>A: POST /upload/request (fileSize, mimeType)
    A->>A: Validate input (whitelist size/type)
    A->>D: Insert UploadIntent (status: 'pending')
    A->>A: Generate random object key (e.g. avatars/xY7_a2B.jpg)
    A->>A: Generate presigned URL (locks Content-Length & Content-Type)
    A-->>C: Return presigned URL & intentId

    Note over C, S: Phase 2: Direct Upload
    C->>S: PUT directly to storage
    S-->>C: 200 OK (only if signature matches)

    Note over C, D: Phase 3: Confirmation & Atomic Swap
    C->>A: POST /upload/confirm (intentId)
    A->>S: HeadObject (get real metadata)
    A->>A: Validate size & mime match intent exactly
    A->>S: GetObject (Range: bytes=0-15)
    A->>A: Magic-byte verification
    A->>D: Fetch user's current file URL
    A->>S: DELETE old object (only now, if checks passed)
    A->>D: Update user's file URL
    A->>D: Update UploadIntent (status: 'completed')
    A-->>C: Return new file URL
```

## Pros

- **Zero server bandwidth**: file bytes never pass through your app server; storage handles the heavy lifting.
- **Cache-busting by default**: a random object key per upload means CDNs never serve a stale cached image after a new upload — no manual cache invalidation needed.
- **Atomic rollback safety**: the old file is only deleted after the new one is fully verified, so a failed/interrupted upload never leaves the user with a broken or missing file.
- **Hard to bypass security**: the presigned URL itself rejects wrong size/type at the storage edge, and the server does an independent second check afterward (magic bytes) — defense in depth, not just one layer.

## Cons / trade-offs to mention to the user

- **More round-trips**: 3 network calls (request → PUT → confirm) instead of one simple form POST. Worth it for anything beyond a toy project; probably overkill for a quick internal admin tool with 2 users.
- **Orphaned files edge case**: if the client uploads to storage but never calls `/confirm` (tab closed, network drop), the object sits unclaimed. This is why the cleanup job (Layer 5 in the security model, see `security-model.md`) is not optional — skipping it means storage cost creeps up silently over time.
