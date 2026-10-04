import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/widgets.dart';
import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import 'bag_controller.dart';

/// Today's prices, stock and standard shipping for the bag. Nothing is reserved.
final bagQuoteProvider = FutureProvider.autoDispose<Quote?>((ref) async {
  final items = ref.watch(bagProvider);
  if (items.isEmpty) return null;
  return ref.watch(apiProvider).quote(items.lines, 'standard');
});

class BagScreen extends ConsumerWidget {
  const BagScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(bagProvider);
    final quote = ref.watch(bagQuoteProvider);
    final fmt = ref.watch(fmtProvider);
    final count = ref.watch(bagCountProvider);
    final q = quote.value;
    final problems = q?.problems ?? const <String>[];

    return Scaffold(
      appBar: AppBar(title: Text(count > 0 ? 'Your bag ($count)' : 'Your bag')),
      body: items.isEmpty
          ? Message(
              icon: Icons.shopping_bag_outlined,
              text: 'Your bag is empty.',
              action: OutlinedButton(onPressed: () => context.go('/shop'), child: const Text('DISCOVER THE COLLECTION')),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 28),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final line = q?.lines.where((l) => l.variant == item.variant).firstOrNull;
                      final short = line != null && line.available < item.quantity;
                      return BagLine(item: item, problem: short ? (line.available == 0 ? 'Sold out: remove it to continue.' : 'Only ${line.available} left.') : null);
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    decoration: const BoxDecoration(color: AppColors.raised, border: Border(top: BorderSide(color: AppColors.line))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Row('Subtotal', fmt.money(q?.subtotal ?? items.subtotal)),
                        const SizedBox(height: 4),
                        _Row('Standard delivery', q == null ? '…' : (q.shipping == 0 ? 'Free' : fmt.money(q.shipping))),
                        const Divider(height: 22),
                        _Row('Total', fmt.money(q?.total ?? items.subtotal), strong: true),
                        if (problems.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          for (final p in problems) Text(p, style: const TextStyle(color: AppColors.accent, fontSize: 13)),
                        ],
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: problems.isNotEmpty
                              ? null
                              : () async {
                                  if (ref.read(authProvider).value == null) {
                                    final ok = await context.push<bool>('/sign-in', extra: 'Sign in or create an account to place your order and follow it afterwards.');
                                    if (ok != true || !context.mounted) return;
                                  }
                                  context.push('/checkout');
                                },
                          child: const Text('CHECKOUT'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: strong ? 17 : 14, fontWeight: strong ? FontWeight.w600 : FontWeight.w400, color: strong ? AppColors.ink : AppColors.inkSoft);
    return Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]);
  }
}

/// A bag line with quantity buttons, shared by the bag and checkout.
class BagLine extends ConsumerWidget {
  const BagLine({super.key, required this.item, this.problem, this.editable = true});
  final BagItem item;
  final String? problem;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(fmtProvider);
    final bag = ref.read(bagProvider.notifier);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => context.push('/products/${item.slug}'),
          child: SizedBox(
            width: 84,
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: item.image.isEmpty
                  ? Container(color: AppColors.photo)
                  : CachedNetworkImage(imageUrl: Photo(url: item.image, photographer: '', photographerUrl: '', sourceUrl: '').sized(200, 266), fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: display(21)),
              const SizedBox(height: 2),
              Text('${item.colour} · ${item.size}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 10),
              if (editable)
                Row(
                  children: [
                    _Step(icon: Icons.remove, label: 'One less', onTap: () => bag.setQuantity(item.variant, item.quantity - 1)),
                    SizedBox(width: 30, child: Text('${item.quantity}', textAlign: TextAlign.center)),
                    _Step(icon: Icons.add, label: 'One more', onTap: item.quantity >= maxQuantity ? null : () => bag.setQuantity(item.variant, item.quantity + 1)),
                    const Spacer(),
                    TextButton(onPressed: () => bag.remove(item.variant), child: const Text('Remove', style: TextStyle(decoration: TextDecoration.underline))),
                  ],
                )
              else
                Text('Qty ${item.quantity}', style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
              if (problem != null) Text(problem!, style: const TextStyle(color: AppColors.accent, fontSize: 12.5)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(fmt.money(item.price * item.quantity), style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(border: Border.all(color: AppColors.lineStrong)),
            child: Icon(icon, size: 16, color: onTap == null ? AppColors.lineStrong : AppColors.ink),
          ),
        ),
      );
}
