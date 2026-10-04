import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';

import '../../common/widgets.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/formatting.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../account/orders_screen.dart';
import '../auth/auth_controller.dart';
import '../bag/bag_controller.dart';
import '../bag/bag_screen.dart';
import '../shop/providers.dart';

enum _Stage { form, loading, paying, confirming, done, expired, failed }

const _addressKey = 'wardrobe.address';

/// Delivery details, then payment with the backend's provider: the fake one
/// (demo buttons) or Stripe (the native payment sheet). With [orderId] it
/// resumes paying for an order already placed.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, this.orderId});

  final int? orderId;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final k in ['full_name', 'address_line1', 'address_line2', 'postal_code', 'city', 'country', 'phone']) k: TextEditingController(),
  };
  String _method = 'standard';
  Quote? _quote;
  _Stage _stage = _Stage.form;
  Order? _order;
  Checkout? _checkout;
  String? _error;
  bool _busy = false;
  Duration _left = Duration.zero;
  Timer? _timer;

  ShopApi get _api => ref.read(apiProvider);

  @override
  void initState() {
    super.initState();
    _restoreAddress();
    if (widget.orderId != null) {
      _stage = _Stage.loading;
      _resume(widget.orderId!);
    } else {
      _refreshQuote();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _restoreAddress() {
    final raw = ref.read(sharedPreferencesProvider).getString(_addressKey);
    final saved = raw == null ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
    for (final e in _fields.entries) {
      e.value.text = saved[e.key] as String? ?? '';
    }
    if (_fields['country']!.text.isEmpty) _fields['country']!.text = 'IT';
    final user = ref.read(authProvider).value;
    if (_fields['full_name']!.text.isEmpty && user != null) _fields['full_name']!.text = user.fullName;
  }

  Future<void> _refreshQuote() async {
    final items = ref.read(bagProvider);
    if (items.isEmpty) return;
    try {
      final q = await _api.quote(items.lines, _method);
      if (mounted) setState(() => _quote = q);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  Future<void> _place() async {
    if (!_form.currentState!.validate()) return;
    final address = {for (final e in _fields.entries) e.key: e.value.text.trim()};
    address['country'] = address['country']!.toUpperCase();
    await ref.read(sharedPreferencesProvider).setString(_addressKey, jsonEncode(address));
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _order = await _api.placeOrder(ref.read(bagProvider).lines, _method, address);
      await _startPayment();
    } catch (e) {
      if (statusOf(e) == 409) await _refreshQuote();
      setState(() => _error = errorMessage(e, 'The order could not be placed.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resume(int id) async {
    try {
      _order = await _api.order(id);
      if (_order!.isPaid) return _finish(_order!);
      if (!_order!.isPending || _order!.expiresAt.isBefore(DateTime.now())) return setState(() => _stage = _Stage.expired);
      await _startPayment();
    } catch (e) {
      setState(() {
        _error = errorMessage(e);
        _stage = _Stage.failed;
      });
    }
  }

  Future<void> _startPayment() async {
    _startCountdown(_order!.expiresAt);
    _checkout = await _api.checkout(_order!.id);
    setState(() => _stage = _Stage.paying);
  }

  void _startCountdown(DateTime expiresAt) {
    _timer?.cancel();
    void tick() {
      if (!mounted) return;
      final left = expiresAt.difference(DateTime.now());
      setState(() => _left = left.isNegative ? Duration.zero : left);
      if (left.isNegative && _stage == _Stage.paying) {
        _timer?.cancel();
        setState(() => _stage = _Stage.expired);
      }
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _payFake({required bool succeed}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await _api.completeFakePayment(_checkout!.paymentId, succeed: succeed);
      if (status == 'paid') return _finish(await _api.order(_order!.id));
      _error = 'Your card was declined. No money was taken. Try again.';
      _checkout = await _api.checkout(_order!.id); // a fresh attempt for the retry
    } catch (e) {
      _error = errorMessage(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payStripe() async {
    final checkout = _checkout!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      Stripe.publishableKey = checkout.publishableKey ?? '';
      await Stripe.instance.applySettings();
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: checkout.clientSecret,
          merchantDisplayName: merchantName,
          style: ThemeMode.light,
          appearance: const PaymentSheetAppearance(colors: PaymentSheetAppearanceColors(primary: AppColors.ink)),
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      // Stripe tells the backend through a webhook: wait for the confirmation
      setState(() => _stage = _Stage.confirming);
      for (var i = 0; i < 30; i++) {
        final order = await _api.order(_order!.id);
        if (order.isPaid) return _finish(order);
        if (!order.isPending) break;
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }
      setState(() {
        _stage = _Stage.failed;
        _error = 'Your payment went through, but the confirmation is taking longer than usual. Your order will appear in your account shortly.';
      });
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) _error = e.error.localizedMessage ?? 'The payment could not be completed.';
    } catch (e) {
      _error = errorMessage(e, 'The payment could not be completed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _finish(Order order) {
    _timer?.cancel();
    if (widget.orderId == null) ref.read(bagProvider.notifier).clear();
    ref.invalidate(myOrdersProvider);
    ref.invalidate(productsProvider);
    setState(() {
      _order = order;
      _stage = _Stage.done;
    });
  }

  Future<void> _back() async {
    // Leaving the payment step gives the stock back straight away
    final order = _order;
    if (order != null && _stage == _Stage.paying) {
      try {
        await _api.cancelOrder(order.id);
      } catch (_) {
        // Already expired: the stock is free either way
      }
    }
    _timer?.cancel();
    if (!mounted) return;
    if (widget.orderId != null) return context.pop();
    setState(() {
      _order = null;
      _checkout = null;
      _stage = _Stage.form;
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = _stage == _Stage.done;
    return PopScope(
      canPop: _stage != _Stage.confirming && _stage != _Stage.paying,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _stage == _Stage.paying) _back();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(done ? '' : _stage == _Stage.paying ? 'Payment' : 'Checkout'), automaticallyImplyLeading: !done),
        body: SafeArea(
          child: switch (_stage) {
            _Stage.loading => const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
            _Stage.form => _buildForm(),
            _Stage.paying => _buildPayment(),
            _Stage.confirming => const Message(icon: Icons.hourglass_top_rounded, text: 'Confirming your payment. This takes a few seconds.'),
            _Stage.expired => Message(
                icon: Icons.timer_off_outlined,
                text: 'Time is up. The pieces were released because the payment was not completed. Your bag is still there.',
                action: FilledButton(onPressed: () => context.go('/bag'), child: const Text('BACK TO BAG')),
              ),
            _Stage.failed => Message(
                icon: Icons.error_outline,
                text: _error ?? 'Something went wrong.',
                action: OutlinedButton(onPressed: () => context.go('/account'), child: const Text('YOUR ORDERS')),
              ),
            _Stage.done => _Done(order: _order!),
          },
        ),
      ),
    );
  }

  Widget _buildForm() {
    final fmt = ref.watch(fmtProvider);
    final items = ref.watch(bagProvider);
    final methods = ref.watch(shippingProvider).value ?? const <ShippingMethod>[];
    final q = _quote;
    if (items.isEmpty) {
      return Message(icon: Icons.shopping_bag_outlined, text: 'Your bag is empty.', action: OutlinedButton(onPressed: () => context.go('/shop'), child: const Text('SHOP')));
    }
    String? required(String? v) => (v ?? '').trim().isEmpty ? 'Required.' : null;

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text('Delivery', style: display(34)),
          const SizedBox(height: 18),
          TextFormField(controller: _fields['full_name'], decoration: const InputDecoration(labelText: 'Full name'), autofillHints: const [AutofillHints.name], validator: required),
          const SizedBox(height: 12),
          TextFormField(controller: _fields['address_line1'], decoration: const InputDecoration(labelText: 'Address'), autofillHints: const [AutofillHints.streetAddressLine1], validator: required),
          const SizedBox(height: 12),
          TextFormField(controller: _fields['address_line2'], decoration: const InputDecoration(labelText: 'Apartment, floor (optional)'), autofillHints: const [AutofillHints.streetAddressLine2]),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextFormField(controller: _fields['postal_code'], decoration: const InputDecoration(labelText: 'Postal code'), autofillHints: const [AutofillHints.postalCode], validator: required)),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: TextFormField(controller: _fields['city'], decoration: const InputDecoration(labelText: 'City'), autofillHints: const [AutofillHints.addressCity], validator: required)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _fields['country'],
                  decoration: const InputDecoration(labelText: 'Country code'),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 2,
                  validator: (v) => RegExp(r'^[A-Za-z]{2}$').hasMatch(v ?? '') ? null : 'Two letters, like IT.',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: TextFormField(controller: _fields['phone'], decoration: const InputDecoration(labelText: 'Phone (for the courier)'), keyboardType: TextInputType.phone, autofillHints: const [AutofillHints.telephoneNumber])),
            ],
          ),
          const SizedBox(height: 18),
          const Eyebrow('Delivery method'),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _method,
            onChanged: (v) {
              setState(() => _method = v!);
              _refreshQuote();
            },
            child: Column(
              children: [
                for (final m in methods)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(border: Border.all(color: _method == m.code ? AppColors.ink : AppColors.lineStrong)),
                    child: RadioListTile<String>(
                      value: m.code,
                      title: Text(m.name),
                      subtitle: Text('${m.when}. ${m.description}', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                      secondary: Text(_method == m.code && q != null ? (q.shipping == 0 ? 'Free' : fmt.money(q.shipping)) : (m.price == 0 ? 'Free' : fmt.money(m.price))),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Your order'),
          const SizedBox(height: 12),
          for (final item in items) ...[BagLine(item: item, editable: false), const SizedBox(height: 12)],
          const Divider(height: 20),
          _Row('Subtotal', fmt.money(q?.subtotal ?? items.subtotal)),
          _Row('Delivery', q == null ? '…' : (q.shipping == 0 ? 'Free' : fmt.money(q.shipping))),
          _Row('Total', fmt.money(q?.total ?? items.subtotal), strong: true),
          for (final p in q?.problems ?? const <String>[]) Text(p, style: const TextStyle(color: AppColors.accent, fontSize: 13)),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: AppColors.accent))],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy || (q?.problems.isNotEmpty ?? false) ? null : _place,
            child: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.paper)) : const Text('CONTINUE TO PAYMENT'),
          ),
          const SizedBox(height: 8),
          const Text('Your pieces are set aside for 15 minutes while you pay.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _buildPayment() {
    final fmt = ref.watch(fmtProvider);
    final o = _order!;
    final urgent = _left.inSeconds < 60;
    final clock = '${_left.inMinutes}:${(_left.inSeconds % 60).toString().padLeft(2, '0')}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          color: urgent ? AppColors.accent.withValues(alpha: 0.1) : AppColors.sunken,
          child: Row(
            children: [
              Icon(Icons.schedule, size: 20, color: urgent ? AppColors.accent : AppColors.ink),
              const SizedBox(width: 10),
              const Text('Your pieces are set aside for '),
              Text(clock, style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Eyebrow('Order ${o.reference}'),
        const SizedBox(height: 6),
        Text(fmt.money(o.total), style: display(48, weight: FontWeight.w300)),
        Text('${o.pieces} ${o.pieces == 1 ? 'piece' : 'pieces'}, ${o.shippingMethod.toLowerCase()} to ${o.fullName}', style: const TextStyle(color: AppColors.inkSoft)),
        const SizedBox(height: 28),
        if (_checkout?.provider == 'stripe')
          FilledButton(onPressed: _busy ? null : _payStripe, child: Text('PAY ${fmt.money(o.total)}'))
        else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(border: Border.all(color: AppColors.lineStrong)),
            child: const Text(
              'Demo payment. No card is charged and no money moves: this shop runs on the fake payment provider.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 14),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: _busy ? null : () => _payFake(succeed: true), child: Text('PAY ${fmt.money(o.total)}')),
          TextButton(onPressed: _busy ? null : () => _payFake(succeed: false), child: const Text('Simulate a declined card')),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.accent), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 8),
        TextButton(onPressed: _busy ? null : _back, child: const Text('Change delivery details')),
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

class _Done extends ConsumerWidget {
  const _Done({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authProvider).value?.firstName ?? '';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.ink)),
              child: const Icon(Icons.check, size: 30),
            ),
          ),
          const SizedBox(height: 24),
          Text('ORDER ${order.reference}', textAlign: TextAlign.center, style: eyebrow()),
          const SizedBox(height: 10),
          Text(name.isEmpty ? 'Thank you' : 'Thank you, $name', textAlign: TextAlign.center, style: display(40, weight: FontWeight.w300)),
          const SizedBox(height: 12),
          const Text(
            'We have your order and will send it within one working day. Follow it, cancel it before it ships or return pieces from your account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkSoft, height: 1.6),
          ),
          const SizedBox(height: 32),
          FilledButton(onPressed: () => context.go('/account/orders/${order.id}'), child: const Text('VIEW YOUR ORDER')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => context.go('/'), child: const Text('KEEP SHOPPING')),
        ],
      ),
    );
  }
}
