import 'package:flutter/material.dart';
import '../../../../core/database/database_helper.dart';
import '../../data/payroll_service.dart';

class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key});

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  late PayrollService _payrollService;
  bool _isLoading = true;
  List<Map<String, dynamic>> _liquidations = [];

  @override
  void initState() {
    super.initState();
    _payrollService = PayrollService(DatabaseHelper());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      final users = await db.query('users');
      final data = await _payrollService.getPendingLiquidations(users);
      
      setState(() {
        _liquidations = (data['liquidations'] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint("Error loading payroll info: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsPaid(String userName, double netAmount) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Confirmar Pago', style: TextStyle(color: Color(0xFFC5A028))),
        content: Text(
          '¿Estás seguro de marcar como PAGADO los \$${netAmount.toStringAsFixed(2)} del barbero $userName?\n\nEsto reseteará su comisión y consumos a cero para el próximo período.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A028), foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, Pagar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _payrollService.markAsPaid(userName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pago liquidado con éxito para $userName'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Liquidación de Barberos', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFC5A028))),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC5A028)))
          : _liquidations.isEmpty
              ? const Center(child: Text('No hay personal para liquidar', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _liquidations.length,
                  itemBuilder: (context, index) {
                    final liq = _liquidations[index];
                    return _buildPayrollCard(liq);
                  },
                ),
    );
  }

  Widget _buildPayrollCard(Map<String, dynamic> liq) {
    final String name = liq['name'];
    final double sales = liq['service_sales'];
    final double commission = liq['commission'];
    final double consumptions = liq['consumptions'];
    final double netPayout = liq['net_payout'];

    final bool isZero = netPayout == 0 && sales == 0 && consumptions == 0;

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFC5A028).withOpacity(0.1),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Color(0xFFC5A028), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 32),
            _buildRow('Servicios Generados', sales, Colors.white70),
            const SizedBox(height: 8),
            _buildRow('Comisión (50%)', commission, Colors.blue),
            const SizedBox(height: 8),
            _buildRow('Consumos A Cuenta', -consumptions, Colors.orange),
            const Divider(color: Colors.white10, height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('A PAGAR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                Text(
                  '\$${netPayout.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: netPayout >= 0 ? const Color(0xFFC5A028) : Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isZero ? null : () => _markAsPaid(name, netPayout),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A028),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white10,
                  disabledForegroundColor: Colors.white30,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Marcar como Pagado', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54)),
        Text(
          '${amount < 0 ? '-' : ''}\$${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}
