import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database_helper.dart';
import '../../../pos/domain/entities/sale.dart';
import '../../../pos/data/repositories/pos_repository_impl.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/data/repositories/expense_repository_impl.dart';
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
  late Future<Map<String, dynamic>> _futureData;
  String _selectedFilter = 'Histórico';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  void _loadAllData() {
    final posRepo = PosRepositoryImpl(databaseHelper: DatabaseHelper());
    final expenseRepo = ExpenseRepositoryImpl(dbHelper: DatabaseHelper());
    
    setState(() {
      _futureData = Future.wait([
        posRepo.getSales(),
        expenseRepo.getExpenses(),
        DatabaseHelper().database.then((db) => db.query('users')),
      ]).then((results) {
        final salesResult = results[0] as dynamic; 
        final expensesResult = results[1] as dynamic; 
        final users = results[2] as List<Map<String, dynamic>>;
        
        List<Sale> sales = [];
        List<Expense> expenses = [];

        salesResult.fold((l) => null, (r) => sales = r);
        expensesResult.fold((l) => null, (r) => expenses = r);

        return {
          'sales': sales,
          'expenses': expenses,
          'users': users,
        };
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes Globales', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Exportar Ventas a Excel',
            onPressed: () async {
              final data = await _futureData;
              final List<Sale> sales = data['sales'];
              if (sales.isNotEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Generando Excel por favor espere...')),
                  );
                }
                final path = await ExcelExportService.exportSales(sales);
                if (mounted && path != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Reporte BM BARBER guardado con éxito'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              }
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allSales = snapshot.data!['sales'] as List<Sale>;
          final allExpenses = snapshot.data!['expenses'] as List<Expense>;
          
          final authState = context.read<AuthBloc>().state;
          List<Sale> filteredSales = allSales;
          List<Expense> filteredExpenses = allExpenses;
          
          if (authState is Authenticated && authState.user.role == UserRole.employee) {
            filteredSales = allSales.where((s) => s.userName == authState.user.name).toList();
            filteredExpenses = allExpenses.where((e) => e.userName == authState.user.name).toList();
          }

          // Filtro por fecha seleccionado
          final now = DateTime.now();
          DateTime startDate = DateTime(2000);
          if (_selectedFilter == 'Hoy') {
            startDate = DateTime(now.year, now.month, now.day);
          } else if (_selectedFilter == 'Esta Semana') {
            startDate = now.subtract(Duration(days: now.weekday - 1));
            startDate = DateTime(startDate.year, startDate.month, startDate.day);
          } else if (_selectedFilter == 'Este Mes') {
            startDate = DateTime(now.year, now.month, 1);
          }

          filteredSales = filteredSales.where((s) => s.date.isAfter(startDate.subtract(const Duration(seconds: 1)))).toList();
          filteredExpenses = filteredExpenses.where((e) => e.dueDate.isAfter(startDate.subtract(const Duration(seconds: 1)))).toList();

          if (filteredSales.isEmpty && filteredExpenses.isEmpty && _selectedFilter != 'Hoy') {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFilterDropdown(),
                  const SizedBox(height: 20),
                  const Text('No hay movimientos en este período.'),
                ],
              )
            );
          }

          // Cálculos Financieros
          final today = DateTime.now();
          final todaySales = allSales.where((s) => _isSameDay(s.date, today)).toList(); // Always show today's status
          final todayRevenue = todaySales.fold<double>(0, (sum, s) => sum + s.total);
          
          final totalSalesRevenue = filteredSales.fold<double>(0, (sum, s) => sum + s.total);
          final totalExpenses = filteredExpenses.fold<double>(0, (sum, e) => sum + e.amount);
          final netProfit = totalSalesRevenue - totalExpenses;

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _buildSummaryHeader(totalSalesRevenue, totalExpenses, netProfit),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('ESTADO CORTOCIRCUITO (HOY REAL)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              _buildTodayCards(todaySales.length, todayRevenue),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('FILTRAR REPORTES', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                    _buildFilterDropdown(),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text('INGRESOS (GRAFICO SEMANAL)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              _buildWeeklyChart(filteredSales),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('VENTAS POR BARBERO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              _buildBarberMetrics(filteredSales, snapshot.data!['users']),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('HISTORIAL DE MOVIMIENTOS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              ...filteredSales.take(20).map((sale) => _SaleCard(sale: sale)),
            ],
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFC5A028).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC5A028).withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          icon: const Icon(Icons.calendar_month, color: Color(0xFFC5A028), size: 16),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A028)),
          dropdownColor: Colors.black87,
          items: ['Hoy', 'Esta Semana', 'Este Mes', 'Histórico'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _selectedFilter = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(double sales, double expenses, double net) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFC5A028).withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.analytics_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'BALANCE GENERAL (${_getCurrentUserRoleLabel(context)})',
                style: const TextStyle(letterSpacing: 1.5, fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSimpleStat('Ventas', sales, Colors.green),
              _buildSimpleStat('Gastos', expenses, Colors.red),
              _buildSimpleStat('Neto', net, net >= 0 ? Colors.blue : Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: net >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(net >= 0 ? Icons.trending_up : Icons.trending_down, color: net >= 0 ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Rentabilidad: \$${net.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: net >= 0 ? Colors.green : Colors.red),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          '\$${value.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }

  Widget _buildTodayCards(int count, double revenue) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _infoCard('Ventas Hoy', count.toString(), Icons.receipt, Colors.orange)),
          const SizedBox(width: 12),
          Expanded(child: _infoCard('Recaudado', '\$${revenue.toStringAsFixed(2)}', Icons.monetization_on, Colors.green)),
        ],
      ),
    );
  }

  Widget _infoCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withOpacity(0.1))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(List<Sale> allSales) {
    if (allSales.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final List<double> weeklyRevenue = List.filled(7, 0.0);
    final List<String> days = List.filled(7, '');
    double maxRevenue = 0.1;

    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: 6 - i));
      days[i] = DateFormat('E', 'es_ES').format(date).substring(0, 1).toUpperCase();
      final dailySales = allSales.where((s) => _isSameDay(s.date, date));
      double rev = dailySales.fold(0, (sum, s) => sum + s.total);
      weeklyRevenue[i] = rev;
      if (rev > maxRevenue) maxRevenue = rev;
    }

    return Container(
      height: 180,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxRevenue * 1.2,
          barGroups: weeklyRevenue.asMap().entries.map((e) => BarChartGroupData(
            x: e.key,
            barRods: [BarChartRodData(toY: e.value, color: const Color(0xFFC5A028), width: 15, borderRadius: BorderRadius.circular(4))],
          )).toList(),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) => Text(days[v.toInt()], style: const TextStyle(fontSize: 10, color: Colors.grey)),
            )),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  String _getCurrentUserRoleLabel(BuildContext context) {
    final state = context.read<AuthBloc>().state;
    if (state is Authenticated) {
      switch (state.user.role) {
        case UserRole.admin: return 'ADMINISTRADOR';
        case UserRole.headBarber: return 'BARBERO JEFE';
        case UserRole.employee: return 'BARBERO';
      }
    }
    return 'USUARIO';
  }

  Widget _buildBarberMetrics(List<Sale> sales, List<Map<String, dynamic>> allUsers) {
    final Map<String, double> barberSales = {};
    final Map<String, double> barberServiceSales = {};
    final Map<String, double> barberConsumption = {};
    
    // 1. Get metrics from sales/expenses
    for (var sale in sales) {
      if (sale.paymentMethod == PaymentMethod.personal) {
        barberConsumption[sale.userName] = (barberConsumption[sale.userName] ?? 0) + sale.total;
      } else {
        barberSales[sale.userName] = (barberSales[sale.userName] ?? 0) + sale.total;
        
        // Sum total of only services for commissions
        double serviceTotal = 0;
        for (var item in sale.items) {
          if (item.isService) {
            serviceTotal += item.total;
          }
        }
        barberServiceSales[sale.userName] = (barberServiceSales[sale.userName] ?? 0) + serviceTotal;
      }
    }

    // 2. Identify which barbers to show
    // We want to show all 'employee' and 'headBarber' users
    final List<String> staffNamesToDisplay = [];
    for (var u in allUsers) {
      final role = u['role'];
      final name = (u['name'] as String).toLowerCase();
      // Strictly exclude test/admin names if they linger, or just stick to roles
      if ((role == 'employee' || role == 'headBarber') && 
          name != 'admin' && name != 'administrador') {
        staffNamesToDisplay.add(u['name'] as String);
      }
    }

    if (staffNamesToDisplay.isEmpty) return const SizedBox.shrink();

    final totalRevenue = barberSales.values.fold(0.0, (sum, val) => sum + val);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...staffNamesToDisplay.map((barber) {
                final saleVal = barberSales[barber] ?? 0;
                final serviceVal = barberServiceSales[barber] ?? 0;
                final consVal = barberConsumption[barber] ?? 0;
                final percentage = totalRevenue == 0 ? 0.0 : saleVal / totalRevenue;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFC5A028).withOpacity(0.1),
                            child: Text(barber.isNotEmpty ? barber.substring(0, 1).toUpperCase() : '?', style: const TextStyle(color: Color(0xFFC5A028), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(barber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Recaudado: \$${saleVal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Comisión (50% serv): \$${(serviceVal * 0.5).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                                if (consVal > 0)
                                  Text('Consumo: -\$${consVal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(
                                  'Neto: \$${((serviceVal * 0.5) - consVal).toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: ((serviceVal * 0.5) - consVal) >= 0 ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: Colors.grey[100],
                          color: const Color(0xFFC5A028),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const Divider(),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    'Total Recaudado por Barbers: \$${totalRevenue.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A028), fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
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
    final isPersonal = sale.paymentMethod == PaymentMethod.personal;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isPersonal ? Colors.orange : const Color(0xFFC5A028)).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isPersonal ? Icons.person_pin_circle_outlined : Icons.monetization_on_outlined,
          size: 16,
          color: isPersonal ? Colors.orange : const Color(0xFFC5A028),
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text('${sale.customerName ?? 'Mostrador'}', style: const TextStyle(fontWeight: FontWeight.bold))),
          if (isPersonal)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: const Text('A CUENTA', style: TextStyle(fontSize: 8, color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      subtitle: Text('${DateFormat('dd/MM HH:mm').format(sale.date)} • Atendido por: ${sale.userName}'),
      trailing: Text('\$${sale.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
    );
  }
}
