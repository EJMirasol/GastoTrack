# GastoTrack

A high-performance mobile expense tracking app built with Flutter and Convex, featuring real-time synchronization, group expense splitting, and interactive analytics.

## Features

- **Quick Add** - One-tap expense entry with amount, category, and date
- **Smart Categories** - Default and custom expense categories
- **Real-time Analytics** - Pie charts, bar charts, and spending breakdowns
- **Group Wallets** - Shared expense tracking for trips, households, etc.
- **Split Bills** - Equal, percentage, or custom amount splits
- **Budget Alerts** - Notifications at 80%/100% budget thresholds
- **Offline Support** - Log expenses offline, sync when connected

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter |
| State Management | Riverpod |
| Backend | Convex |
| Charts | fl_chart |
| Routing | go_router |

## Project Structure

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/      # Colors, sizes, strings
│   ├── theme/          # Light/dark themes
│   └── router/         # GoRouter configuration
├── features/
│   ├── auth/           # User authentication
│   ├── expenses/       # Expense tracking
│   ├── groups/         # Group wallets
│   ├── analytics/      # Charts & insights
│   └── settings/       # App settings
└── shared/
    └── widgets/        # Reusable UI components

convex/
├── schema.ts           # Database schema
├── users.ts            # User functions
├── expenses.ts         # Expense CRUD
├── categories.ts       # Category management
└── groups.ts           # Group management
```

## Getting Started

### Prerequisites

- Flutter SDK 3.10+
- Node.js 18+
- Convex CLI (`npm install -g convex`)

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

3. **Run the app:**
   ```bash
   flutter run
   ```

### Convex Setup

1. Create a Convex account at [convex.dev](https://convex.dev)
2. Create a new project
3. Run `npx convex dev` to deploy the schema and functions
4. Copy the deployment URL to your Flutter app configuration

## Monetization (RevenueCat)

| Feature | Free | Pro |
|---------|------|-----|
| Monthly Expenses | 50 | Unlimited |
| Shared Groups | 1 (3 members) | Unlimited |
| Analytics | Basic | Advanced + CSV |
| Cloud Sync | Standard | Priority |

## Roadmap

- [x] Project setup & folder structure
- [x] Theme system (light/dark)
- [x] Core expense tracking
- [x] Analytics with charts
- [ ] Convex backend integration
- [ ] Group management
- [ ] Split bill logic
- [ ] RevenueCat integration
- [ ] Offline support

## License

MIT
