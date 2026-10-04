import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'models.dart';

/// Turn any API failure into one sentence for the user.
String errorMessage(Object error, [String fallback = 'Something went wrong. Try again.']) {
  if (error is DioException) {
    if (error.type == DioExceptionType.connectionError || error.type == DioExceptionType.connectionTimeout) {
      return 'The shop cannot be reached. Check your connection.';
    }
    final data = error.response?.data;
    if (data is Map) {
      if (data['detail'] is String) return data['detail'] as String;
      Iterable<String> flat(Object? v) => v is String ? [v] : v is List ? v.expand(flat) : v is Map ? v.values.expand(flat) : const [];
      final messages = data.values.expand(flat);
      if (messages.isNotEmpty) return messages.join(' ');
    }
  }
  return fallback;
}

int? statusOf(Object error) => error is DioException ? error.response?.statusCode : null;

class Tokens {
  const Tokens(this.access, this.refresh);
  final String access;
  final String refresh;

  Map<String, String> toJson() => {'access': access, 'refresh': refresh};
}

/// Stores the JWT pair. Kept in shared preferences so the session survives restarts.
class TokenStore {
  TokenStore(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'wardrobe.auth';

  Tokens? read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return Tokens(json['access'] as String, json['refresh'] as String);
  }

  Future<void> write(Tokens? tokens) =>
      tokens == null ? _prefs.remove(_key) : _prefs.setString(_key, jsonEncode(tokens.toJson()));
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('Overridden in main()'));

final tokenStoreProvider = Provider((ref) => TokenStore(ref.watch(sharedPreferencesProvider)));

/// Called when the refresh token is no longer valid, so the app can sign out.
final sessionExpiredProvider = NotifierProvider<SessionExpired, int>(SessionExpired.new);

class SessionExpired extends Notifier<int> {
  @override
  int build() => 0;
  void signal() => state++;
}

final dioProvider = Provider<Dio>((ref) {
  final store = ref.watch(tokenStoreProvider);
  final dio = Dio(BaseOptions(baseUrl: apiUrl, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 20)));

  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) {
        final tokens = store.read();
        if (tokens != null && !options.path.startsWith('/auth/token')) {
          options.headers['Authorization'] = 'Bearer ${tokens.access}';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final tokens = store.read();
        final retried = error.requestOptions.extra['retried'] == true;
        if (error.response?.statusCode != 401 || tokens == null || retried || error.requestOptions.path.startsWith('/auth/token')) {
          return handler.next(error);
        }
        try {
          // Refresh once, then replay the original request with the new token
          final res = await Dio(BaseOptions(baseUrl: apiUrl)).post('/auth/token/refresh/', data: {'refresh': tokens.refresh});
          final fresh = Tokens(res.data['access'] as String, (res.data['refresh'] as String?) ?? tokens.refresh);
          await store.write(fresh);
          final request = error.requestOptions
            ..headers['Authorization'] = 'Bearer ${fresh.access}'
            ..extra['retried'] = true;
          handler.resolve(await dio.fetch(request));
        } catch (_) {
          await store.write(null);
          ref.read(sessionExpiredProvider.notifier).signal();
          handler.next(error);
        }
      },
    ),
  );
  return dio;
});

/// Typed access to every endpoint the app uses.
class ShopApi {
  ShopApi(this._dio);
  final Dio _dio;

  List<T> _list<T>(Object? data, T Function(Map<String, dynamic>) parse) {
    final items = data is Map ? data['results'] as List : data as List;
    return items.map((e) => parse(e as Map<String, dynamic>)).toList();
  }

  Future<Store> store() async => Store.fromJson((await _dio.get('/store/')).data);

  Future<Map<String, Editorial>> editorial() async {
    final data = (await _dio.get('/editorial/')).data as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, Editorial.fromJson(v)));
  }

  Future<List<Product>> products([Map<String, String> filters = const {}]) async =>
      _list((await _dio.get('/products/', queryParameters: filters)).data, Product.fromJson);

  Future<Product> product(String slug) async => Product.fromJson((await _dio.get('/products/$slug/')).data);

  Future<List<Category>> categories() async => _list((await _dio.get('/categories/')).data, Category.fromJson);

  Future<List<Collection>> collections() async => _list((await _dio.get('/collections/')).data, Collection.fromJson);

  Future<List<ShippingMethod>> shippingMethods() async => _list((await _dio.get('/shipping-methods/')).data, ShippingMethod.fromJson);

  Future<Quote> quote(List<({int variant, int quantity})> items, String? method) async {
    final res = await _dio.post('/bag/quote/', data: {
      'items': [for (final i in items) {'variant': i.variant, 'quantity': i.quantity}],
      'shipping_method': ?method,
    });
    return Quote.fromJson(res.data);
  }

  Future<Tokens> signIn(String email, String password) async {
    final res = await _dio.post('/auth/token/', data: {'email': email, 'password': password});
    return Tokens(res.data['access'] as String, res.data['refresh'] as String);
  }

  Future<Tokens> register({required String email, required String password, required String firstName, required String lastName}) async {
    final res = await _dio.post('/auth/register/', data: {'email': email, 'password': password, 'first_name': firstName, 'last_name': lastName});
    return Tokens(res.data['access'] as String, res.data['refresh'] as String);
  }

  Future<User> me() async => User.fromJson((await _dio.get('/auth/me/')).data);

  Future<Order> placeOrder(List<({int variant, int quantity})> items, String method, Map<String, String> address) async {
    final res = await _dio.post('/orders/', data: {
      'items': [for (final i in items) {'variant': i.variant, 'quantity': i.quantity}],
      'shipping_method': method,
      'address': address,
    });
    return Order.fromJson(res.data);
  }

  Future<Order> order(int id) async => Order.fromJson((await _dio.get('/orders/$id/')).data);

  Future<List<Order>> myOrders() async => _list((await _dio.get('/orders/')).data, Order.fromJson);

  Future<Order> cancelOrder(int id) async => Order.fromJson((await _dio.post('/orders/$id/cancel/')).data);

  Future<Checkout> checkout(int order) async => Checkout.fromJson((await _dio.post('/orders/$order/checkout/')).data);

  Future<String> completeFakePayment(int paymentId, {bool succeed = true}) async {
    final res = await _dio.post('/payments/fake/complete/', data: {'payment_id': paymentId, 'outcome': succeed ? 'succeeded' : 'failed'});
    return res.data['order_status'] as String;
  }

  Future<void> requestReturn(int order, Map<int, int> lines, String reason, String note) => _dio.post('/returns/', data: {
        'order': order,
        'lines': [for (final e in lines.entries) {'order_line': e.key, 'quantity': e.value}],
        'reason': reason,
        'note': note,
      });
}

final apiProvider = Provider((ref) => ShopApi(ref.watch(dioProvider)));
