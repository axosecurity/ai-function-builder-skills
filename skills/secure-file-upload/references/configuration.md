# Storage Provider Configuration Guide

Use this to walk a user through console setup when they need to create/configure the bucket. Cloudflare R2 is recommended by default (zero egress fees — matters a lot for image/file-heavy apps), but AWS S3 works identically at the API level.

## Required environment variables (either provider)

```env
STORAGE_ACCOUNT_ID=          # R2 account ID, or leave blank for AWS
STORAGE_ACCESS_KEY_ID=
STORAGE_SECRET_ACCESS_KEY=
STORAGE_BUCKET_NAME=
STORAGE_PUBLIC_URL=          # https://pub-xxxxx.r2.dev  or your CDN/CloudFront domain
```

## Cloudflare R2 setup

1. **Create a bucket**: Cloudflare Dashboard → R2 → Create bucket → name it → location `Automatic`.
2. **Get the Account ID**: shown in the R2 dashboard sidebar under "Account Details".
3. **Generate API tokens**: R2 dashboard → "Manage R2 API Tokens" → Create API token → Permissions: **Object Read & Write** → scope to the bucket if desired. Copy the Access Key ID and Secret Access Key immediately — the secret is shown only once.
4. **Enable public access**: bucket → Settings → Public Access → "R2.dev subdomain" → Allow Access. This gives you `STORAGE_PUBLIC_URL`.
5. **Configure CORS** (required — the browser uploads directly to the bucket, so it needs cross-origin permission):

```json
[
  {
    "AllowedOrigins": ["http://localhost:3000", "https://your-production-domain.com"],
    "AllowedMethods": ["GET", "PUT", "HEAD"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3000
  }
]
```
Remind the user to replace the origins with their real domain(s) before shipping.

## AWS S3 setup

Same shape, different console:
- Bucket = `STORAGE_BUCKET_NAME`
- IAM user Access Key / Secret Key = `STORAGE_ACCESS_KEY_ID` / `STORAGE_SECRET_ACCESS_KEY`
- No account-ID concept — S3 uses regions. Point the SDK's endpoint at `https://s3.<region>.amazonaws.com` instead of R2's account-scoped endpoint.

CORS policy (S3 console → bucket → Permissions → CORS):
```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "PUT", "HEAD"],
    "AllowedOrigins": ["*"]
  }
]
```
Tighten `AllowedOrigins` to the real domain before production — `"*"` is fine for local dev only.

## Other providers (Supabase Storage, Firebase Storage, Azure Blob, GCS)

All support signed/presigned URLs with the same core guarantees (Content-Type/Length locking, HeadObject-equivalent metadata fetch, byte-range reads). The SDK call names differ but the 5-layer security model in `security-model.md` applies unchanged — swap in the provider's SDK methods for: generate signed PUT URL, get object metadata, and ranged GET.
