# GastoTrack

A production-quality mobile expense tracking app built with Flutter and Convex, featuring Better Auth authentication, real-time synchronization, group expense splitting, multi-currency support, and interactive analytics.

## Features

- **Authentication** - Email/password sign-up and sign-in via Better Auth with session persistence and demo mode
- **Quick Add** - One-tap expense entry with amount, category, and date
- **Smart Categories** - 10 default categories with custom category support
- **Multi-Currency** - 12 currencies supported (PHP, USD, EUR, GBP, JPY, KRW, CNY, INR, AUD, CAD, SGD, AED) with persistent selection
- **Real-time Analytics** - Pie charts, bar charts, and category breakdowns using fl_chart
- **Group Wallets** - Create groups, share invite codes, split bills equally
- **Settlement Algorithm** - Automated equal-split debt calculation with optimal payment paths
- **Budget Alerts** - Local notifications at 80%/100% budget thresholds
- **Offline-First** - Hive local cache with automatic sync queue, last-write-wins conflict resolution, and 30-day data expiry
- **Cloud Sync** - Real-time sync to Convex backend with connectivity monitoring and 5-minute periodic sync
- **Theme** - Material 3 light and dark themes

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter 3.10+ |
| State Management | Riverpod |
| Backend | Convex |
| Authentication | Better Auth (via `@convex-dev/better-auth`) |
| Local Storage | Hive + Hive Flutter |
| Charts | fl_chart |
| Routing | go_router |
| Notifications | flutter_local_notifications |
| Connectivity | connectivity_plus |
| HTTP | http (for Convex REST API) |

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Flutter App  │────▶│  Convex API  │────▶│  Convex DB   │
│  (Riverpod)  │     │  (REST HTTP) │     │  (Real-time) │
└──────┬──────┘     └──────────────┘     └─────────────┘
       │
       ▼
┌──────────────┐
│  Hive Cache   │
│  (Offline)    │
└──────────────┘
```

- **Offline-first**: All writes go to Hive first, then sync to Convex. Reads serve from cache immediately.
- **Auth flow**: Better Auth REST endpoints (`/api/auth/sign-up/email`, `/api/auth/sign-in/email`, `/api/auth/get-session`) called via `http` package. Token stored in Hive and sent as cookie header.
- **Sync**: Connectivity monitoring triggers sync on reconnect. Periodic sync every 5 minutes. Failed mutations queued with max 5 retries.
- **Server auth**: All Convex mutations verify the authenticated user via `authComponent.getAuthUser(ctx)` — no client-provided userId is trusted.

## Project Structure

```
lib/
├── main.dart                          # App entry point, Hive + notification init
├── app.dart                           # MaterialApp.router with themes
├── core/
│   ├── config/
│   │   └── env.dart                   # Convex API & site URLs
│   ├── constants/
│   │   ├── app_colors.dart
│   │   ├── app_sizes.dart
│   │   ├── app_strings.dart
│   │   └── constants.dart             # Barrel export
│   ├── theme/
│   │   └── app_theme.dart             # Light/dark ThemeData
│   ├── router/
│   │   └── app_router.dart            # GoRouter + auth redirect
│   └── services/
│       ├── convex_service.dart        # Convex HTTP client + auth endpoints
│       ├── local_cache_service.dart   # Hive boxes (expenses, groups, budgets, settings)
│       ├── sync_service.dart          # Connectivity monitor, pull/push, retry queue
│       ├── currency_service.dart      # Currency selection + formatCurrency()
│       └── notification_service.dart  # Budget alerts + reminders
├── features/
│   ├── auth/
│   │   ├── domain/user.dart           # User model + SubscriptionStatus
│   │   ├── data/auth_repository.dart  # AuthNotifier (Better Auth HTTP)
│   │   └── presentation/auth_page.dart
│   ├── expenses/
│   │   ├── domain/expense.dart        # Expense model + ExpenseType
│   │   ├── domain/category.dart       # Category model
│   │   ├── data/expense_repository.dart # ExpenseNotifier (Convex + Hive)
│   │   ├── data/budget_service.dart   # BudgetNotifier + BudgetAlertService
│   │   ├── presentation/home_page.dart
│   │   ├── presentation/add_expense_page.dart
│   │   └── presentation/analytics_page.dart
│   ├── groups/
│   │   ├── domain/group.dart          # Group model
│   │   ├── presentation/groups_page.dart   # GroupNotifier + GroupsPage
│   │   └── presentation/group_detail_page.dart
│   └── settings/
│       └── presentation/settings_page.dart  # Currency picker + settings
└── shared/
    └── widgets/
        ├── balance_card.dart
        ├── expense_list_item.dart
        └── widgets.dart               # Barrel export

convex/
├── package.json
├── .env.local                         # BETTER_AUTH_SECRET, SITE_URL
├── convex/
│   ├── convex.config.ts               # App definition with betterAuth component
│   ├── schema.ts                      # Database schema (7 tables)
│   ├── auth.config.ts                 # getAuthConfigProvider() for JWT validation
│   ├── auth.ts                        # Better Auth integration + user profile queries
│   ├── http.ts                        # HTTP route registration (Better Auth endpoints)
│   ├── users.ts                       # Subscription update
│   ├── expenses.ts                    # Expense CRUD (auth-protected)
│   ├── categories.ts                  # Category CRUD (auth-protected)
│   ├── groups.ts                      # Group CRUD + join/leave (auth-protected)
│   ├── budgets.ts                     # Budget CRUD (auth-protected)
│   ├── betterAuth/
│   │   └── schema.ts                  # Extends user table with subscriptionStatus
│   └── _generated/                    # Auto-generated by Convex CLI
```

## Getting Started

### Prerequisites

- Flutter SDK 3.10+
- Node.js 18+
- Rust toolchain (required by `convex_flutter` Cargokit)
- Convex account at [convex.dev](https://convex.dev)

### Installation

1. **Clone and install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

2. **Set up Convex backend:**
   ```bash
   cd convex
   npm install
   npx convex dev
   ```
   This will install the `betterAuth` component and deploy all functions.

3. **Configure environment variables:**
   ```bash
   npx convex env set BETTER_AUTH_SECRET <your-secret>
   npx convex env set SITE_URL <your-convex-site-url>
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

### Environment Variables

| Variable | Description | Where |
|----------|-------------|-------|
| `BETTER_AUTH_SECRET` | Secret key for Better Auth session encryption | Convex env |
| `SITE_URL` | Convex site URL (e.g. `https://your-project.convex.site`) | Convex env |
| `CONVEX_DEPLOYMENT` | Deployment identifier | `.env.local` |

### Demo Mode

Tap "Continue as Demo" on the login screen to use the app without creating an account. Demo password: `Demo@123`.

## Monetization (RevenueCat - Planned)

| Feature | Free | Pro |
|---------|------|-----|
| Monthly Expenses | 50 | Unlimited |
| Shared Groups | 1 (3 members) | Unlimited |
| Analytics | Basic | Advanced + CSV |
| Cloud Sync | Standard | Priority |

## Database Schema

| Table | Purpose |
|-------|---------|
| `user` | Managed by Better Auth (email, name, session) |
| `session` | Managed by Better Auth |
| `expenses` | User expenses with category, group, date |
| `categories` | Default + custom categories |
| `groups` | Shared expense groups with invite codes |
| `groupMembers` | Group membership tracking |
| `budgets` | Per-category budget limits |
| `recurringRules` | Recurring expense rules (planned) |
| `settlements` | Group settlement records (planned) |

## Roadmap

### Completed
- [x] Project setup & feature-first architecture
- [x] Theme system (light/dark Material 3)
- [x] Core expense tracking (add, edit, delete)
- [x] Analytics with pie/bar charts
- [x] Better Auth integration (sign-up, sign-in, session)
- [x] Convex backend with auth-protected mutations
- [x] Offline-first with Hive local cache
- [x] Sync service with connectivity monitoring + retry queue
- [x] Group management (create, join via invite code, leave)
- [x] Equal-split settlement algorithm
- [x] Budget alerts (80%/100% thresholds)
- [x] Multi-currency support (12 currencies)
- [x] Currency picker in Settings
- [x] "Continue as Demo" mode
- [x] Clipboard support for invite codes

### In Progress
- [ ] Forgot password email flow (endpoint exists, needs email provider)
- [ ] RevenueCat integration / paywall

### Planned
- [ ] CSV export
- [ ] Recurring expenses scheduler
- [ ] Real-time Convex subscriptions
- [ ] Biometric auth
- [ ] Photo receipts
- [ ] Search/filter expenses
- [ ] Push notifications (FCM)

## License

MIT
