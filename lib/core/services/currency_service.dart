import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_cache_service.dart';

class Currency {
  final String code;
  final String symbol;
  final String name;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
  });
}

const availableCurrencies = [
  Currency(code: 'PHP', symbol: '₱', name: 'Philippine Peso'),
  Currency(code: 'USD', symbol: '\$', name: 'US Dollar'),
  Currency(code: 'EUR', symbol: '€', name: 'Euro'),
  Currency(code: 'GBP', symbol: '£', name: 'British Pound'),
  Currency(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
  Currency(code: 'KRW', symbol: '₩', name: 'Korean Won'),
  Currency(code: 'CNY', symbol: '¥', name: 'Chinese Yuan'),
  Currency(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
  Currency(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar'),
  Currency(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar'),
  Currency(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar'),
  Currency(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham'),
];

const defaultCurrency = Currency(
  code: 'PHP',
  symbol: '₱',
  name: 'Philippine Peso',
);

class CurrencyNotifier extends StateNotifier<Currency> {
  final LocalCacheService _cache;

  CurrencyNotifier(this._cache) : super(defaultCurrency) {
    _load();
  }

  void _load() {
    final code = _cache.getSetting<String>('currency_code');
    if (code != null) {
      final found = availableCurrencies
          .where((c) => c.code == code)
          .firstOrNull;
      if (found != null) {
        state = found;
      }
    }
  }

  Future<void> setCurrency(Currency currency) async {
    state = currency;
    await _cache.saveSetting('currency_code', currency.code);
  }
}

final currencyProvider = StateNotifierProvider<CurrencyNotifier, Currency>((
  ref,
) {
  final cache = ref.watch(localCacheServiceProvider);
  return CurrencyNotifier(cache);
});

String formatCurrency(double amount, Currency currency) {
  return '${currency.symbol}${amount.toStringAsFixed(2)}';
}
