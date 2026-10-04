import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/widgets.dart';
import '../shop/providers.dart';
import 'wishlist_controller.dart';

/// Saved pieces, with today's price and stock.
class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slugs = ref.watch(wishlistProvider);
    final products = ref.watch(productsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: AsyncBody(
        value: products,
        onRetry: () => ref.invalidate(productsProvider),
        builder: (all) {
          final saved = [for (final s in slugs) ...all.where((p) => p.slug == s)];
          if (saved.isEmpty) {
            return Message(
              icon: Icons.favorite_border,
              text: 'Tap the heart on a piece to keep it here.',
              action: OutlinedButton(onPressed: () => context.go('/shop'), child: const Text('BROWSE THE SHOP')),
            );
          }
          return CustomScrollView(slivers: [ProductGrid(saved, padding: const EdgeInsets.fromLTRB(16, 16, 16, 32))]);
        },
      ),
    );
  }
}
