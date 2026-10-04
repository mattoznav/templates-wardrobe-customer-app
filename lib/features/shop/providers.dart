import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';

/// The whole catalogue. It is small, so the app loads it once and filters on the phone.
final productsProvider = FutureProvider<List<Product>>((ref) => ref.watch(apiProvider).products());

final productProvider = FutureProvider.autoDispose.family<Product, String>((ref, slug) => ref.watch(apiProvider).product(slug));

final categoriesProvider = FutureProvider<List<Category>>((ref) => ref.watch(apiProvider).categories());

final collectionsProvider = FutureProvider<List<Collection>>((ref) => ref.watch(apiProvider).collections());

final editorialProvider = FutureProvider<Map<String, Editorial>>((ref) => ref.watch(apiProvider).editorial());

final shippingProvider = FutureProvider<List<ShippingMethod>>((ref) => ref.watch(apiProvider).shippingMethods());
