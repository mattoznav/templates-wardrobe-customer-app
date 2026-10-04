/// Shapes returned by the wardrobe backend API.
library;

double _num(Object? v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

class Photo {
  const Photo({required this.url, required this.photographer, required this.photographerUrl, required this.sourceUrl});

  factory Photo.fromJson(Map<String, dynamic> j) => Photo(
        url: j['url'] as String,
        photographer: j['photographer'] as String? ?? '',
        photographerUrl: j['photographer_url'] as String? ?? '',
        sourceUrl: j['source_url'] as String? ?? '',
      );

  final String url;
  final String photographer;
  final String photographerUrl;
  final String sourceUrl;

  /// The photo from the Unsplash CDN, cropped to the size it is shown at.
  String sized(int width, [int? height]) {
    final h = height == null ? '' : '&h=$height&crop=faces,entropy';
    return '$url?w=$width$h&fit=crop&q=72&auto=format';
  }
}

class Store {
  const Store({required this.name, required this.tagline, required this.currency, required this.freeShippingOver, required this.returnWindowDays, required this.address, required this.openingHours});

  factory Store.fromJson(Map<String, dynamic> j) => Store(
        name: j['name'] as String,
        tagline: j['tagline'] as String? ?? '',
        currency: j['currency'] as String? ?? 'EUR',
        freeShippingOver: j['free_shipping_over'] == null ? null : _num(j['free_shipping_over']),
        returnWindowDays: j['return_window_days'] as int? ?? 30,
        address: '${j['address']}, ${j['postal_code']} ${j['city']}',
        openingHours: j['opening_hours'] as String? ?? '',
      );

  final String name;
  final String tagline;
  final String currency;
  final double? freeShippingOver;
  final int returnWindowDays;
  final String address;
  final String openingHours;
}

class Editorial {
  const Editorial({required this.title, required this.text, required this.alt, required this.image});

  factory Editorial.fromJson(Map<String, dynamic> j) =>
      Editorial(title: j['title'] as String? ?? '', text: j['text'] as String? ?? '', alt: j['alt'] as String? ?? '', image: Photo.fromJson(j['image']));

  final String title;
  final String text;
  final String alt;
  final Photo image;
}

class Category {
  const Category(this.slug, this.name);
  factory Category.fromJson(Map<String, dynamic> j) => Category(j['slug'] as String, j['name'] as String);
  final String slug;
  final String name;
}

class Colour {
  const Colour(this.slug, this.name, this.hex);
  factory Colour.fromJson(Map<String, dynamic> j) => Colour(j['slug'] as String, j['name'] as String, j['hex'] as String);
  final String slug;
  final String name;
  final String hex;

  int get value => int.parse('FF${hex.replaceFirst('#', '')}', radix: 16);
}

class ProductImage extends Photo {
  const ProductImage({required super.url, required super.photographer, required super.photographerUrl, required super.sourceUrl, required this.alt, this.colour});

  factory ProductImage.fromJson(Map<String, dynamic> j) {
    final p = Photo.fromJson(j);
    return ProductImage(url: p.url, photographer: p.photographer, photographerUrl: p.photographerUrl, sourceUrl: p.sourceUrl, alt: j['alt'] as String? ?? '', colour: j['colour'] as String?);
  }

  final String alt;
  final String? colour;
}

class Variant {
  const Variant({required this.id, required this.sku, required this.colour, required this.size, required this.stock});

  factory Variant.fromJson(Map<String, dynamic> j) =>
      Variant(id: j['id'] as int, sku: j['sku'] as String, colour: j['colour'] as String, size: j['size'] as String, stock: j['stock'] as int);

  final int id;
  final String sku;
  final String colour;
  final String size;
  final int stock;
}

class Product {
  const Product({
    required this.slug,
    required this.name,
    required this.department,
    required this.category,
    required this.categoryName,
    required this.description,
    required this.details,
    required this.composition,
    required this.care,
    required this.price,
    required this.compareAtPrice,
    required this.isNew,
    required this.popularity,
    required this.colours,
    required this.sizes,
    required this.inStock,
    required this.images,
    required this.variants,
    required this.collections,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        slug: j['slug'] as String,
        name: j['name'] as String,
        department: j['department'] as String,
        category: j['category'] as String,
        categoryName: j['category_name'] as String? ?? '',
        description: j['description'] as String? ?? '',
        details: (j['details'] as List? ?? []).cast<String>(),
        composition: j['composition'] as String? ?? '',
        care: j['care'] as String? ?? '',
        price: _num(j['price']),
        compareAtPrice: j['compare_at_price'] == null ? null : _num(j['compare_at_price']),
        isNew: j['is_new'] as bool? ?? false,
        popularity: j['popularity'] as int? ?? 0,
        colours: (j['colours'] as List).map((e) => Colour.fromJson(e)).toList(),
        sizes: (j['sizes'] as List).map((e) => (code: e['code'] as String, label: e['label'] as String)).toList(),
        inStock: j['in_stock'] as bool? ?? true,
        images: (j['images'] as List).map((e) => ProductImage.fromJson(e)).toList(),
        variants: (j['variants'] as List).map((e) => Variant.fromJson(e)).toList(),
        collections: (j['collections'] as List? ?? []).cast<String>(),
      );

  final String slug;
  final String name;
  final String department;
  final String category;
  final String categoryName;
  final String description;
  final List<String> details;
  final String composition;
  final String care;
  final double price;
  final double? compareAtPrice;
  final bool isNew;
  final int popularity;
  final List<Colour> colours;
  final List<({String code, String label})> sizes;
  final bool inStock;
  final List<ProductImage> images;
  final List<Variant> variants;
  final List<String> collections;

  bool get onSale => compareAtPrice != null;
  bool get oneSize => sizes.length == 1 && sizes.first.code == 'one-size';

  /// The shop's sections: accessories group bags, shoes and small things.
  String get section {
    if (const {'bags', 'shoes', 'accessories', 'jewellery'}.contains(category)) return 'accessories';
    return department == 'men' ? 'men' : 'women';
  }

  bool inSection(String s) => section == s || (s != 'accessories' && department == 'unisex' && section != 'accessories');

  Variant? variantFor(String colour, String size) {
    for (final v in variants) {
      if (v.colour == colour && v.size == size) return v;
    }
    return null;
  }

  ProductImage? imageFor(String colour) {
    for (final i in images) {
      if (i.colour == colour) return i;
    }
    return images.isEmpty ? null : images.first;
  }
}

class Collection {
  const Collection({required this.slug, required this.title, required this.subtitle, required this.description, required this.image, required this.alt, required this.count});

  factory Collection.fromJson(Map<String, dynamic> j) => Collection(
        slug: j['slug'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String? ?? '',
        description: j['description'] as String? ?? '',
        image: Photo.fromJson(j['image']),
        alt: j['alt'] as String? ?? '',
        count: j['product_count'] as int? ?? 0,
      );

  final String slug;
  final String title;
  final String subtitle;
  final String description;
  final Photo image;
  final String alt;
  final int count;
}

class ShippingMethod {
  const ShippingMethod({required this.code, required this.name, required this.description, required this.price, required this.daysMin, required this.daysMax});

  factory ShippingMethod.fromJson(Map<String, dynamic> j) => ShippingMethod(
        code: j['code'] as String,
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        price: _num(j['price']),
        daysMin: j['days_min'] as int? ?? 0,
        daysMax: j['days_max'] as int? ?? 0,
      );

  final String code;
  final String name;
  final String description;
  final double price;
  final int daysMin;
  final int daysMax;

  String get when => daysMax <= 1 ? (daysMin == 0 ? 'Today' : 'Next working day') : '$daysMin to $daysMax working days';
}

class Quote {
  const Quote({required this.lines, required this.subtotal, required this.shipping, required this.total, required this.problems});

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        lines: (j['lines'] as List).map((e) => (variant: e['variant'] as int, available: e['available'] as int, unitPrice: _num(e['unit_price']))).toList(),
        subtotal: _num(j['subtotal']),
        shipping: _num(j['shipping']),
        total: _num(j['total']),
        problems: (j['problems'] as List).cast<String>(),
      );

  final List<({int variant, int available, double unitPrice})> lines;
  final double subtotal;
  final double shipping;
  final double total;
  final List<String> problems;
}

class OrderLine {
  const OrderLine({required this.id, required this.productName, required this.productSlug, required this.colour, required this.size, required this.imageUrl, required this.unitPrice, required this.quantity, required this.returnable});

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        id: j['id'] as int,
        productName: j['product_name'] as String,
        productSlug: j['product_slug'] as String,
        colour: j['colour'] as String,
        size: j['size'] as String,
        imageUrl: j['image_url'] as String? ?? '',
        unitPrice: _num(j['unit_price']),
        quantity: j['quantity'] as int,
        returnable: j['returnable'] as int? ?? 0,
      );

  final int id;
  final String productName;
  final String productSlug;
  final String colour;
  final String size;
  final String imageUrl;
  final double unitPrice;
  final int quantity;
  final int returnable;
}

class Order {
  const Order({
    required this.id,
    required this.reference,
    required this.status,
    required this.statusLabel,
    required this.fullName,
    required this.address,
    required this.shippingMethod,
    required this.subtotal,
    required this.shipping,
    required this.total,
    required this.lines,
    required this.expiresAt,
    required this.createdAt,
    required this.paidAt,
    required this.shippedAt,
    required this.deliveredAt,
    required this.trackingNumber,
    required this.canCancel,
    required this.canReturn,
    required this.returnDeadline,
    required this.returns,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as int,
        reference: j['reference'] as String,
        status: j['status'] as String,
        statusLabel: j['status_label'] as String,
        fullName: j['full_name'] as String,
        address: [j['address_line1'], if ((j['address_line2'] as String? ?? '').isNotEmpty) j['address_line2'], '${j['postal_code']} ${j['city']}', j['country']].join(', '),
        shippingMethod: j['shipping_method']['name'] as String,
        subtotal: _num(j['subtotal']),
        shipping: _num(j['shipping']),
        total: _num(j['total']),
        lines: (j['lines'] as List).map((e) => OrderLine.fromJson(e)).toList(),
        expiresAt: DateTime.parse(j['expires_at'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
        paidAt: _date(j['paid_at']),
        shippedAt: _date(j['shipped_at']),
        deliveredAt: _date(j['delivered_at']),
        trackingNumber: j['tracking_number'] as String? ?? '',
        canCancel: j['can_cancel'] as bool? ?? false,
        canReturn: j['can_return'] as bool? ?? false,
        returnDeadline: _date(j['return_deadline']),
        returns: (j['returns'] as List? ?? []).map((e) => (reference: e['reference'] as String, status: e['status'] as String)).toList(),
      );

  final int id;
  final String reference;
  final String status;
  final String statusLabel;
  final String fullName;
  final String address;
  final String shippingMethod;
  final double subtotal;
  final double shipping;
  final double total;
  final List<OrderLine> lines;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final String trackingNumber;
  final bool canCancel;
  final bool canReturn;
  final DateTime? returnDeadline;
  final List<({String reference, String status})> returns;

  bool get isPending => status == 'pending';
  bool get isPaid => const {'paid', 'shipped', 'delivered'}.contains(status);
  int get pieces => lines.fold(0, (n, l) => n + l.quantity);
}

class Checkout {
  const Checkout({required this.paymentId, required this.provider, required this.clientSecret, this.publishableKey});

  factory Checkout.fromJson(Map<String, dynamic> j) => Checkout(
        paymentId: j['payment_id'] as int,
        provider: j['provider'] as String,
        clientSecret: j['client_secret'] as String,
        publishableKey: j['publishable_key'] as String?,
      );

  final int paymentId;
  final String provider;
  final String clientSecret;
  final String? publishableKey;
}

class User {
  const User({required this.email, required this.firstName, required this.lastName});
  factory User.fromJson(Map<String, dynamic> j) => User(email: j['email'] as String, firstName: j['first_name'] as String? ?? '', lastName: j['last_name'] as String? ?? '');
  final String email;
  final String firstName;
  final String lastName;

  String get fullName => '$firstName $lastName'.trim();
}
