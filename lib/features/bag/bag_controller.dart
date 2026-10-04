import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

/// A line in the bag, with a snapshot of the product so the bag shows instantly.
/// Prices and stock are always checked again with the backend before paying.
class BagItem {
  const BagItem({
    required this.variant,
    required this.quantity,
    required this.slug,
    required this.name,
    required this.colour,
    required this.size,
    required this.image,
    required this.price,
  });

  factory BagItem.fromJson(Map<String, dynamic> j) => BagItem(
        variant: j['variant'] as int,
        quantity: j['quantity'] as int,
        slug: j['slug'] as String,
        name: j['name'] as String,
        colour: j['colour'] as String,
        size: j['size'] as String,
        image: j['image'] as String,
        price: (j['price'] as num).toDouble(),
      );

  final int variant;
  final int quantity;
  final String slug;
  final String name;
  final String colour;
  final String size;
  final String image;
  final double price;

  BagItem withQuantity(int q) => BagItem(variant: variant, quantity: q, slug: slug, name: name, colour: colour, size: size, image: image, price: price);

  Map<String, dynamic> toJson() =>
      {'variant': variant, 'quantity': quantity, 'slug': slug, 'name': name, 'colour': colour, 'size': size, 'image': image, 'price': price};
}

const maxQuantity = 10;

/// The bag, kept on the phone until checkout: no account needed to fill it.
final bagProvider = NotifierProvider<BagController, List<BagItem>>(BagController.new);

class BagController extends Notifier<List<BagItem>> {
  static const _key = 'wardrobe.bag';

  @override
  List<BagItem> build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).map((e) => BagItem.fromJson(e)).toList();
    } catch (_) {
      return const [];
    }
  }

  void _save(List<BagItem> items) {
    state = items;
    ref.read(sharedPreferencesProvider).setString(_key, jsonEncode([for (final i in items) i.toJson()]));
  }

  void add(BagItem item) {
    final existing = state.where((i) => i.variant == item.variant).firstOrNull;
    if (existing != null) {
      setQuantity(item.variant, existing.quantity + item.quantity);
    } else {
      _save([item, ...state]);
    }
  }

  void setQuantity(int variant, int quantity) {
    final q = quantity.clamp(0, maxQuantity);
    _save([for (final i in state) if (i.variant != variant) i else if (q > 0) i.withQuantity(q)]);
  }

  void remove(int variant) => setQuantity(variant, 0);

  void clear() => _save(const []);
}

final bagCountProvider = Provider<int>((ref) => ref.watch(bagProvider).fold(0, (n, i) => n + i.quantity));

extension BagLines on List<BagItem> {
  List<({int variant, int quantity})> get lines => [for (final i in this) (variant: i.variant, quantity: i.quantity)];
  double get subtotal => fold(0, (s, i) => s + i.price * i.quantity);
}
