# BookShare — Backend Setup (Phase 1)

Phase 1 stands up **auth** (email/password + reset, phone OTP, Apple/Google OAuth),
**location**, and **radius search** on a local Supabase stack. This doc covers running
it locally and the one-time provider setup for the parts that need external accounts.

Stack: native **SwiftUI** + **supabase-swift** (2.54.0) → **Supabase** (Postgres 17 + PostGIS,
Auth, RLS). This deliberately diverges from Deliverable 17's Flutter recommendation; the
backend half of Del.17 is unchanged.

---

## 1. Prerequisites

- **Xcode 16.4+**, iOS 18.5 simulator.
- **Docker Desktop** running (the local Supabase stack runs in Docker).
- **Supabase CLI** — installed at `~/.local/bin/supabase` (v2.110.0). Add to PATH:
  ```bash
  export PATH="$HOME/.local/bin:$PATH"
  ```

## 2. Run the local backend

```bash
cd /Users/srijan/Documents/BookShare
supabase start           # boots Postgres+PostGIS, Auth, Storage, Mailpit (first run pulls images)
```

Apply the schema + seed. **Note:** Supabase CLI 2.110.0 has a bug where `supabase db reset`
fails with `LegacyDbBootstrapError: Could not find the supabase-go binary`. Until it's fixed,
apply migrations directly (the DB container is `supabase_db_BookShare`):

```bash
docker exec -i supabase_db_BookShare psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/migrations/0001_init.sql
docker exec -i supabase_db_BookShare psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/seed.sql
```
(Or pin an older CLI, e.g. `supabase@2.109.x`, where `db reset` works normally.)

Useful local URLs:
- API: `http://127.0.0.1:54321`  ·  Studio: `http://127.0.0.1:54323`
- **Mailpit** (catches all dev emails — confirmations, password resets): `http://127.0.0.1:54324`

The app already points at this stack — see `BookShare/Backend/SupabaseConfig.swift`
(local dev URL + public anon key). The iOS Simulator reaches `127.0.0.1` directly.

## 3. Run the app

Open `BookShare.xcodeproj` in Xcode and Run, or from CLI:
```bash
xcodebuild -project BookShare.xcodeproj -scheme BookShare \
  -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug build
```

**What works fully on the local stack (no accounts needed):**
- Email sign-up / log in, and **Forgot password** (reset email lands in Mailpit).
- Location permission + one-shot fix → saved via `update_my_location`.
- Discover feed via the `books_near_me` PostGIS radius query.

Tip: set the simulator's location for the feed to populate around the seed origin —
Simulator ▸ Features ▸ Location ▸ Custom → `40.6862, -73.9959` (Cobble Hill), or:
```bash
xcrun simctl location "iPhone 16" set 40.6862,-73.9959
```

---

## 4. Provider setup (one-time, needs your accounts)

These flows are fully coded in the app but need an external provider switched on. Each maps
to a config block in `supabase/config.toml` that reads a secret from an env var.

### Apple — Sign in with Apple
1. Apple Developer ▸ Certificates, IDs & Profiles ▸ create a **Services ID** and a **Sign in with Apple key**.
2. Build the client secret (JWT) per Supabase's Apple guide.
3. In `config.toml` set `[auth.external.apple] enabled = true`, `client_id = "<your Services ID>"`,
   and export `SUPABASE_AUTH_EXTERNAL_APPLE_SECRET=<client secret>` before `supabase start`.
4. Redirect URL is already registered: `bookshare://auth-callback`.

### Google — OAuth
1. Google Cloud ▸ APIs & Services ▸ Credentials ▸ create an **OAuth 2.0 Client ID** (iOS + Web).
2. In `config.toml` set `[auth.external.google] enabled = true`, `client_id`, and export
   `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=<secret>`.

### Phone OTP / SMS — Twilio
Local note: the CLI disables phone login unless a real SMS provider is enabled (the
`[auth.sms.test_otp]` map alone isn't enough).
1. Create a **Twilio** account; note Account SID, Auth Token, and a Messaging Service SID.
2. In `config.toml` set `[auth.sms] enable_signup = true`, `[auth.sms.twilio] enabled = true`,
   `account_sid`, `message_service_sid`, and export `SUPABASE_AUTH_SMS_TWILIO_AUTH_TOKEN=<token>`.
3. Restart: `supabase stop && supabase start`.

After enabling any provider, the corresponding button in the app works with **no code change** —
the flows are already wired in `BookShare/Backend/AuthService.swift`.

---

## 5. Going to a hosted Supabase project (later)

1. Create a project at supabase.com; `supabase link --project-ref <ref>`; push migrations.
2. Swap `url` + `anonKey` in `SupabaseConfig.swift` for the project's values.
3. Configure the providers above in the hosted dashboard instead of `config.toml`.

## 6. What's NOT in Phase 1 (next phases)

Loans/ratings/wishlist tables & lifecycle, Edge Functions (Open Library ISBN lookup,
reminders/push), Storage buckets, and native (non-web) Sign in with Apple button.
