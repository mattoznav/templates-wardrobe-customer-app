import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobe_app/core/models.dart';

void main() {
  final json = {
    'slug': 'leather-tote',
    'name': 'Leather Tote',
    'department': 'unisex',
    'category': 'bags',
    'category_name': 'Bags',
    'description': '',
    'details': <String>[],
    'composition': '',
    'care': '',
    'price': '285.00',
    'compare_at_price': null,
    'is_new': false,
    'popularity': 1,
    'colours': [
      {'slug': 'cognac', 'name': 'Cognac', 'hex': '#94552b'},
    ],
    'sizes': [
      {'code': 'one-size', 'label': 'One size'},
    ],
    'in_stock': true,
    'images': [
      {'url': 'https://images.unsplash.com/photo-1', 'alt': 'Tote', 'colour': 'cognac', 'photographer': 'A', 'photographer_url': 'x', 'source_url': 'y'},
    ],
    'variants': [
      {'id': 7, 'sku': 'HD-1', 'colour': 'cognac', 'size': 'one-size', 'stock': 3},
    ],
    'collections': <String>[],
  };

  test('parses a product and finds its variants', () {
    final p = Product.fromJson(json);
    expect(p.price, 285);
    expect(p.oneSize, isTrue);
    expect(p.section, 'accessories');
    expect(p.variantFor('cognac', 'one-size')?.stock, 3);
    expect(p.colours.first.value, 0xFF94552B);
  });

  test('sizes photos for the CDN', () {
    final p = Product.fromJson(json);
    expect(p.images.first.sized(300, 400), contains('w=300&h=400'));
  });

  test('unisex clothes show in both departments', () {
    final tee = Product.fromJson({...json, 'category': 'tops'});
    expect(tee.inSection('women') && tee.inSection('men'), isTrue);
    expect(tee.inSection('accessories'), isFalse);
  });
}
