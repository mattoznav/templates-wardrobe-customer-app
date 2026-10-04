import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/widgets.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import 'providers.dart';

/// A curated edit: cover photo, a few words and its pieces.
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider);
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    return Scaffold(
      appBar: AppBar(),
      body: AsyncBody(
        value: collections,
        onRetry: () => ref.invalidate(collectionsProvider),
        builder: (list) {
          final c = list.where((x) => x.slug == slug).firstOrNull;
          if (c == null) return const Message(icon: Icons.search_off, text: 'This edit is no longer online.');
          final items = products.where((p) => p.collections.contains(slug)).toList();
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        NetPhoto(c.image, ratio: 4 / 5, width: 1000, semanticLabel: c.alt),
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0x99141210)]),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 22,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Eyebrow('The edit', color: AppColors.paper.withValues(alpha: 0.8)),
                              const SizedBox(height: 8),
                              Text(c.title, style: display(48, color: AppColors.paper, weight: FontWeight.w300)),
                              Text(c.subtitle, style: display(22, color: AppColors.paper, style: FontStyle.italic)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: PhotoCredit([c.image]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Text(c.description, style: display(24, color: AppColors.inkSoft)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Text('${items.length} pieces', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              ProductGrid(items),
            ],
          );
        },
      ),
    );
  }
}
