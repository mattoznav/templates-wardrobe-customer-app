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

final myOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) {
  if (ref.watch(authProvider).value == null) return const [];
  return ref.watch(apiProvider).myOrders();
});

final orderProvider = FutureProvider.autoDispose.family<Order, int>((ref, id) => ref.watch(apiProvider).order(id));

String _thumb(String url, [int w = 120]) => url.isEmpty ? '' : '$url?w=$w&h=${(w * 4 / 3).round()}&fit=crop&crop=faces,entropy&q=70&auto=format';

/// Account tab: sign in, or the customer's orders.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: user.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
        error: (_, _) => const SizedBox.shrink(),
        data: (u) => u == null ? const _SignedOut() : _Orders(user: u),
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Welcome', style: display(48, weight: FontWeight.w300)),
          const SizedBox(height: 12),
          const Text('Sign in to follow your orders, cancel before they ship and send pieces back.', style: TextStyle(color: AppColors.inkSoft, fontSize: 16, height: 1.5)),
          const SizedBox(height: 28),
          FilledButton(onPressed: () => context.push('/sign-in'), child: const Text('SIGN IN OR CREATE AN ACCOUNT')),
        ],
      ),
    );
  }
}

class _Orders extends ConsumerWidget {
  const _Orders({required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);
    final fmt = ref.watch(fmtProvider);
    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: () => ref.refresh(myOrdersProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text('Hello, ${user.firstName.isEmpty ? user.email.split('@').first : user.firstName}', style: display(40, weight: FontWeight.w300)),
          const SizedBox(height: 4),
          Text(user.email, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 28),
          const Eyebrow('Your orders'),
          const SizedBox(height: 8),
          ...orders.when(
            loading: () => [const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(strokeWidth: 1.5)))],
            error: (e, _) => [Text(errorMessage(e), style: const TextStyle(color: AppColors.accent))],
            data: (list) => list.isEmpty
                ? [const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No orders yet.', style: TextStyle(color: AppColors.inkSoft)))]
                : [
                    for (final o in list)
                      InkWell(
                        onTap: () => context.push('/account/orders/${o.id}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(o.reference, style: display(22)),
                                    const SizedBox(height: 2),
                                    Text('${fmt.date(o.createdAt)} · ${o.pieces} ${o.pieces == 1 ? 'piece' : 'pieces'} · ${fmt.money(o.total)}',
                                        style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      for (final l in o.lines.take(4))
                                        Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: SizedBox(width: 36, height: 48, child: l.imageUrl.isEmpty ? Container(color: AppColors.photo) : CachedNetworkImage(imageUrl: _thumb(l.imageUrl, 80), fit: BoxFit.cover)),
                                        ),
                                    ]),
                                  ],
                                ),
                              ),
                              StatusTag(o.status, o.statusLabel),
                            ],
                          ),
                        ),
                      ),
                  ],
          ),
          const SizedBox(height: 32),
          OutlinedButton(onPressed: () => ref.read(authProvider.notifier).signOut(), child: const Text('SIGN OUT')),
        ],
      ),
    );
  }
}

class StatusTag extends StatelessWidget {
  const StatusTag(this.status, this.label, {super.key});
  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'shipped' || 'delivered' || 'refunded' => AppColors.success,
      'pending' || 'requested' => AppColors.accent,
      _ => AppColors.inkSoft,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: color)),
      child: Text(label.toUpperCase(), style: eyebrow(color: color).copyWith(fontSize: 9.5)),
    );
  }
}

/// One order: progress, pieces, delivery, and what can still be done with it.
class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(id));
    final fmt = ref.watch(fmtProvider);
    return Scaffold(
      appBar: AppBar(title: Text(order.value?.reference ?? 'Order')),
      body: AsyncBody(
        value: order,
        onRetry: () => ref.invalidate(orderProvider(id)),
        builder: (o) {
          final pending = o.isPending && o.expiresAt.isAfter(DateTime.now());
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Row(children: [Expanded(child: Eyebrow('Placed ${fmt.date(o.createdAt)}')), StatusTag(o.status, o.statusLabel)]),
              const SizedBox(height: 20),
              if (o.status == 'cancelled' || o.status == 'expired')
                Text(o.status == 'cancelled' ? 'Cancelled. Any payment was refunded in full.' : 'This order expired before it was paid. Nothing was charged.',
                    style: const TextStyle(color: AppColors.inkSoft))
              else
                _Timeline(o),
              const SizedBox(height: 24),
              for (final l in o.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: InkWell(
                    onTap: () => context.push('/products/${l.productSlug}'),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 64, height: 85, child: l.imageUrl.isEmpty ? Container(color: AppColors.photo) : CachedNetworkImage(imageUrl: _thumb(l.imageUrl, 140), fit: BoxFit.cover)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.productName, style: display(20)),
                              Text('${l.colour} · ${l.size} · Qty ${l.quantity}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                            ],
                          ),
                        ),
                        Text(fmt.money(l.unitPrice * l.quantity)),
                      ],
                    ),
                  ),
                ),
              const Divider(height: 24),
              _Row('Subtotal', fmt.money(o.subtotal)),
              _Row('Delivery', o.shipping == 0 ? 'Free' : fmt.money(o.shipping)),
              _Row('Total', fmt.money(o.total), strong: true),
              const SizedBox(height: 20),
              const Eyebrow('Delivery'),
              const SizedBox(height: 6),
              Text('${o.fullName}\n${o.address}', style: const TextStyle(color: AppColors.inkSoft, height: 1.5)),
              Text([o.shippingMethod, if (o.trackingNumber.isNotEmpty) 'Tracking ${o.trackingNumber}'].join(' · '), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              if (o.returns.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Eyebrow('Returns'),
                const SizedBox(height: 6),
                for (final r in o.returns) Text('${r.reference}: ${r.status}', style: const TextStyle(color: AppColors.inkSoft)),
              ],
              const SizedBox(height: 28),
              if (pending) FilledButton(onPressed: () => context.push('/pay/${o.id}'), child: const Text('COMPLETE PAYMENT')),
              if (o.canReturn) ...[
                OutlinedButton(onPressed: () => _startReturn(context, ref, o), child: const Text('RETURN PIECES')),
                if (o.returnDeadline != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Returns open until ${fmt.date(o.returnDeadline!)}.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ),
              ],
              if (o.canCancel) TextButton(onPressed: () => _cancel(context, ref, o), child: const Text('Cancel this order')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Order o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Cancel ${o.reference}?', style: display(26)),
        content: const Text('Anything you paid is refunded in full.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancel order', style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiProvider).cancelOrder(o.id);
      ref.invalidate(orderProvider(o.id));
      ref.invalidate(myOrdersProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  Future<void> _startReturn(BuildContext context, WidgetRef ref, Order o) async {
    final sent = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => _ReturnSheet(order: o));
    if (sent == true) {
      ref.invalidate(orderProvider(o.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return requested. Send the pieces back with their labels: we refund them when they arrive.')));
      }
    }
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline(this.o);
  final Order o;

  @override
  Widget build(BuildContext context) {
    final steps = [('Placed', o.createdAt), ('Paid', o.paidAt), ('Shipped', o.shippedAt), ('Delivered', o.deliveredAt)];
    return Row(
      children: [
        for (final (label, at) in steps)
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: at != null ? AppColors.ink : AppColors.line, width: 2))),
              child: Text(label, style: TextStyle(fontSize: 12, color: at != null ? AppColors.ink : AppColors.muted, fontWeight: at != null ? FontWeight.w600 : FontWeight.w400)),
            ),
          ),
      ],
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
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]));
  }
}

const _reasons = {
  'too_small': 'Too small',
  'too_large': 'Too large',
  'not_as_pictured': 'Not as pictured',
  'changed_mind': 'Changed my mind',
  'faulty': 'Faulty or damaged',
  'other': 'Other',
};

class _ReturnSheet extends ConsumerStatefulWidget {
  const _ReturnSheet({required this.order});
  final Order order;

  @override
  ConsumerState<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends ConsumerState<_ReturnSheet> {
  final Map<int, int> _picks = {};
  String _reason = 'too_small';
  final _note = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_picks.isEmpty) return setState(() => _error = 'Choose at least one piece.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).requestReturn(widget.order.id, _picks, _reason, _note.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.order.lines.where((l) => l.returnable > 0).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Return pieces', style: display(32)),
            const SizedBox(height: 6),
            const Text('We refund the pieces when they reach us. Delivery is not refunded.', style: TextStyle(color: AppColors.inkSoft)),
            const SizedBox(height: 16),
            for (final l in lines)
              CheckboxListTile(
                value: _picks.containsKey(l.id),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l.productName),
                subtitle: Text('${l.colour} · ${l.size}'),
                secondary: l.returnable > 1 && _picks.containsKey(l.id)
                    ? DropdownButton<int>(
                        value: _picks[l.id],
                        items: [for (var i = 1; i <= l.returnable; i++) DropdownMenuItem(value: i, child: Text('$i'))],
                        onChanged: (v) => setState(() => _picks[l.id] = v!),
                      )
                    : null,
                onChanged: (on) => setState(() => on == true ? _picks[l.id] = 1 : _picks.remove(l.id)),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: [for (final e in _reasons.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => _reason = v!),
            ),
            const SizedBox(height: 12),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Anything we should know (optional)'), maxLines: 3),
            if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: AppColors.accent))],
            const SizedBox(height: 18),
            FilledButton(onPressed: _busy ? null : _send, child: const Text('REQUEST RETURN')),
          ],
        ),
      ),
    );
  }
}
