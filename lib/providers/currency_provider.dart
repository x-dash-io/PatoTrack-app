import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyOption {
  const CurrencyOption({
    required this.code,
    required this.symbol,
    required this.label,
    required this.locale,
  });

  final String code;
  final String symbol;
  final String label;
  final String locale;
}

class CurrencyProvider extends ChangeNotifier {
  static const String _currencyCodePreferenceKey = 'currency_code';
  static const String _legacyCurrencySymbolPreferenceKey = 'currency';

  static const List<CurrencyOption> _supportedOptions = <CurrencyOption>[
    CurrencyOption(
      code: 'KES',
      symbol: 'KSh',
      label: 'Kenyan Shilling',
      locale: 'en_KE',
    ),
    CurrencyOption(
      code: 'USD',
      symbol: '4',
      label: 'US Dollar',
      locale: 'en_US',
    ),
    CurrencyOption(
      code: 'EUR',
      symbol: 'EUR',
      label: 'Euro',
      locale: 'en_IE',
    ),
    CurrencyOption(
      code: 'GBP',
      symbol: 'GBP',
      label: 'British Pound',
      locale: 'en_GB',
    ),
  ];

  static final Map<String, CurrencyOption> _optionsByCode =
      <String, CurrencyOption>{
    for (final option in _supportedOptions) option.code: option,
  };

  static final Map<String, CurrencyOption> _optionsBySymbol =
      <String, CurrencyOption>{
    for (final option in _supportedOptions) option.symbol: option,
  };

  CurrencyOption _selectedCurrency = _supportedOptions.first;
  bool _isLoaded = false;

  CurrencyProvider() {
    _loadPreferences();
  }

  bool get isLoaded => _isLoaded;

  CurrencyOption get selectedCurrency => _selectedCurrency;

  String get code => _selectedCurrency.code;

  String get symbol => _selectedCurrency.symbol;

  String get label => _selectedCurrency.label;

  List<CurrencyOption> get options =>
      List<CurrencyOption>.unmodifiable(_supportedOptions);

  Future<void> setCurrency(String code) async {
    final option = _optionsByCode[code];
    if (option == null || option.code == _selectedCurrency.code) {
      return;
    }

    _selectedCurrency = option;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyCodePreferenceKey, option.code);
    // Keep legacy key updated so older screens remain consistent while
    // migrations complete.
    await prefs.setString(_legacyCurrencySymbolPreferenceKey, option.symbol);
  }

  String format(
    num value, {
    int decimalDigits = 0,
    bool includePositiveSign = false,
  }) {
    final formatter = NumberFormat.currency(
      locale: _selectedCurrency.locale,
      symbol: '',
      decimalDigits: decimalDigits,
    );

    final absFormatted = formatter.format(value.abs()).trim();
    final prefix = value < 0
        ? '-'
        : includePositiveSign
            ? '+'
            : '';

    return '$prefix${_selectedCurrency.symbol} $absFormatted';
  }

  String formatCompact(num value) {
    final formatter = NumberFormat.compact(locale: _selectedCurrency.locale);
    return '${_selectedCurrency.symbol} ${formatter.format(value)}';
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final storedCode = prefs.getString(_currencyCodePreferenceKey);

    CurrencyOption? option;
    if (storedCode != null) {
      option = _optionsByCode[storedCode];
    }

    if (option == null) {
      final legacySymbol = prefs.getString(_legacyCurrencySymbolPreferenceKey);
      if (legacySymbol != null) {
        option = _optionsBySymbol[legacySymbol];
      }
    }

    if (option != null) {
      _selectedCurrency = option;
    }

    _isLoaded = true;
    notifyListeners();
  }
}
