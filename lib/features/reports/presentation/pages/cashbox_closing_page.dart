import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database_helper.dart';
import '../../data/cashbox_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class CashboxClosingPage extends StatefulWidget {
  const CashboxClosingPage({super.key});

  @override
  State<CashboxClosingPage> createState() => _CashboxClosingPageState();
}

class _CashboxClosingPageState extends State<CashboxClosingPage> {
  late CashboxService _cashboxService;
  
  bool _isLoading = true;
  CashboxSession? _lastSession;
  double _expectedCash = 0;
  double _expectedMp = 0;
  double _expensesCash = 0;

  final TextEditingController _actualCashController = TextEditingController();
  final TextEditingController _actualMpController = TextEditingController();

  double _discrepancyCash = 0;
  double _discrepancyMp = 0;

  @override
  void initState() {
    super.initState();
    _cashboxService = CashboxService(DatabaseHelper());
    _loadData();

    _actualCashController.addListener(_calculateDiscrepancy);
    _actualMpController.addListener(_calculateDiscrepancy);
  }

  @override
  void dispose() {
    _actualCashController.dispose();
    _actualMpController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _lastSession = await _cashboxService.getLastSession();
      final totals = await _cashboxService.getExpectedTotals();
      setState(() {
        _expectedCash = totals['cash'] ?? 0;
        _expectedMp = totals['mp'] ?? 0;
        _expensesCash = totals['expenses_cash'] ?? 0;
      });
    } catch (e) {
      debugPrint("Error loading cashbox info: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateDiscrepancy() {
    final actualCash = double.tryParse(_actualCashController.text) ?? 0;
    final actualMp = double.tryParse(_actualMpController.text) ?? 0;

    setState(() {
      _discrepancyCash = actualCash - _expectedCash;
      _discrepancyMp = actualMp - _expectedMp;
    });
  }

  Future<void> _performClosing() async {
    if (_actualCashController.text.isEmpty || _actualMpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa los montos reales.')),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    String? userName;
    int? userId;
    if (authState is Authenticated) {
      userName = authState.user.name;
      userId = authState.user.id;
    }

    final actualCash = double.tryParse(_actualCashController.text) ?? 0;
    final actualMp = double.tryParse(_actualMpController.text) ?? 0;
    final totalDiscrepancy = _discrepancyCash + _discrepancyMp;

    final session = CashboxSession(
      openedAt: _lastSession?.closedAt ?? DateTime.now().subtract(const Duration(hours: 8)),
      closedAt: DateTime.now(),
      closedBy: userId,
      closedByName: userName,
      expectedCash: _expectedCash,
      actualCash: actualCash,
      expectedMp: _expectedMp,
      actualMp: actualMp,
      discrepancy: totalDiscrepancy,
      notes: "Cierre de caja automático",
    );

    try {
      await _cashboxService.saveSession(session);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFC5A028), width: 1)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Cierre Exitoso', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Text(
              'El cierre de caja se guardó correctamente.\n\nDescuadre total: \$${totalDiscrepancy.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true); // Return to previous screen
                },
                child: const Text('Volver', style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _shareByWhatsApp(session);
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A028),
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.share),
                label: const Text('Enviar Reporte'),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _shareByWhatsApp(CashboxSession session) async {
    final format = DateFormat('dd/MM/yyyy HH:mm');
    String text = "📊 *CIERRE DE CAJA - BM BARBER*\n";
    text += "📅 ${format.format(session.closedAt)}\n";
    text += "👤 Cajero: ${session.closedByName ?? 'Admin'}\n\n";
    text += "*💵 EFECTIVO:*\n";
    text += "• Esperado: \$${session.expectedCash.toStringAsFixed(2)}\n";
    text += "• Real: \$${session.actualCash.toStringAsFixed(2)}\n";
    text += "• Dif: \$${_discrepancyCash.toStringAsFixed(2)}\n";
    if (_expensesCash > 0) {
      text += "_(Se descontaron \$${_expensesCash.toStringAsFixed(2)} de Gastos en efectivo)_\n";
    }
    text += "\n*💳 MERCADO PAGO:*\n";
    text += "• Esperado: \$${session.expectedMp.toStringAsFixed(2)}\n";
    text += "• Real: \$${session.actualMp.toStringAsFixed(2)}\n";
    text += "• Dif: \$${_discrepancyMp.toStringAsFixed(2)}\n\n";
    text += "⚖️ *DESCUADRE TOTAL:* \$${session.discrepancy.toStringAsFixed(2)}\n";

    final url = "https://wa.me/?text=${Uri.encodeComponent(text)}";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      debugPrint("Could not launch WhatsApp");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Cierre Diario', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFC5A028).withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC5A028).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Color(0xFFC5A028)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Período a Arquear', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      const Text('Día de Hoy (00:00 - 23:59)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            _buildCashCard(),
            const SizedBox(height: 16),
            _buildMpCard(),
            const SizedBox(height: 32),
            
            // Total Discrepancy Box
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (_discrepancyCash + _discrepancyMp) == 0
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'DESCUADRE TOTAL',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                     '\$${(_discrepancyCash + _discrepancyMp).toStringAsFixed(2)}',
                     style: TextStyle(
                       fontSize: 32,
                       fontWeight: FontWeight.w900,
                       color: (_discrepancyCash + _discrepancyMp) == 0 ? Colors.green : Colors.redAccent,
                     ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            SizedBox(
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A028),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _performClosing,
                child: const Text('Realizar Cierre de Caja', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Al cerrar la caja, este período se guardará y los montos esperados volverán a cero.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white30, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashCard() {
    return _buildSectionCard(
      title: 'EFECTIVO',
      icon: Icons.payments_outlined,
      expected: _expectedCash,
      controller: _actualCashController,
      discrepancy: _discrepancyCash,
      expensesDiscounted: _expensesCash,
    );
  }

  Widget _buildMpCard() {
    return _buildSectionCard(
      title: 'MERCADO PAGO',
      icon: Icons.qr_code_scanner,
      expected: _expectedMp,
      controller: _actualMpController,
      discrepancy: _discrepancyMp,
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required double expected,
    required TextEditingController controller,
    required double discrepancy,
    double expensesDiscounted = 0,
  }) {
    Color getDiscrepancyColor() {
      if (discrepancy == 0) return Colors.green;
      if (discrepancy > 0) return Colors.blue; // Over
      return Colors.red; // Under
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white54, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sistema (Esperado)', style: TextStyle(color: Colors.white70)),
              Text('\$${expected.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          if (expensesDiscounted > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.info_outline, size: 12, color: Colors.orange.withOpacity(0.8)),
                  const SizedBox(width: 4),
                  Text(
                    'Se descontaron \$${expensesDiscounted.toStringAsFixed(2)} por Gastos pagados',
                    style: TextStyle(color: Colors.orange.withOpacity(0.8), fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(flex: 2, child: Text('Dinero Físico (Real)', style: TextStyle(color: Colors.white70))),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Color(0xFFC5A028), fontWeight: FontWeight.bold, fontSize: 20),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    prefixStyle: const TextStyle(color: Color(0xFFC5A028), fontSize: 20),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Diferencia', style: TextStyle(color: Colors.white54)),
              Text(
                '${discrepancy >= 0 ? '+' : ''}\$${discrepancy.toStringAsFixed(2)}',
                style: TextStyle(color: getDiscrepancyColor(), fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
