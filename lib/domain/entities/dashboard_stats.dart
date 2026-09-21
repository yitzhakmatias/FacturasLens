class SpendSlice {
  const SpendSlice({required this.label, required this.amount});

  final String label;
  final double amount;
}

class DashboardStats {
  const DashboardStats({
    this.monthTotal = 0,
    this.previousMonthTotal = 0,
    this.averageTicket = 0,
    this.invoiceCount = 0,
    this.pendingCount = 0,
    this.allTimeTotal = 0,
    this.monthTax = 0,
    this.highestInvoice,
    this.byCategory = const [],
    this.bySupplier = const [],
    this.monthlyTrend = const [],
  });

  final double monthTotal;
  final double previousMonthTotal;
  final double averageTicket;
  final int invoiceCount;
  final int pendingCount;

  /// Suma histórica de todas las facturas verificadas (todos los meses).
  final double allTimeTotal;

  /// Impuesto (IVA) acumulado en las facturas verificadas del mes actual.
  final double monthTax;

  /// La factura verificada de mayor monto del mes actual, si existe.
  final SpendSlice? highestInvoice;

  final List<SpendSlice> byCategory;
  final List<SpendSlice> bySupplier;

  /// Gasto total verificado por mes, de los últimos 6 meses (incluye el
  /// actual), en orden cronológico. Los meses sin facturas aparecen con 0.
  final List<SpendSlice> monthlyTrend;

  double? get monthChangePercent {
    if (previousMonthTotal == 0) return null;
    return ((monthTotal - previousMonthTotal) / previousMonthTotal) * 100;
  }
}
