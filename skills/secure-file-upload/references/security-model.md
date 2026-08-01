# The 5-Layer Security Model

When a client uploads directly to your storage bucket, you must assume the client is fully adversarial — it can send arbitrary size/type claims, or hit your storage bucket with `curl` bypassing your UI entirely. Each layer below closes a specific bypass. Implement all five; skipping any one re-opens a known hole.

## Layer 1: Server-Side Input Validation

On the `/upload/request` endpoint, validate the client's claimed `fileName`, `fileSize`, and `mimeType` against a strict whitelist using whatever validation library is idiomatic to the stack (Zod/Yup in JS, Pydantic in Python, struct validation in Go, FormRequest in Laravel, etc.).

Example constraints for an avatar/image use case:
- Max size: 10MB
- Whitelist: `image/jpeg`, `image/png`, `image/webp`, `image/gif`, `image/avif`

**Never trust client-side validation alone** — it's UX, not security. A malicious client skips your form entirely and hits the API directly.

## Layer 2: Cryptographic Presigned-URL Signatures

When generating the presigned PUT URL, lock the `Content-Type` and `Content-Length` into the signed request itself:

```typescript
// AWS SDK v3 example — same idea applies to any S3-compatible SDK
const command = new PutObjectCommand({
  Bucket: process.env.BUCKET_NAME,
  Key: objectKey,
  ContentType: mimeType,     // validated value from Layer 1, not raw client input
  ContentLength: fileSize,   // validated value from Layer 1, not raw client input
});
const presignedUrl = await getSignedUrl(s3Client, command, { expiresIn: 300 });
```

If the client then tries to `PUT` a file with a different size or type than what was signed, the storage provider rejects the request at the edge — your server does zero work to stop this.

## Layer 3: HeadObject Metadata Verification

Even with a locked presigned URL, you must confirm the upload actually happened and matches expectations before trusting it. In `/upload/confirm`, query storage for the real object metadata:

```typescript
const head = await s3Client.send(new HeadObjectCommand({ Bucket, Key: objectKey }));
if (head.ContentLength !== intent.fileSize || head.ContentType !== intent.mimeType) {
  // delete the object, mark intent 'failed', reject
}
```

## Layer 4: Deep Magic-Byte Inspection

A client can rename `malware.exe` to `innocent.jpg` — the extension and even a spoofed `Content-Type` header won't catch this. Magic bytes (the file's actual binary signature) will.

Fetch *only* the first 16 bytes via an HTTP Range request — never download the whole file server-side, that would defeat the "zero bandwidth" property:

```typescript
const range = await s3Client.send(new GetObjectCommand({
  Bucket, Key: objectKey, Range: "bytes=0-15",
}));
const bytes = await streamToBuffer(range.Body);
const hex = bytes.toString("hex");
```

Common signatures to check against:

| Type | Magic bytes (hex prefix) |
|---|---|
| JPEG | `ffd8ff` |
| PNG | `89504e470d0a1a0a` |
| GIF | `474946383761` or `474946383961` |
| WEBP | `52494646....57454250` (RIFF....WEBP, check bytes 0-3 and 8-11) |
| PDF | `25504446` |
| ZIP-based (docx/xlsx/etc.) | `504b0304` |

If the magic bytes don't match the declared type, delete the object immediately and write an audit log entry — this is a strong signal of a malicious actor, not a bug in the client.

## Layer 5: Intent Tracking & Garbage Collection

Every upload starts as a `pending` row in an intent-tracking table (see `database-schema.md`). This is what makes cleanup possible: a scheduled job periodically finds `pending` intents older than ~5 minutes and deletes the corresponding orphaned storage objects, marking them `expired`. Without this table, you have no way to distinguish "upload in progress" from "abandoned upload" from "attacker requesting thousands of presigned URLs they never use" — and no way to clean any of them up.
