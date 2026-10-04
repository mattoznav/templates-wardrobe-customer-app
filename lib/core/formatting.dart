import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'api_client.dart';
import 'models.dart';

final storeProvider = FutureProvider<Store>((ref) => ref.watch(apiProvider).store());

/// Prices in the shop's currency and dates in a fixed English format, whatever the phone's settings.
final fmtProvider = Provider<Fmt>((ref) => Fmt(ref.watch(storeProvider).value?.currency ?? 'EUR'));

class Fmt {
  const Fmt(this.currency);

  final String currency;
  static const _locale = 'en_GB';

  String money(num amount) {
    final whole = amount == amount.roundToDouble();
    return NumberFormat.currency(locale: _locale, name: currency, symbol: NumberFormat.simpleCurrency(locale: _locale, name: currency).currencySymbol, decimalDigits: whole ? 0 : 2)
        .format(amount);
  }

  String date(DateTime moment) => DateFormat('d MMMM y', _locale).format(moment.toLocal());

  String short(DateTime moment) => DateFormat('d MMM', _locale).format(moment.toLocal());
}
