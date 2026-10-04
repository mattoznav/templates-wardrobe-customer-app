import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

/// Saved products, kept on the phone. Stored as slugs so they always show today's price and stock.
final wishlistProvider = NotifierProvider<WishlistController, List<String>>(WishlistController.new);

class WishlistController extends Notifier<List<String>> {
  static const _key = 'wardrobe.wishlist';

  @override
  List<String> build() => ref.read(sharedPreferencesProvider).getStringList(_key) ?? const [];

  bool contains(String slug) => state.contains(slug);

  /// Returns true when the product was added.
  bool toggle(String slug) {
    final adding = !state.contains(slug);
    state = adding ? [slug, ...state] : state.where((s) => s != slug).toList();
    ref.read(sharedPreferencesProvider).setStringList(_key, state);
    return adding;
  }
}
