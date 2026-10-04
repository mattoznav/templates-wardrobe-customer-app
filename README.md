# Wardrobe template: Customer app

The clothing store's app for customers: an editorial front page, the catalogue with filters, product pages with live stock, wishlist, bag, checkout and payment, orders, cancellations and returns.

Flutter, Riverpod, go_router and Dio. iOS and Android. Part of the [`templates-wardrobe`](https://github.com/mattoznav/templates-wardrobe) template, inside the [`templates`](https://github.com/mattoznav/templates) collection.

## Requirements

- Flutter 3.44 or newer (Dart 3.12)
- For iOS: macOS with Xcode and CocoaPods; the app targets iOS 15 or later
- For Android: Android Studio with an emulator or a device
- The backend running locally (see its README)

## Quick start

Start the [backend](https://github.com/mattoznav/templates-wardrobe-backend) first, then:

```bash
flutter pub get
flutter run
```

The app finds the backend on this computer by itself: `localhost:8001` on the iOS simulator, `10.0.2.2:8001` on the Android emulator. For a real device or a deployed backend:

```bash
flutter run --dart-define=API_URL=https://shop.example.com/api --dart-define=MERCHANT_NAME="Your Shop"
```

## Screens

| Tab or screen | What it does |
| --- | --- |
| Discover | Hero, new arrivals, departments, the season's edits, the knitwear story and the store |
| Shop | The whole catalogue: search, section (women, men, accessories), category, sort, new in and sale |
| Product | Photos per colour, colour and size with live stock ("only 2 left"), add to bag, details, care, delivery, photo credits, complete the look |
| Collection | A curated edit with its cover and pieces |
| Wishlist | Saved pieces with today's price and stock, kept on the phone |
| Bag | Quantities, today's prices and stock checked with the backend, free shipping, problems such as sold out sizes |
| Checkout | Delivery address (remembered), delivery method, then payment while the pieces are set aside for 15 minutes |
| Account | Orders with their progress, tracking, cancel before shipping, complete a pending payment, return pieces with a reason |

The bag and wishlist work without an account. Signing in is asked only at checkout and to see orders.

## Payments

The app follows the backend:

- **Fake provider** (default): "Pay" and "Simulate a declined card" buttons. No money moves.
- **Stripe**: the native Stripe payment sheet, then the app waits for the backend webhook to mark the order paid. Use test mode keys and [test cards](https://docs.stripe.com/testing).

Stripe needs iOS 15 or later and, on Android, `FlutterFragmentActivity` with a Material theme: both are already set up.

## Photos

Product and editorial photos come from [Unsplash](https://unsplash.com) under the [Unsplash License](https://unsplash.com/license). The app loads them from the Unsplash CDN at the size each screen needs, caches them, and credits the photographer under each image.

## Structure

```
lib/
  core/       config, API client (JWT with refresh), models, theme, prices and dates
  common/     shared widgets: photos with credits, product tiles and grid, prices, empty states
  features/   shop (discover, browse, product, collection), bag, checkout, wishlist, account, auth
  router.dart tabs and full screen routes
```

## Before publishing

- Change the bundle identifier (`com.example.wardrobe`) on iOS and Android.
- Replace the app icon and name ("Halden").
- Remove the local networking exceptions, which are only for development: `NSAllowsLocalNetworking` in `ios/Runner/Info.plist` and `usesCleartextTraffic` in the debug Android manifest.

Run the tests with `flutter test`.
