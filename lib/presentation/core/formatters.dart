import 'package:intl/intl.dart';

abstract final class AppFormatters {
  static final _currency = NumberFormat.currency(
    locale: 'es_BO',
    symbol: 'Bs',
    decimalDigits: 2,
  );
  static final _date = DateFormat('dd MMM yyyy', 'es');
  static final _shortDate = DateFormat('dd/MM/yyyy');

  static String money(num value) => _currency.format(value);
  static String date(DateTime value) => _date.format(value);
  static String shortDate(DateTime value) => _shortDate.format(value);
}
