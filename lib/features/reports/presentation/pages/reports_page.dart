import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database_helper.dart';
import '../../../pos/domain/entities/sale.dart';
import '../../../pos/data/repositories/pos_repository_impl.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../../core/utils/excel_export_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late Future<List<Sale>> _futureSales;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  void _loadSales() {
    // using PosRepository directly for simplicity in the reports screen without full BLoC overhead
    final repo = PosRepositoryImpl(databaseHelper: DatabaseHelper());
    setState(() {
      _futureSales = repo.getSales().then(
        (result) => result.fold(
          (failure) => throw Exception(failure.message),
          (sales) => sales,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes e Historial de Ventas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Exportar a Excel',
            onPressed: () async {
              final sales = await _futureSales;
              if (sales.isNotEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Generando Excel...')),
                  );
                }
                final path = await ExcelExportService.exportSales(sales);
                if (mounted && path != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reporte exportado: $path'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSales),
        ],
      ),
      body: FutureBuilder<List<Sale>>(
        future: _futureSales,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar ventas: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          var sales = snapshot.data ?? [];
          final authState = context.read<AuthBloc>().state;
          if (authState is Authenticated &&
              authState.user.role == UserRole.employee) {
            sales = sales
                .where((s) => s.userName == authState.user.name)
                .toList();
          }

          if (sales.isEmpty) {
            return const Center(
              child: Text(
                'No hay ventas registradas.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          final today = DateTime.now();
          final todaySales = sales
              .where(
                (s) =>
                    s.date.year == today.year &&
                    s.date.month == today.month &&
                    s.date.day == today.day,
              )
              .toList();

          final totalRevenueToday = todaySales.fold<double>(
            0,
            (sum, sale) => sum + sale.total,
          );

          final Map<String, double> revenueByBarber = {};
          final Map<String, int> salesByBarber = {};
          for (var sale in todaySales) {
            final name = sale.userName;
            revenueByBarber[name] = (revenueByBarber[name] ?? 0) + sale.total;
            salesByBarber[name] = (salesByBarber[name] ?? 0) + 1;
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'HOY',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.grey,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              _buildSummaryCards(todaySales.length, totalRevenueToday),
              if (revenueByBarber.isNotEmpty)
                _buildBarberMetrics(revenueByBarber, salesByBarber),
              const Padding(
                padding: EdgeInsets.only(top: 24.0, left: 16.0, right: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'INGRESOS ÚLTIMOS 7 DÍAS',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.grey,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              _buildWeeklyChart(sales),
              const Padding(
                padding: EdgeInsets.only(
                  top: 16.0,
                  left: 16.0,
                  right: 16.0,
                  bottom: 8.0,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'HISTORIAL DE VENTAS',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.grey,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const Divider(),
              ...sales.map((sale) => _SaleCard(sale: sale)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(int totalSales, double totalRevenue) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: const Color(0xFFC5A028).withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      color: Color(0xFFC5A028),
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Ventas',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[300]
                            : Colors.grey[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalSales',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFC5A028),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.green.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.green,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ingresos',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[300]
                            : Colors.grey[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${totalRevenue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarberMetrics(
    Map<String, double> revenueMap,
    Map<String, int> salesCountMap,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Métricas por Colaborador',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const Divider(height: 1),
          ...revenueMap.entries.map((entry) {
            final name = entry.key;
            final rev = entry.value;
            final count = salesCountMap[name] ?? 0;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFC5A028).withOpacity(0.1),
                child: const Icon(Icons.person, color: Color(0xFFC5A028)),
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('$count ${count == 1 ? 'venta' : 'ventas'} hoy'),
              trailing: Text(
                '\$${rev.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Color(0xFFC5A028),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(List<Sale> allSales) {
    if (allSales.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final List<double> weeklyRevenue = List.filled(7, 0.0);
    final List<String> days = List.filled(7, '');

    double maxRevenue = 0.0;

    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: 6 - i));
      days[i] = DateFormat(
        'E',
        'es_ES',
      ).format(date).substring(0, 3).toUpperCase();
      final dailySales = allSales.where(
        (s) =>
            s.date.year == date.year &&
            s.date.month == date.month &&
            s.date.day == date.day,
      );
      double revenue = 0.0;
      for (var sale in dailySales) {
        revenue += sale.total;
      }
      weeklyRevenue[i] = revenue;
      if (revenue > maxRevenue) {
        maxRevenue = revenue;
      }
    }

    // prevent division by zero feeling if 0 sales
    if (maxRevenue == 0) maxRevenue = 100;

    return Container(
      height: 220,
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxRevenue * 1.2, // leave some padding at the top
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '\$${rod.toY.toStringAsFixed(0)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      days[value.toInt()],
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: weeklyRevenue.asMap().entries.map((entry) {
            final idx = entry.key;
            final val = entry.value;
            final bool isToday = idx == 6; // last item is today
            return BarChartGroupData(
              x: idx,
              barRods: [
                BarChartRodData(
                  toY: val,
                  width: 22,
                  color: isToday
                      ? const Color(0xFFC5A028)
                      : const Color(0xFFC5A028).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxRevenue * 1.2,
                    color: Colors.grey.withOpacity(0.05),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  final Sale sale;

  const _SaleCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.receipt,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ticket #${sale.id.toString().padLeft(4, '0')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(sale.date),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            Text(
              '\$${sale.total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Color(0xFFC5A028),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Row(
            children: [
              Icon(
                Icons.person,
                size: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[300]
                    : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                sale.customerName ?? 'Mostrador',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[300]
                      : Colors.grey[700],
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.badge,
                size: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[300]
                    : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                sale.userName,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[300]
                      : Colors.grey[700],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Desglose',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                ...sale.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item.quantity}x ${item.productName}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '\$${item.total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pago mediante',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC5A028).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatPaymentMethod(sale.paymentMethod),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC5A028),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatPaymentMethod(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Efectivo';
      case PaymentMethod.card:
        return 'Tarjeta';
      case PaymentMethod.transfer:
        return 'Transferencia';
    }
  }
}
