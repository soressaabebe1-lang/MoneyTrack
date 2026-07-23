# MoneyTrack — Flutter Frontend

A Material 3 Flutter frontend built to consume the MoneyTrack Flask API
(`/transactions`, `/total_income`, `/total_expenses`, `/net_balance`).

## Setup

```bash
flutter create . --project-name money_tracker_app --overwrite
flutter pub get
flutter run
```

(The `flutter create .` step regenerates the platform folders — `android/`,
`ios/`, etc. — that aren't included here, since this deliverable is just
the Dart source.)

## Pointing at your backend

Edit the default `baseUrl` in `lib/services/api_service.dart`:

```dart
ApiService({this.baseUrl = 'http://10.0.2.2:5000'});
```

- `http://10.0.2.2:5000` → Android emulator talking to a Flask server running
  on your machine at `localhost:5000`.
- `http://localhost:5000` → iOS simulator.
- Your Render URL → physical device or production.

## Structure

```
lib/
  main.dart                        # App entry, theming, bottom nav shell
  theme/app_theme.dart             # Material 3 light/dark theme, green brand color
  models/transaction_model.dart    # Maps to Flask's transaction.to_dict()
  services/api_service.dart        # HTTP client for the Flask endpoints
  screens/
    dashboard_screen.dart          # Net balance, quick-add, recent transactions
    add_transaction_screen.dart    # Form for creating an income/expense entry
    category_breakdown_screen.dart # Donut chart + ranked list by category
  widgets/
    net_balance_card.dart
    quick_action_button.dart
    transaction_tile.dart          # Also holds category icon/color mapping
```

## Known assumption worth revisiting

Your backend's `transaction` model has `name` and `reason` fields but no
dedicated `category`. The Category Breakdown screen currently groups
expenses by `reason` as a stand-in category. If you add a real `category`
column to the Flask model later, swap the grouping key in
`category_breakdown_screen.dart` (`_buildTotals`) and the icon-mapping
lookup in `transaction_tile.dart` (`categoryStyleFor`) from `reason` to
`category`.

## Not yet included

- Persistent auth/session handling (your quiz-app backend has JWT; this
  MoneyTrack backend currently doesn't require it)
- Date-range filtering, editing an existing transaction, and a dedicated
  "See all transactions" screen (the Dashboard links to it visually but
  doesn't navigate there yet)
- Widget/unit tests
