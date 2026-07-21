### Product of NULogic
<div align="center">
        <h1> BookShare </h1>
        <h3>APP UNDER DEVELOPMENT ~ INTENDED FOR IOS</h3>
</div>

<div align="center">

![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-A8431F)
![Swift](https://img.shields.io/badge/Swift-6.0-A8431F)
![UI](https://img.shields.io/badge/UI-SwiftUI-A8431F)
![Backend](https://img.shields.io/badge/backend-Supabase-A8431F)
![Status](https://img.shields.io/badge/status-pre--MVP-C9973C)

</div>

---

## What it is

BookShare is a neighborhood book-lending app. It makes the books already sitting on your street searchable, and it handles the awkward parts of lending to someone you don't know yet — the asking, the reminding, the "where should we meet."

Millions of household books sit idle while nearby demand goes unmet. Every existing channel fails at a different layer: neighborhood social apps have the neighbors but no inventory or accountability, mail-swap sites have the mechanics but lose the neighborhood, Little Free Libraries have the charm but are unsearchable, and libraries have the books but twelve-week waitlists.

The core wager: **strangers will lend property to strangers if — and only if — the product manufactures trust from zero.** That reframes what this is. BookShare isn't a browsing app with a lending feature. It's a trust machine with a book-shaped interface.

---

## Core features (MVP)

| | Feature | Requirement |
|---|---|---|
| 📚 | Scan an ISBN, list a book in under a minute | BR-01 |
| ✅ | Phone verification required; optional ID check earns a **Verified Neighbor** badge | BR-02 |
| 📍 | Browse books near you — filter by radius, genre, availability | BR-03 |
| 🔄 | Full loan lifecycle: request → accept → handoff → return, with automatic reminders | BR-04 |
| 🔒 | Jittered map pins — exact addresses are **never** shown to other users | BR-05 |
| ⭐ | Two-sided reliability ratings; completed loans raise your borrow limit | BR-06 |
| 🏠 | Little Free Libraries mapped as public inventory nodes | BR-07 |
| 🔔 | Wishlist alerts when a wanted title is listed nearby | BR-08 |
| 👋 | Invite-your-block referrals with QR codes | BR-09 |

No payments at MVP. Trust comes from reputation mechanics, not deposits.

---

## Tech stack

| Layer | Choice |
|---|---|
| **UI framework** | SwiftUI (iOS 17+) |
| **Language** | Swift 6.0 |
| **IDE** | Xcode 16 |
| **State** | Observation framework (`@Observable`) + MVVM |
| **Backend** | Supabase — Postgres, Auth, Storage, Realtime, Edge Functions |
| **Database** | Supabase Postgres + PostGIS |
| **File storage** | Supabase Storage buckets |
| **SDK** | `supabase-swift` |
| **Barcode scanning** | VisionKit `DataScannerViewController` |
| **Maps** | MapKit |
| **Push** | APNs directly (see [scheduling](#push-notifications)) |
| **Design** | Figma → design tokens → generated Swift → Xcode Previews |
| **CI/CD** | Xcode Cloud or GitHub Actions + Fastlane |

### Why native

The BRD specifies an iOS **and** Android MVP. Going SwiftUI means iOS ships first and Android becomes a second codebase later — a deliberate tradeoff, and one worth restating plainly, because this is a **density product**. A block is not iOS-only. Liquidity on a street depends on the neighbors who live there, not on their phone brand, so plan Android as a fast follow rather than an eventual maybe. What native buys in exchange:

- **VisionKit** for ISBN scanning — better capture rates than any cross-platform wrapper, and BR-01 lives or dies on that flow feeling instant.
- **MapKit** for jittered pins and LFL nodes — no key management, no per-tile billing.
- **Dynamic Type, VoiceOver, and Reduce Motion for free**, which matters because the accessibility floor for this product is Alma, the 58-year-old block captain whose patience burns out on small type.
- **One language end to end** — Swift in the app, Swift SDK against Supabase.
- **Simpler push** — APNs directly, no FCM bridge.

---

## Architecture

```
┌─────────────────────────────────────────────┐
│  SwiftUI (iOS 17+)                          │
│  @Observable view models · NavigationStack  │
│  MapKit · VisionKit · Swift Concurrency     │
└──────────────┬──────────────────────────────┘
               │ supabase-swift (HTTPS / WebSocket)
┌──────────────▼──────────────────────────────┐
│  Supabase                                   │
│  ├─ Postgres + PostGIS  (radius queries)    │
│  ├─ Row Level Security  (privacy, limits)   │
│  ├─ Auth                (phone OTP, Apple)  │
│  ├─ Storage buckets     (covers, photos)    │
│  ├─ Realtime            (chat, loan state)  │
│  └─ Edge Functions      (rules, matching)   │
└──────────────┬──────────────────────────────┘
               │ pg_cron → Edge Function
┌──────────────▼──────────────────────────────┐
│  APNs — due-date reminders, wishlist alerts │
└─────────────────────────────────────────────┘
```

### Why Supabase

BookShare is a proximity-and-trust product, and both of those live in the data layer:

- **Radius search wants PostGIS.** `ST_DWithin` on a geography column, not client-side filtering.
- **The privacy model wants Row Level Security.** Exact coordinates live in a protected column; a public view exposes approximate distance only. Jitter is computed server-side, so true location never leaves the database.
- **Borrow limits and strike enforcement want rules the client can't bypass.** RLS policies, not app logic.

Managed auth, storage, and realtime keep a small team from operating that infrastructure by hand.

---

## Project structure

```
BookShare/
├── App/
│   ├── BookShareApp.swift        # @main, scene setup, deep links
│   └── AppEnvironment.swift      # dependency container
├── Features/                     # mirrors the information architecture
│   ├── Onboarding/               # account → phone verify → address → radius
│   ├── Discover/                 # geo feed, filters, map, book detail
│   ├── Shelf/                    # my books, ISBN scan, wishlist
│   ├── Home/                     # requests, active loans, chat
│   ├── Loans/                    # lifecycle, handoff, return, rating
│   └── Profile/                  # score, verification, privacy, invites
│       └── {Views, ViewModels, Models}/
├── DesignSystem/                 # coded twin of the Figma library
│   ├── Tokens.generated.swift    # generated from tokens.json — do not edit
│   ├── Typography.swift
│   └── Components/               # BSButton, BSBookCard, BSStatusBadge, ...
├── Core/
│   ├── Supabase/                 # client, repositories, DTOs
│   ├── Location/                 # CoreLocation wrapper, permission flow
│   ├── Scanning/                 # VisionKit ISBN capture
│   └── Notifications/            # APNs registration, categories
└── Resources/                    # Assets.xcassets, fonts, Info.plist

BookShareTests/                   # unit + snapshot
BookShareUITests/                 # XCUITest — task flow E2E
supabase/
├── migrations/                   # versioned schema + RLS policies
└── functions/                    # Edge Functions (Deno / TypeScript)
design/
└── tokens.json                   # exported from Figma Variables
```

---

## Getting started

### Prerequisites

- Xcode 16+ (iOS 17 SDK)
- macOS Sonoma or later
- Supabase CLI
- A Supabase project (free tier is fine for local dev)
- A physical device for barcode scanning — the simulator has no camera

### Setup

```bash
# 1. Clone
git clone https://github.com/NULogic/bookshare.git
cd bookshare

# 2. Environment — copy the template and fill in your keys
cp .env.example Config/Secrets.xcconfig

# 3. Apply the database schema to your Supabase project
supabase link --project-ref <your-project-ref>
supabase db push

# 4. Open and run
open BookShare.xcodeproj
```

Swift Package Manager resolves dependencies on first build:

| Package | Role |
|---|---|
| `supabase-swift` | Auth, Postgres, Storage, Realtime |
| `swift-snapshot-testing` | Design system regression tests |

### Configuration

`Config/Secrets.xcconfig` — referenced from `Info.plist`, never committed:

```
SUPABASE_URL = https:/$()/<project-ref>.supabase.co
SUPABASE_ANON_KEY = <anon-key>
```

> ⚠️ Never commit `Secrets.xcconfig` or the Supabase **service role** key. The anon key is safe on-device only because Row Level Security is doing the real work — treat RLS policies as production security code, not configuration.

Two `Info.plist` strings carry real design weight — reuse the tested onboarding copy verbatim:

```
NSLocationWhenInUseUsageDescription
  We use your location to find books nearby. Your exact address is never shown to other users.
NSCameraUsageDescription
  Scan a book's barcode and we'll fill in the rest.
```

---

## Design system

The design language lives in **Figma** and code inherits it. No hex value should ever appear in a feature view.

```
Figma Variables → tokens.json → Tokens.generated.swift + Assets.xcassets
                                              ↓
                         SwiftUI component library (DesignSystem/)
                                              ↓
                    Xcode Previews + snapshot tests → screens
```

A build-phase script regenerates tokens on change, so a designer's Figma edit lands as a reviewable diff rather than a Slack message.

**Palette** — warm library paper, one terracotta accent that carries every primary action and never decorates.

| Token | Hex | Use |
|---|---|---|
| `paper` | `#F4EFE4` | App background |
| `card` | `#FBF7EE` | Cards, sheets, tab bar |
| `field` | `#EBE3CF` | Inputs, secondary buttons |
| `ink` | `#221812` | Primary text |
| `muted` | `#6F6152` | Secondary text, metadata |
| `rust` | `#A8431F` | Primary actions, links, active tab |
| `sage` | `#E4E8D5` / `#55663F` | Positive status — Available, Verified |
| `gilt` | `#C9973C` | Rating stars — never buttons |

**Type** — three faces, three jobs. Lora (serif) is the voice: screen titles and book titles only. DM Sans is the interface. IBM Plex Mono marks data — distances, dates, counts.

Register custom fonts as **scaled** text styles (`Font.custom(_:size:relativeTo:)`) so Dynamic Type keeps working. Components must survive 135% text size before truncating — that's the Alma bar, and it's a review requirement, not a nice-to-have.

Every component ships with an Xcode Preview covering its states, light/dark, and largest Dynamic Type size. Previews are the living gallery; snapshot tests are the guardrail.

---

## Status vocabulary

Four words, one meaning each, used identically on Discover badges, the Home queue, and the loan stepper. Learned once. Model it as a single `enum LoanStatus` so the compiler enforces it.

| Status | Meaning |
|---|---|
| `available` | Listed and free to request |
| `requested` | Request pending — 48-hour response window running |
| `accepted` | Lender said yes; handoff being planned in chat |
| `onLoan` | Handoff confirmed by both; due date running |
| `returned` | Lender confirmed return; ratings triggered |

Do not introduce new status words. "Borrowed" was retired in usability testing — it read as first-person.

---

## Voice

The product's deepest job is to absorb the awkwardness. Every current workaround for borrowing a book from a neighbor fails at the social layer, not the logistical one — so:

- **The app is the nag.** *"We'll nudge you 3 days before it's due — no one has to be the nag."* Reminders, norms, and asks come from the product's voice.
- **Never transactional.** No "items," "inventory," "users," or "transactions" in user-facing copy. Books, neighbors, shelves, loans.
- **Privacy promises appear where the risk is felt**, in plain sentences, every time — not buried in a settings page.

---

## Testing

```bash
xcodebuild test -scheme BookShare -destination 'platform=iOS Simulator,name=iPhone 16'
supabase test db          # pgTAP — RLS policy tests
```

- **Unit** — Swift Testing for view models, distance math, and loan state transitions.
- **Snapshot** — every design system component, light/dark, default and largest Dynamic Type.
- **UI (XCUITest)** — scripted directly from the five task flows: onboard, list a book, find and request, coordinate handoff, return and rate. The usability test scripts double as E2E specs.
- **pgTAP** — RLS policies get their own suite. Privacy rules here are load-bearing; if a policy regresses, exact addresses leak.

---

## Known gaps

### Push notifications

Supabase does not send mobile push. `pg_cron` schedules the reminder cadence (3 days before due, day of) and the 48-hour request expiry sweep, but an Edge Function still has to sign a JWT and call **APNs** to deliver them.

Going iOS-only simplifies this considerably — one provider, no FCM bridge — but it is still a piece you build, not a checkbox you tick. Budget for it early: the reminder system is what lets the app be the nag, which is the entire trust proposition.

### Android

Not in this codebase. The BRD scopes an iOS + Android MVP, so plan the second platform explicitly — a Kotlin/Compose codebase against the same Supabase backend is the honest path. Keep all business rules in Postgres and Edge Functions so the second client stays thin.

### Also deferred

- Dispute and strike-enforcement surfaces (the unhappy paths)
- Book clubs (BR-10) — the retention hedge against novelty decay
- Affiliate links (BR-11)

---

## Roadmap

- [x] BRD, personas, journey maps, IA
- [x] User flows, task flows, wireframes
- [x] High-fidelity UI + design system
- [x] Interactive prototype
- [ ] Usability study — 6 participants, moderated
- [ ] Supabase schema + RLS policies
- [ ] SwiftUI design system + Previews
- [ ] Onboarding + Discover
- [ ] Loan lifecycle + chat
- [ ] ISBN scan pipeline (VisionKit)
- [ ] TestFlight beta — seed neighborhoods
- [ ] Public launch — 3 metros
- [ ] Android client

**Growth note:** density is the product. Fifty users spread across a city is worthless; fifty users within a mile is magical. Beta cohorts map to TestFlight groups, one per neighborhood — growth is block-by-block, not city-wide. Which is also the strongest argument for not letting the Android gap run long.

---

## Contributing

1. Branch from `main` — `feature/…`, `fix/…`, `chore/…`
2. Build clean with no warnings; tests and snapshots must pass before opening a PR
3. Schema changes go in `supabase/migrations/` — never edit the remote database by hand
4. Design changes start in Figma, flow through `tokens.json`, and land as a reviewable diff
5. Never edit `Tokens.generated.swift` by hand
6. Any change touching location, verification, or RLS needs a second reviewer

---

## License

Proprietary — © NULogic. All rights reserved.

<div align="center">
<sub>Built to make the books three blocks away visible.</sub>
</div>
