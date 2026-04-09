# GastoTrack

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Convex](https://img.shields.io/badge/Convex-Backend-2D2D2D?logo=convex)](https://convex.dev)
[![Riverpod](https://img.shields.io/badge/State%20Management-Riverpod-4285F4)](https://riverpod.dev)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

A full-featured expense tracking application with multi-wallet support, group bill splitting, and offline-first synchronization. Built for individuals and groups who want a reliable, real-time view of their finances across multiple payment methods.

## Features

### Core

- **Transaction Tracking** — Log income and expenses with amount, category, payment method, description, and date
- **Payment Methods** — Every transaction is tagged as Cash, E-Wallet, or Bank via a segmented selector
- **Smart Categories** — 10 built-in categories (Food, Transport, Shopping, Entertainment, Bills, Health, Education, Home, Savings, Other) with color-coded icons

### Wallets

- **Multi-Wallet Dashboard** — Dedicated tab displaying live Cash, E-Wallet, and Bank balances computed from transactions
- **Atomic Transfers** — Move money between wallets via a single server-side mutation that creates both the debit and credit in one Convex transaction, eliminating partial-failure orphan records
- **Balance Card** — Home screen summary showing all three wallet balances at a glance

### Group Expenses

- **Group Management** — Create groups, share 6-character invite codes, join existing groups
- **Settlement Algorithm** — Automated equal-split debt calculation with optimized payment paths
- **Group Transactions** — Tag expenses to a group for shared tracking

### Analytics

- **Spending by Category** — Interactive pie chart with percentage breakdowns
- **Daily Spending** — Bar chart showing spending patterns across the month
- **Category Breakdown** — Sorted list with amount and percentage per category

### Infrastructure

- **Authentication** — Email/password sign-up and sign-in via Better Auth with JWT session persistence, profile editing with image upload, and password changes
- **Offline-First** — All writes go to Hive local cache first, then sync to Convex. Reads serve from cache immediately. Safe cache pruning preserves local-only records during sync
- **Cloud Sync** — Auto-sync triggered by connectivity changes and a 5-minute periodic timer. Failed mutations are queued with up to 5 retries and last-write-wins conflict resolution
- **Multi-Currency** — 12 currencies supported (PHP, USD, EUR, GBP, JPY, KRW, CNY, INR, AUD, CAD, SGD, AED) with persistent user preference
- **Budget Alerts** — Local notifications fired at 80% and 100% of per-category budget thresholds
- **Material 3 Theming** — Light and dark modes following Material Design 3 guidelines

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter 3.10+ |
| State Management | Riverpod |
| Backend | Convex |
| Authentication | Better Auth (`@convex-dev/better-auth`) |
| Local Storage | Hive + Hive Flutter |
| Charts | fl_chart |
| Routing | GoRouter |
| Notifications | flutter_local_notifications |
| Connectivity | connectivity_plus |
| HTTP | http (Convex REST API) |

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Flutter App  │────>│  Convex API  │────>│  Convex DB   │
│  (Riverpod)  │     │  (REST HTTP) │     │  (Real-time) │
└──────┬──────┘     └──────────────┘     └─────────────┘
       │
       v
┌──────────────┐
│  Hive Cache   │
│  (Offline)    │
└──────────────┘
```

- **Offline-first**: All writes go to Hive first, then sync to Convex. Reads serve from cache immediately.
- **Auth flow**: Better Auth REST endpoints (`/api/auth/sign-up/email`, `/api/auth/sign-in/email`, `/api/auth/get-session`) called via `http` package. Session cookie and Convex JWT extracted from response headers and stored in Hive.
- **Sync**: Connectivity monitoring triggers sync on reconnect. Periodic sync every 5 minutes. Failed mutations queued with max 5 retries. Safe cache pruning ensures offline-only records are never deleted during pull.
- **Server auth**: All Convex mutations verify the authenticated user via `authComponent.getAuthUser(ctx)` — no client-provided userId is trusted.

## Project Structure

```
lib/
├── main.dart                              # App entry, Hive + notification init
├── app.dart                               # MaterialApp.router with themes
├── core/
│   ├── config/
│   │   └── env.dart                       # Convex API & site URLs
│   ├── constants/
│   │   ├── app_colors.dart
│   │   ├── app_sizes.dart
│   │   ├── app_strings.dart
│   │   └── constants.dart                 # Barrel export
│   ├── router/
│   │   ├── app_router.dart                # GoRouter + auth redirect + 5-tab ShellRoute
│   │   └── router.dart                    # Re-export
│   ├── services/
│   │   ├── convex_service.dart            # Convex HTTP client + Better Auth REST
│   │   ├── local_cache_service.dart       # Hive boxes (transactions, groups, budgets, wallets, settings, pending_mutations)
│   │   ├── sync_service.dart              # Connectivity monitor, pull/push, retry queue, safe prune
│   │   ├── currency_service.dart          # Currency selection + formatCurrency()
│   │   └── notification_service.dart      # Budget threshold alerts
│   └── theme/
│       ├── app_theme.dart                 # Light/dark ThemeData
│       └── theme.dart                     # Re-export
├── features/
│   ├── auth/
│   │   ├── domain/user.dart               # User model with image + SubscriptionStatus
│   │   ├── data/auth_repository.dart      # AuthNotifier (Better Auth HTTP)
│   │   └── presentation/auth_page.dart    # Sign-up / sign-in
│   ├── transactions/
│   │   ├── domain/
│   │   │   ├── transaction.dart           # Transaction model + TransactionType + PaymentMethod
│   │   │   ├── category.dart              # Category model
│   │   │   └── domain.dart               # Barrel export
│   │   ├── data/
│   │   │   ├── transaction_repository.dart # TransactionNotifier + balance providers
│   │   │   └── budget_service.dart        # BudgetNotifier + BudgetAlertService
│   │   └── presentation/
│   │       ├── home_page.dart             # BalanceCard + transaction list + pull-to-refresh
│   │       └── add_transaction_page.dart  # Type + category + payment method form
│   ├── analytics/
│   │   └── presentation/
│   │       └── analytics_page.dart        # Pie/bar charts + category breakdown
│   ├── groups/
│   │   ├── domain/group.dart              # Group model
│   │   └── presentation/
│   │       ├── groups_page.dart           # GroupNotifier + create/join dialogs
│   │       └── group_detail_page.dart     # Settlement algorithm + member list
│   ├── wallets/
│   │   ├── domain/
│   │   │   ├── wallet.dart                # Wallet model
│   │   │   └── domain.dart               # Barrel export
│   │   ├── data/wallet_repository.dart     # WalletNotifier
│   │   └── presentation/
│   │       └── wallets_page.dart          # Wallet cards + atomic transfer dialog
│   └── settings/
│       └── presentation/
│           ├── settings_page.dart          # Currency picker + preferences
│           └── profile_page.dart           # Edit profile, image upload, change password, sign out
└── shared/
    └── widgets/
        ├── balance_card.dart               # 3-column wallet balance summary
        ├── transaction_list_item.dart       # Category icon + payment method label
        └── widgets.dart                     # Barrel export

convex/
├── package.json
├── .env.local                              # BETTER_AUTH_SECRET, CONVEX_DEPLOYMENT, CONVEX_SITE_URL
├── convex/
│   ├── convex.config.ts                    # App definition with betterAuth component
│   ├── schema.ts                           # Database schema (8 tables)
│   ├── auth.config.ts                      # getAuthConfigProvider() for JWT validation
│   ├── auth.ts                             # getCurrentUser, getUserProfile, updateProfile
│   ├── http.ts                             # HTTP route registration (Better Auth endpoints + CORS)
│   ├── transactions.ts                     # CRUD + atomic transfer mutation (auth-protected)
│   ├── categories.ts                       # Category CRUD (auth-protected)
│   ├── groups.ts                           # Group CRUD + join/leave (auth-protected)
│   ├── budgets.ts                          # Budget CRUD (auth-protected)
│   ├── wallets.ts                          # Wallet queries (legacy, balances computed from transactions)
│   ├── users.ts                            # Subscription update
│   ├── betterAuth/
│   │   └── schema.ts                       # Extends user table with subscriptionStatus
│   └── _generated/                         # Auto-generated by Convex CLI
```

## Getting Started

### Prerequisites

- Flutter SDK 3.10+
- Node.js 18+
- Convex account at [convex.dev](https://convex.dev)

### Installation

1. **Clone and install Flutter dependencies:**

   ```bash
   git clone https://github.com/your-username/GastoTrack.git
   cd GastoTrack
   flutter pub get
   ```

2. **Set up the Convex backend:**

   ```bash
   cd convex
   npm install
   npx convex dev
   ```

3. **Configure environment variables:**

   ```bash
   npx convex env set BETTER_AUTH_SECRET <your-secret>
   npx convex env set CONVEX_SITE_URL <your-convex-site-url>
   ```

4. **Run the app:**

   ```bash
   cd ..
   flutter run
   ```

### Environment Variables

| Variable | Description | Where |
|----------|-------------|-------|
| `BETTER_AUTH_SECRET` | Secret key for Better Auth session encryption | Convex env |
| `CONVEX_SITE_URL` | Convex site URL (e.g. `https://your-project.convex.site`) | Convex env |
| `CONVEX_DEPLOYMENT` | Deployment identifier (auto-set by `npx convex dev`) | `.env.local` |

## Database Schema

| Table | Purpose |
|-------|---------|
| `transactions` | Income and expenses with category, payment method, group, and date |
| `categories` | Default and custom spending categories |
| `groups` | Shared expense groups with invite codes |
| `groupMembers` | Group membership tracking |
| `settlements` | Group settlement records |
| `budgets` | Per-category budget limits with weekly or monthly periods |
| `recurringRules` | Recurring expense rules |
| `wallets` | Wallet type definitions (balances computed from transactions) |
| `user` | Managed by Better Auth (email, name, image, subscription status) |
| `session` | Managed by Better Auth |

### Key Design Decisions

- **Balances are computed, not stored** — Wallet balances are derived by aggregating transactions per payment method, avoiding dual-write consistency issues
- **Atomic transfers** — The `transactions:transfer` Convex mutation creates both the source debit and target income in a single database transaction
- **Safe cache pruning** — Sync pull operations only delete cached records that have been confirmed synced (contain a `convexId`), preserving offline-only records
- **Hive-safe type casts** — All numeric fields use `(value as num).toInt()` to handle Hive's occasional int-to-double coercion on cache round-trips

## Roadmap

### Completed

- [x] Project setup with feature-first architecture
- [x] Material 3 theme system (light/dark)
- [x] Email/password authentication via Better Auth
- [x] Session persistence and profile management
- [x] Transaction CRUD with categories and payment methods
- [x] Multi-wallet dashboard with live balances
- [x] Atomic wallet-to-wallet transfers
- [x] Group management with invite codes
- [x] Equal-split settlement algorithm
- [x] Analytics with pie charts, bar charts, and category breakdown
- [x] Budget alerts at 80%/100% thresholds
- [x] Multi-currency support (12 currencies)
- [x] Offline-first with Hive local cache
- [x] Sync service with connectivity monitoring and retry queue
- [x] Safe cache pruning for concurrent sync/write scenarios
- [x] Profile image upload (base64)
- [x] Password change flow

### In Progress

- [ ] Forgot password email flow (endpoint exists, needs email provider configuration)

### Planned

- [ ] RevenueCat integration / paywall
- [ ] CSV export
- [ ] Recurring expense scheduler
- [ ] Real-time Convex subscriptions
- [ ] Biometric authentication
- [ ] Push notifications (FCM)
- [ ] Search and filter transactions
- [ ] Sync indicator UI

## License

MIT
