import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/formatting.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../features/wishlist/wishlist_controller.dart';

/// A photo from the Unsplash CDN, requested at the size it is shown at.
class NetPhoto extends StatelessWidget {
  const NetPhoto(this.photo, {super.key, this.ratio = 3 / 4, this.width = 600, this.semanticLabel});

  final Photo? photo;
  final double ratio;
  final int width;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1, 3);
    final w = (width * dpr / 1.5).round();
    final placeholder = Container(color: AppColors.photo);
    return AspectRatio(
      aspectRatio: ratio,
      child: photo == null
          ? placeholder
          : Semantics(
              image: true,
              label: semanticLabel,
              child: CachedNetworkImage(
                imageUrl: photo!.sized(w, (w / ratio).round()),
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 350),
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) => placeholder,
              ),
            ),
    );
  }
}

/// "Photo: Name on Unsplash", linking to the source as the license asks.
class PhotoCredit extends StatelessWidget {
  const PhotoCredit(this.photos, {super.key, this.color = AppColors.muted});

  final List<Photo> photos;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final names = {for (final p in photos) p.photographer}.where((n) => n.isNotEmpty).join(', ');
    if (names.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(photos.first.sourceUrl), mode: LaunchMode.externalApplication),
      child: Text('Photo: $names on Unsplash', style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

class Price extends ConsumerWidget {
  const Price(this.price, {super.key, this.was, this.size = 14});

  final double price;
  final double? was;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(fmtProvider);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: fmt.money(price), style: TextStyle(color: was != null ? AppColors.accent : AppColors.inkSoft)),
        if (was != null) ...[
          const TextSpan(text: '  '),
          TextSpan(text: fmt.money(was!), style: const TextStyle(color: AppColors.muted, decoration: TextDecoration.lineThrough)),
        ],
      ]),
      style: TextStyle(fontSize: size, fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = AppColors.muted});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: eyebrow(color: color));
}

/// Product tile for grids and rails: photo, heart, name, price, colours.
class ProductTile extends ConsumerWidget {
  const ProductTile(this.product, {super.key, this.width = 400});

  final Product product;
  final int width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = product;
    final saved = ref.watch(wishlistProvider).contains(p.slug);
    return Semantics(
      button: true,
      label: '${p.name}, ${ref.watch(fmtProvider).money(p.price)}',
      child: InkWell(
        onTap: () => context.push('/products/${p.slug}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                NetPhoto(p.images.firstOrNull, width: width, semanticLabel: p.images.firstOrNull?.alt),
                if (p.isNew || p.onSale || !p.inStock)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      color: AppColors.paper,
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      child: Text(
                        !p.inStock ? 'SOLD OUT' : p.onSale ? 'SALE' : 'NEW',
                        style: eyebrow(color: p.onSale ? AppColors.accent : AppColors.ink).copyWith(fontSize: 9.5),
                      ),
                    ),
                  ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Material(
                    color: AppColors.paper.withValues(alpha: 0.85),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: saved ? 'Remove from wishlist' : 'Save to wishlist',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(saved ? Icons.favorite : Icons.favorite_border, size: 18, color: AppColors.ink),
                      onPressed: () => ref.read(wishlistProvider.notifier).toggle(p.slug),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, height: 1.3)),
            const SizedBox(height: 2),
            Price(p.price, was: p.compareAtPrice, size: 13.5),
            if (p.colours.length > 1) ...[
              const SizedBox(height: 6),
              Row(children: [for (final c in p.colours) Swatch(c, size: 9)]),
            ],
          ],
        ),
      ),
    );
  }
}

class Swatch extends StatelessWidget {
  const Swatch(this.colour, {super.key, this.size = 12, this.selected = false});
  final Colour colour;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        color: Color(colour.value),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
      ),
    );
  }
}

/// A two-column grid of products that sizes its tiles to the screen.
class ProductGrid extends StatelessWidget {
  const ProductGrid(this.products, {super.key, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 32)});
  final List<Product> products;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, mainAxisSpacing: 28, crossAxisSpacing: 12, childAspectRatio: 0.57),
        delegate: SliverChildBuilderDelegate((_, i) => ProductTile(products[i]), childCount: products.length),
      ),
    );
  }
}

/// Loading, error with retry, or the content, for any [AsyncValue].
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.builder, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      data: builder,
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
      error: (e, _) => Message(
        icon: Icons.wifi_off_rounded,
        text: errorMessage(e, 'This could not be loaded.'),
        action: onRetry == null ? null : OutlinedButton(onPressed: onRetry, child: const Text('TRY AGAIN')),
      ),
    );
  }
}

/// A centred empty or error state.
class Message extends StatelessWidget {
  const Message({super.key, required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center, style: display(24, color: AppColors.inkSoft)),
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}
