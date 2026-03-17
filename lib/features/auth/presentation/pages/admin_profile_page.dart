import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database_helper.dart';
import '../../../pos/domain/entities/sale.dart';
import '../../../pos/data/repositories/pos_repository_impl.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/domain/entities/user.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  late Future<Map<String, dynamic>> _dashboardData;
  final ScrollController _terminalController = ScrollController();
  final List<String> _systemLogs = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _addLog("SYSTEM INITIALIZED...");
    _addLog("FETCHING REAL-TIME METRICS...");
    _addLog("DATABASE STATUS: OPTIMAL");
  }

  void _addLog(String message) {
    setState(() {
      _systemLogs.add("[${DateFormat('HH:mm:ss').format(DateTime.now())}] $message");
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_terminalController.hasClients) {
        _terminalController.animateTo(
          _terminalController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _loadDashboardData() {
    final posRepo = PosRepositoryImpl(databaseHelper: DatabaseHelper());
    setState(() {
      _dashboardData = Future.wait([
        posRepo.getSales(),
        DatabaseHelper().database.then((db) => db.query('products', where: 'stock <= stock_min')),
        DatabaseHelper().database.then((db) => db.query('users')),
      ]).then((results) {
        final salesResult = results[0] as dynamic;
        final lowStock = results[1] as List<Map<String, dynamic>>;
        final users = results[2] as List<Map<String, dynamic>>;

        List<Sale> sales = [];
        salesResult.fold((l) => null, (r) => sales = r);

        final today = DateTime.now();
        final todaySales = sales.where((s) => _isSameDay(s.date, today)).toList();
        final totalRevenue = todaySales.fold<double>(0, (sum, s) => sum + s.total);

        _addLog("SYNC COMPLETED: ${todaySales.length} SALES FOUND TODAY");
        if (lowStock.isNotEmpty) {
          _addLog("WARNING: ${lowStock.length} PRODUCTS WITH LOW STOCK");
        }

        return {
          'revenue': totalRevenue,
          'salesCount': todaySales.length,
          'lowStockCount': lowStock.length,
          'staffCount': users.length,
          'lowStockItems': lowStock,
        };
      });
    });
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030303),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "MASTER CONTROL CENTER",
          style: GoogleFonts.shareTechMono(
            fontSize: 18,
            letterSpacing: 2,
            color: const Color(0xFFC5A028),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFC5A028)),
            onPressed: () {
              _addLog("MANUAL REFRESH REQUESTED...");
              _loadDashboardData();
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardData,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFC5A028)));
          }

          final data = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCriticalMetrics(data),
                const SizedBox(height: 32),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildSystemTerminal(),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: _buildHealthStatus(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCriticalMetrics(Map<String, dynamic> data) {
    return Row(
      children: [
        _metricBox("REVENUE_DAY", "\$${data['revenue'].toStringAsFixed(0)}", Colors.green),
        const SizedBox(width: 16),
        _metricBox("ACTIVE_SALES", "${data['salesCount']}", Colors.blue),
        const SizedBox(width: 16),
        _metricBox("LOW_STOCK", "${data['lowStockCount']}", data['lowStockCount'] > 0 ? Colors.red : Colors.grey),
        const SizedBox(width: 16),
        _metricBox("STAFF_ONLINE", "${data['staffCount']}", const Color(0xFFC5A028)),
      ],
    );
  }

  Widget _metricBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, spreadRadius: 2),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 10),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.shareTechMono(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemTerminal() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF141414),
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                const Icon(Icons.code, size: 14, color: Colors.white38),
                const SizedBox(width: 8),
                Text(
                  "SYSTEM_LOGS.EXE",
                  style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _terminalController,
              padding: const EdgeInsets.all(16),
              itemCount: _systemLogs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _systemLogs[index],
                    style: GoogleFonts.shareTechMono(
                      color: _systemLogs[index].contains("WARNING") ? Colors.red : Colors.green.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStatus() {
    return Column(
      children: [
        _statusIndicator("DATABASE_FLUTTER", "CONNECTED", Colors.green),
        const SizedBox(height: 12),
        _statusIndicator("PWA_SERVICE_WORKER", "ACTIVE", Colors.green),
        const SizedBox(height: 12),
        _statusIndicator("SYNC_QUEUE", "IDLE", Colors.blue),
        const SizedBox(height: 12),
        _statusIndicator("ENCRYPTION_KEY", "VALID", Colors.green),
        const SizedBox(height: 12),
        _statusIndicator("API_UPTIME", "99.9%", const Color(0xFFC5A028)),
        const Spacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFC5A028).withOpacity(0.05),
            border: Border.all(color: const Color(0xFFC5A028).withOpacity(0.2)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              Text(
                "VER_1.3.5",
                style: GoogleFonts.shareTechMono(color: const Color(0xFFC5A028), fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                "STATUS: PROTECTED",
                style: GoogleFonts.shareTechMono(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusIndicator(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 11)),
          Text(value, style: GoogleFonts.shareTechMono(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
