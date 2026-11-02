/// Currencies the user can pick in Setup and Settings.
class Currency {
  const Currency(this.code, this.symbol, this.name);

  final String code;
  final String symbol;
  final String name;
}

const String kDefaultCurrencyCode = 'INR';

/// Popular ones first (Armenian dram on top), then A to Z by code.
const List<Currency> kCurrencies = [
  Currency('AMD', '֏', 'Armenian Dram'),
  Currency('INR', '₹', 'Indian Rupee'),
  Currency('USD', r'$', 'US Dollar'),
  Currency('EUR', '€', 'Euro'),
  Currency('RUB', '₽', 'Russian Ruble'),
  Currency('GBP', '£', 'British Pound'),
  Currency('AED', 'AED', 'UAE Dirham'),
  Currency('GEL', '₾', 'Georgian Lari'),
  Currency('AFN', '؋', 'Afghan Afghani'),
  Currency('ALL', 'L', 'Albanian Lek'),
  Currency('ARS', r'AR$', 'Argentine Peso'),
  Currency('AUD', r'A$', 'Australian Dollar'),
  Currency('AZN', '₼', 'Azerbaijani Manat'),
  Currency('BAM', 'KM', 'Bosnian Mark'),
  Currency('BDT', '৳', 'Bangladeshi Taka'),
  Currency('BGN', 'лв', 'Bulgarian Lev'),
  Currency('BHD', 'BHD', 'Bahraini Dinar'),
  Currency('BRL', r'R$', 'Brazilian Real'),
  Currency('BYN', 'Br', 'Belarusian Ruble'),
  Currency('CAD', r'C$', 'Canadian Dollar'),
  Currency('CHF', 'CHF', 'Swiss Franc'),
  Currency('CLP', r'CL$', 'Chilean Peso'),
  Currency('CNY', '¥', 'Chinese Yuan'),
  Currency('COP', r'COL$', 'Colombian Peso'),
  Currency('CZK', 'Kč', 'Czech Koruna'),
  Currency('DKK', 'kr', 'Danish Krone'),
  Currency('DZD', 'DA', 'Algerian Dinar'),
  Currency('EGP', r'E£', 'Egyptian Pound'),
  Currency('ETB', 'Br', 'Ethiopian Birr'),
  Currency('GHS', 'GH₵', 'Ghanaian Cedi'),
  Currency('HKD', r'HK$', 'Hong Kong Dollar'),
  Currency('HUF', 'Ft', 'Hungarian Forint'),
  Currency('IDR', 'Rp', 'Indonesian Rupiah'),
  Currency('ILS', '₪', 'Israeli Shekel'),
  Currency('IQD', 'IQD', 'Iraqi Dinar'),
  Currency('IRR', 'IRR', 'Iranian Rial'),
  Currency('ISK', 'kr', 'Icelandic Krona'),
  Currency('JOD', 'JD', 'Jordanian Dinar'),
  Currency('JPY', '¥', 'Japanese Yen'),
  Currency('KES', 'KSh', 'Kenyan Shilling'),
  Currency('KGS', 'KGS', 'Kyrgyzstani Som'),
  Currency('KRW', '₩', 'South Korean Won'),
  Currency('KWD', 'KD', 'Kuwaiti Dinar'),
  Currency('KZT', '₸', 'Kazakhstani Tenge'),
  Currency('LKR', 'Rs', 'Sri Lankan Rupee'),
  Currency('MAD', 'MAD', 'Moroccan Dirham'),
  Currency('MDL', 'L', 'Moldovan Leu'),
  Currency('MKD', 'ден', 'Macedonian Denar'),
  Currency('MMK', 'K', 'Myanmar Kyat'),
  Currency('MXN', r'Mex$', 'Mexican Peso'),
  Currency('MYR', 'RM', 'Malaysian Ringgit'),
  Currency('NGN', '₦', 'Nigerian Naira'),
  Currency('NOK', 'kr', 'Norwegian Krone'),
  Currency('NPR', 'Rs', 'Nepalese Rupee'),
  Currency('NZD', r'NZ$', 'New Zealand Dollar'),
  Currency('OMR', 'OMR', 'Omani Rial'),
  Currency('PEN', 'S/', 'Peruvian Sol'),
  Currency('PHP', '₱', 'Philippine Peso'),
  Currency('PKR', 'Rs', 'Pakistani Rupee'),
  Currency('PLN', 'zł', 'Polish Zloty'),
  Currency('QAR', 'QR', 'Qatari Riyal'),
  Currency('RON', 'lei', 'Romanian Leu'),
  Currency('RSD', 'din', 'Serbian Dinar'),
  Currency('SAR', 'SAR', 'Saudi Riyal'),
  Currency('SEK', 'kr', 'Swedish Krona'),
  Currency('SGD', r'S$', 'Singapore Dollar'),
  Currency('THB', '฿', 'Thai Baht'),
  Currency('TJS', 'TJS', 'Tajikistani Somoni'),
  Currency('TMT', 'TMT', 'Turkmenistani Manat'),
  Currency('TRY', '₺', 'Turkish Lira'),
  Currency('TWD', r'NT$', 'New Taiwan Dollar'),
  Currency('UAH', '₴', 'Ukrainian Hryvnia'),
  Currency('UGX', 'USh', 'Ugandan Shilling'),
  Currency('UZS', 'UZS', 'Uzbekistani Som'),
  Currency('VND', '₫', 'Vietnamese Dong'),
  Currency('ZAR', 'R', 'South African Rand'),
];

Currency currencyByCode(String code) {
  for (final c in kCurrencies) {
    if (c.code == code) return c;
  }
  return kCurrencies.firstWhere((c) => c.code == kDefaultCurrencyCode);
}

bool isKnownCurrency(String code) => kCurrencies.any((c) => c.code == code);

/// Symbol plus a space when the symbol contains Latin letters ("AED 500"),
/// otherwise just the symbol ("₹500").
String symbolPrefix(String symbol) =>
    RegExp(r'[A-Za-z]').hasMatch(symbol) ? '$symbol ' : symbol;
