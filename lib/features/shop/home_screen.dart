import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/widgets.dart';
import '../../core/formatting.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import 'providers.dart';

/// The front page: hero, new arrivals, departments and the season's edits.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorial = ref.watch(editorialProvider);
    final store = ref.watch(storeProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text((store?.name ?? 'Halden').toUpperCase(), style: display(26).copyWith(letterSpacing: 8))),
      body: AsyncBody(
        value: editorial,
        onRetry: () => ref.invalidate(editorialProvider),
        builder: (ed) => RefreshIndicator(
          color: AppColors.ink,
          onRefresh: () async {
            ref.invalidate(productsProvider);
            ref.invalidate(collectionsProvider);
            await ref.read(productsProvider.future);
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (ed['home-hero'] case final hero?) _Hero(hero),
              const _NewIn(),
              const SizedBox(height: 48),
              _Departments(ed),
              const SizedBox(height: 56),
              const _Edits(),
              if (ed['knitwear'] case final knit?) _Band(knit),
              if (ed['store'] case final shop?) _Visit(shop, store),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero(this.e);
  final Editorial e;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetPhoto(e.image, ratio: 4 / 5, width: 900, semanticLabel: e.alt),
          const SizedBox(height: 6),
          PhotoCredit([e.image]),
          const SizedBox(height: 24),
          const Eyebrow('Autumn and winter'),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Made slowly.\n'),
              TextSpan(text: 'Worn for years.', style: display(48, style: FontStyle.italic, weight: FontWeight.w300)),
            ]),
            style: display(48, weight: FontWeight.w300),
          ),
          const SizedBox(height: 14),
          Text(e.text, style: const TextStyle(color: AppColors.inkSoft, fontSize: 15, height: 1.6)),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: FilledButton(onPressed: () => context.go('/shop?section=women'), child: const Text('WOMEN'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(onPressed: () => context.go('/shop?section=men'), child: const Text('MEN'))),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.label, this.title, {this.action, this.onAction});
  final String label;
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Eyebrow(label), const SizedBox(height: 6), Text(title, style: display(36, weight: FontWeight.w300))],
            ),
          ),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!.toUpperCase(), style: eyebrow(color: AppColors.ink))),
        ],
      ),
    );
  }
}

class _NewIn extends ConsumerWidget {
  const _NewIn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final items = products.where((p) => p.isNew).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading('Just arrived', 'New in', action: 'View all', onAction: () => context.go('/shop?new=1')),
        const SizedBox(height: 18),
        SizedBox(
          height: 330,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => SizedBox(width: 168, child: ProductTile(items[i], width: 300)),
          ),
        ),
      ],
    );
  }
}

class _Departments extends StatelessWidget {
  const _Departments(this.ed);
  final Map<String, Editorial> ed;

  @override
  Widget build(BuildContext context) {
    final items = [('women', 'Women'), ('men', 'Men'), ('accessories', 'Accessories')];
    return SizedBox(
      height: 300,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final (key, label) = items[i];
          final e = ed[key];
          return SizedBox(
            width: 220,
            child: InkWell(
              onTap: () => context.go('/shop?section=$key'),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetPhoto(e?.image, ratio: 220 / 300, width: 440, semanticLabel: e?.alt),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0x99141210)]),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: display(34, color: AppColors.paper, weight: FontWeight.w300)),
                        const SizedBox(height: 4),
                        Text('SHOP NOW', style: eyebrow(color: AppColors.paper)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Edits extends ConsumerWidget {
  const _Edits();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider).value ?? const <Collection>[];
    if (collections.isEmpty) return const SizedBox.shrink();
    final first = collections.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading('Collections', 'Edits for the season'),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: InkWell(
            onTap: () => context.push('/collections/${first.slug}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NetPhoto(first.image, ratio: 4 / 5, width: 900, semanticLabel: first.alt),
                const SizedBox(height: 14),
                Text(first.title, style: display(32)),
                const SizedBox(height: 4),
                Text(first.subtitle, style: display(19, style: FontStyle.italic, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        for (final c in collections.skip(1))
          InkWell(
            onTap: () => context.push('/collections/${c.slug}'),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
              child: Row(
                children: [
                  SizedBox(width: 72, child: NetPhoto(c.image, width: 150)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.title, style: display(24)),
                        Text(c.subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        const SizedBox(height: 48),
      ],
    );
  }
}

class _Band extends StatelessWidget {
  const _Band(this.e);
  final Editorial e;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NetPhoto(e.image, ratio: 4 / 5, width: 900, semanticLabel: e.alt),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xB3141210)]),
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
              Eyebrow('Our knitwear', color: AppColors.paper.withValues(alpha: 0.8)),
              const SizedBox(height: 8),
              Text(e.title, style: display(36, color: AppColors.paper, weight: FontWeight.w300)),
              const SizedBox(height: 10),
              Text(e.text, style: const TextStyle(color: AppColors.paper, fontSize: 14, height: 1.55)),
              const SizedBox(height: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.paper, side: const BorderSide(color: AppColors.paper)),
                onPressed: () => context.go('/shop?category=knitwear'),
                child: const Text('SHOP KNITWEAR'),
              ),
              const SizedBox(height: 10),
              PhotoCredit([e.image], color: AppColors.paper.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Visit extends StatelessWidget {
  const _Visit(this.e, this.store);
  final Editorial e;
  final Store? store;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetPhoto(e.image, ratio: 16 / 11, width: 900, semanticLabel: e.alt),
          const SizedBox(height: 6),
          PhotoCredit([e.image]),
          const SizedBox(height: 20),
          Text(e.title, style: display(34, weight: FontWeight.w300)),
          const SizedBox(height: 10),
          Text(e.text, style: const TextStyle(color: AppColors.inkSoft, height: 1.6)),
          if (store != null) ...[
            const SizedBox(height: 16),
            _Line(Icons.place_outlined, store!.address),
            const SizedBox(height: 8),
            _Line(Icons.schedule, store!.openingHours),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.inkSoft),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.inkSoft, fontSize: 14))),
        ],
      );
}
