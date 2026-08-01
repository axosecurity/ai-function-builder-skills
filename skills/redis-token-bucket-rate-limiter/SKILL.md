---
name: redis-token-bucket-rate-limiter
description: Implements a production-grade, race-condition-free token bucket rate limiter backed by Redis (optimized for Upstash Redis) using an atomic Lua script. Use this skill whenever the user asks to add rate limiting, throttling, or request-quota enforcement to an API, endpoint, or backend service — especially if Redis or Upstash is mentioned, or if they mention "token bucket", "429 Too Many Requests", "abuse prevention", or "brute-force protection". Also trigger this proactively when reviewing or building auth/payment/public API endpoints that lack rate limiting. Always follow the interview-first workflow below rather than guessing rate limits or identification strategy.
---

# Redis Token Bucket Rate Limiter

Implements a safe, atomic, distributed rate limiter using Redis's token bucket algorithm. Designed for Node.js/TypeScript backends and optimized for Upstash Redis, but the Lua script itself is Redis-client-agnostic.

## Workflow

### Phase 1 — Information Gathering (do not write code yet)

Before writing any implementation, ask the user (use `ask_user_input_v0` if available, otherwise ask inline):

1. **User identification**: How should unique clients be identified for the per-user bucket? Options: `Authorization`/JWT payload (preferred, secure), `x-user-id` header (only if trusted/internal), or fallback to IP address (`req.ip`).
2. **Global limit**: Do they also want a shared **Global** bucket for the whole endpoint, independent of who's calling?
3. **Rates**: What's the burst capacity (max tokens in the bucket) and the steady refill rate (tokens per minute)?
4. **Failure mode**: For sensitive endpoints (payments, auth, admin actions) ask explicitly whether to **Fail Open** (allow requests through if Redis is unreachable) or **Fail Closed** (block requests if Redis is unreachable). Default to Fail Open for everything else, but always ask for sensitive endpoints — don't assume.

Do not proceed to implementation until these are answered. If the user has clearly already answered some of this earlier in the conversation, don't re-ask — just confirm your understanding and proceed.

### Phase 2 — Implementation Rules (non-negotiable)

#### Rule 1: Use this exact Lua script

This performs the refill calculation, limit check, and token deduction as a single atomic operation (avoids race conditions across concurrent requests). Save it as a constant in the codebase (e.g. `lib/rate-limit/token-bucket.lua.ts` or embedded as a template string):

```lua
local key = KEYS[1]
local capacity = tonumber(ARGV[1])
local refill_rate = tonumber(ARGV[2])
local now = tonumber(ARGV[3])
local requested = tonumber(ARGV[4])

-- Get current bucket state
local bucket_state = redis.call("HMGET", key, "tokens", "last_refill_time")
local tokens = tonumber(bucket_state[1])
local last_refill_time = tonumber(bucket_state[2])

if tokens == nil then
    -- Bucket doesn't exist, initialize it
    tokens = capacity
    last_refill_time = now
else
    -- Refill bucket based on time passed
    local time_passed = math.max(0, now - last_refill_time)
    local tokens_to_add = math.floor(time_passed * refill_rate)

    if tokens_to_add > 0 then
        tokens = math.min(capacity, tokens + tokens_to_add)
        last_refill_time = now
    end
end

local allowed = 0
if tokens >= requested then
    tokens = tokens - requested
    allowed = 1
end

-- Save updated state
redis.call("HMSET", key, "tokens", tokens, "last_refill_time", last_refill_time)
-- Set an expiration so unused keys are eventually removed
local ttl = math.ceil(capacity / refill_rate) * 2
redis.call("EXPIRE", key, ttl)

return { allowed, tokens }
```

#### Rule 2: Pass arguments correctly

- `KEYS[1]`: unique bucket identifier, e.g. `rate_limit:user:123` or `rate_limit:global:my_endpoint`.
- `ARGV[1]` capacity: integer, max burst size.
- `ARGV[2]` refill_rate: **tokens per second**, as a float. If the user gives requests-per-minute, convert: `rate_per_minute / 60`. Never pass the per-minute number directly.
- `ARGV[3]` now: current time in **seconds** (`Math.floor(Date.now() / 1000)` in JS), not milliseconds.
- `ARGV[4]` requested: normally `1` per API request, unless the user wants variable request "weights".

#### Rule 3: Fail Open (or Fail Closed) architecture

Wrap the Redis call in try/catch:
- **Fail Open** (default): on Redis error, log it and let the request proceed.
- **Fail Closed** (sensitive endpoints, if the user chose this in Phase 1): on Redis error, block the request and return an error response — explain to the user that this trades availability for stricter security, and confirm that's what they want before implementing it.

#### Rule 4: Standardized HTTP headers

On allowed requests (including fail-open passthroughs), set:
- `X-RateLimit-Limit`: the bucket capacity.
- `X-RateLimit-Remaining`: the `tokens` value returned by the script.

On blocked requests (`allowed === 0`): return **HTTP 429 Too Many Requests** with a JSON error body, and short-circuit — do not execute the rest of the endpoint handler.

#### Rule 5: Security & bypass prevention

- **Never trust raw client-supplied headers** (like `x-user-id`) for identity in production — they're trivially spoofable and let an attacker reset their own bucket. Extract identity from a verified JWT/session instead.
- **IP-based fallback is weak**: if unauthenticated traffic falls back to IP, explicitly tell the user that VPNs/proxy rotation can bypass it, and recommend pairing it with a Global limit as a second line of defense.
- **Fail-open abuse**: for sensitive endpoints, remind the user that Fail Open means an attacker who can DDoS or disconnect Redis can bypass the limiter entirely — this is why Phase 1 asks about Fail Closed for those cases.

### Phase 3 — Self-check before presenting code

Before showing the final implementation, verify:
- [ ] Lua script matches Rule 1 exactly and is stored as a constant.
- [ ] `now` is computed in seconds, not milliseconds.
- [ ] `refill_rate` math is correct for the timeframe the user specified (per-minute → divide by 60, per-hour → divide by 3600, etc.).
- [ ] try/catch present around the Redis call, implementing the failure mode chosen in Phase 1.
- [ ] Response headers and 429 handling match Rule 4.
- [ ] Identity extraction follows Rule 5 (no raw spoofable headers for production auth).

Only after all checks pass, output the full implementation for the user's framework/language (adapt the surrounding glue code to their stack — e.g. Express middleware, Next.js middleware/route handler, Fastify plugin — but never alter the Lua script itself).

## Notes

- This is optimized for Upstash Redis (works over REST/serverless-friendly clients) but the Lua script works with any Redis-compatible client that supports `EVAL`/`EVALSHA` (ioredis, node-redis, etc.).
- If the user's stack doesn't have an obvious place for "middleware," ask where they'd like the check inserted (e.g. at the top of a route handler, in an edge middleware file) rather than guessing.
