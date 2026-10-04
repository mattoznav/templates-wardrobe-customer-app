import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/widgets.dart';
import '../../core/formatting.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../bag/bag_controller.dart';
import '../wishlist/wishlist_controller.dart';
import 'providers.dart';

const _lowStock = 3;

/// One product: photos, colour, size with live stock, add to bag.
class ProductScreen extends ConsumerWidget {
  const ProductScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(slug));
    final saved = ref.watch(wishlistProvider).contains(slug);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: saved ? 'Remove from wishlist' : 'Save to wishlist',
            icon: Icon(saved ? Icons.favorite : Icons.favorite_border),
            onPressed: () => ref.read(wishlistProvider.notifier).toggle(slug),
          ),
          const _BagButton(),
        ],
      ),
      body: AsyncBody(
        value: product,
        onRetry: () => ref.invalidate(productProvider(slug)),
        builder: (p) => _ProductBody(p),
      ),
    );
  }
}

class _BagButton extends ConsumerWidget {
  const _BagButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(bagCountProvider);
    return IconButton(
      tooltip: 'Bag',
      onPressed: () => context.go('/bag'),
      icon: Badge(isLabelVisible: count > 0, label: Text('$count'), backgroundColor: AppColors.ink, child: const Icon(Icons.shopping_bag_outlined)),
    );
  }
}

class _ProductBody extends ConsumerStatefulWidget {
  const _ProductBody(this.product);
  final Product product;

  @override
  ConsumerState<_ProductBody> createState() => _ProductBodyState();
}

class _ProductBodyState extends ConsumerState<_ProductBody> {
  late String _colour = widget.product.colours.firstOrNull?.slug ?? '';
  late String? _size = widget.product.oneSize ? 'one-size' : null;
  final _pages = PageController();
  int _page = 0;

  Product get p => widget.product;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Photos of the chosen colour first.
  List<ProductImage> get _images {
    final mine = p.images.where((i) => i.colour == _colour);
    return [...mine, ...p.images.where((i) => i.colour != _colour)];
  }

  void _add() {
    final v = p.variantFor(_colour, _size ?? '');
    if (v == null || v.stock <= 0) return;
    final colour = p.colours.firstWhere((c) => c.slug == _colour);
    final size = p.sizes.firstWhere((s) => s.code == _size);
    ref.read(bagProvider.notifier).add(BagItem(
          variant: v.id,
          quantity: 1,
          slug: p.slug,
          name: p.name,
          colour: colour.name,
          size: size.label,
          image: p.imageFor(_colour)?.url ?? '',
          price: p.price,
        ));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${p.name} added to your bag'),
        action: SnackBarAction(label: 'VIEW BAG', textColor: AppColors.paper, onPressed: () => context.go('/bag')),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(fmtProvider);
    final store = ref.watch(storeProvider).value;
    final images = _images;
    final selected = _size == null ? null : p.variantFor(_colour, _size!);
    final stock = selected?.stock ?? 0;
    final related = (ref.watch(productsProvider).value ?? const <Product>[])
        .where((o) => o.slug != p.slug && (o.collections.any(p.collections.contains) || o.section == p.section))
        .take(6)
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).width * 4 / 3,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pages,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => NetPhoto(images[i], width: 1000, semanticLabel: images[i].alt),
              ),
              if (images.length > 1)
                Positioned(
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < images.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 18 : 6,
                          height: 2,
                          color: AppColors.paper.withValues(alpha: i == _page ? 1 : 0.6),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(p.categoryName),
              const SizedBox(height: 8),
              Text(p.name, style: display(36)),
              const SizedBox(height: 6),
              Price(p.price, was: p.compareAtPrice, size: 17),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Eyebrow('Colour'),
                  const SizedBox(width: 10),
                  Text(p.colours.firstWhere((c) => c.slug == _colour, orElse: () => p.colours.first).name, style: const TextStyle(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  for (final c in p.colours)
                    Semantics(
                      selected: c.slug == _colour,
                      label: c.name,
                      button: true,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _colour = c.slug);
                          if (_pages.hasClients) _pages.jumpToPage(0);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.slug == _colour ? AppColors.ink : Colors.transparent)),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(color: Color(c.value), shape: BoxShape.circle, border: Border.all(color: Colors.black.withValues(alpha: 0.12))),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (!p.oneSize) ...[
                const SizedBox(height: 22),
                const Eyebrow('Size'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in p.sizes)
                      _SizeButton(
                        label: s.label,
                        stock: p.variantFor(_colour, s.code)?.stock ?? 0,
                        selected: _size == s.code,
                        onTap: () => setState(() => _size = s.code),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 20,
                child: Text(
                  selected == null
                      ? ''
                      : stock <= 0
                          ? 'Sold out in this size.'
                          : stock <= _lowStock
                              ? 'Only $stock left in this size.'
                              : 'In stock, ready to ship.',
                  style: TextStyle(fontSize: 13, color: stock > 0 && stock <= _lowStock ? AppColors.accent : AppColors.inkSoft),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: selected != null && stock > 0 ? _add : null,
                  child: Text(_size == null ? 'SELECT A SIZE' : stock <= 0 ? 'SOLD OUT' : 'ADD TO BAG'),
                ),
              ),
              const SizedBox(height: 20),
              if (store != null) ...[
                _Perk(Icons.local_shipping_outlined,
                    store.freeShippingOver == null ? 'Tracked delivery' : 'Free standard delivery over ${fmt.money(store.freeShippingOver!)}'),
                _Perk(Icons.undo, 'Free returns within ${store.returnWindowDays} days'),
                const _Perk(Icons.storefront_outlined, 'Collect in store in two hours'),
              ],
              const SizedBox(height: 8),
              _Section('Description', initiallyExpanded: true, children: [
                Text(p.description, style: const TextStyle(color: AppColors.inkSoft, height: 1.6)),
                const SizedBox(height: 10),
                for (final d in p.details)
                  Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('·  $d', style: const TextStyle(color: AppColors.inkSoft))),
              ]),
              _Section('Composition and care', children: [
                Text(p.composition, style: const TextStyle(color: AppColors.inkSoft)),
                const SizedBox(height: 6),
                Text(p.care, style: const TextStyle(color: AppColors.inkSoft)),
              ]),
              _Section('Delivery and returns', children: [
                Text(
                  'Standard delivery in 3 to 5 working days, express the next working day, or collect in store for free. '
                  'Send pieces back within ${store?.returnWindowDays ?? 30} days of delivery from your account.',
                  style: const TextStyle(color: AppColors.inkSoft, height: 1.6),
                ),
              ]),
              const SizedBox(height: 14),
              PhotoCredit(p.images),
            ],
          ),
        ),
        if (related.isNotEmpty) ...[
          const SizedBox(height: 40),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('Complete the look', style: display(30))),
          const SizedBox(height: 16),
          SizedBox(
            height: 320,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: related.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(width: 160, child: ProductTile(related[i], width: 300)),
            ),
          ),
        ],
      ],
    );
  }
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({required this.label, required this.stock, required this.selected, required this.onTap});
  final String label;
  final int stock;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final out = stock <= 0;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label${out ? ', sold out' : stock <= _lowStock ? ', only $stock left' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: out ? null : onTap,
        child: Container(
          width: 58,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.transparent,
            border: Border.all(color: selected ? AppColors.ink : AppColors.lineStrong),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    color: selected ? AppColors.paper : out ? AppColors.muted : AppColors.ink,
                    decoration: out ? TextDecoration.lineThrough : null,
                  )),
              if (!out && stock <= _lowStock)
                Positioned(top: -10, right: -16, child: Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [Icon(icon, size: 18, color: AppColors.inkSoft), const SizedBox(width: 12), Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft)))]),
      );
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.children, this.initiallyExpanded = false});
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
        child: ExpansionTile(
          title: Text(title.toUpperCase(), style: eyebrow(color: AppColors.ink)),
          initiallyExpanded: initiallyExpanded,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: AppColors.ink,
          collapsedIconColor: AppColors.ink,
          children: children,
        ),
      ),
    );
  }
}
