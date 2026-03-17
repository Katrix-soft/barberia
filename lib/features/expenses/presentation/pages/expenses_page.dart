import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/expense_bloc.dart';
import '../bloc/expense_event.dart';
import '../bloc/expense_state.dart';
import '../../domain/entities/expense.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/domain/entities/user.dart';
import 'package:posbarber/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:posbarber/features/pos/presentation/bloc/pos_event.dart';
import 'package:posbarber/core/database/database_helper.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _currentUserName = authState.user.name;
      // Filter by the logged-in user's name
      context.read<ExpenseBloc>().add(LoadExpenses(userName: _currentUserName));
    } else {
      context.read<ExpenseBloc>().add(const LoadExpenses());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final bool isAdmin = authState is Authenticated && authState.user.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Control de Gastos Personal',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: BlocListener<ExpenseBloc, ExpenseState>(
        listener: (context, state) {
          if (state.status == ExpenseStatus.success) {
            context.read<PosBloc>().add(LoadPosData());
            
            if (state.lastUpdatedExpense != null && state.lastUpdatedExpense!.isPaid) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '¡Cumpliste con pagar el ${state.lastUpdatedExpense!.description}!',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
          }
          if (state.status == ExpenseStatus.error &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<ExpenseBloc, ExpenseState>(
          builder: (context, state) {
            if (state.status == ExpenseStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            final pending = state.totalPending;

            return Column(
              children: [
                if (isAdmin)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.blue.withOpacity(0.1),
                    child: const Row(
                      children: [
                        Icon(Icons.visibility, color: Colors.blue, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'MODO OBSERVADOR: No puedes modificar los gastos.',
                            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildSummaryHeader(pending),
                Expanded(
                  child: state.expenses.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.expenses.length,
                          itemBuilder: (context, index) {
                            final expense = state.expenses[index];
                            return _buildExpenseCard(expense, isAdmin: isAdmin);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: isAdmin ? null : FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(context),
        backgroundColor: const Color(0xFFC5A028),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_card),
        label: const Text('Nuevo Gasto'),
      ),
    );
  }

  Widget _buildSummaryHeader(double pending) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFC5A028).withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const Text(
            'MI SALDO PENDIENTE',
            style: TextStyle(
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
              color: Color(0xFFC5A028),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${pending.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: Color(0xFFC5A028),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Usuario: ${_currentUserName ?? "Administrador"}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No tienes gastos registrados',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense, {bool isAdmin = false}) {
    final bool isOverdue =
        !expense.isPaid && expense.dueDate.isBefore(DateTime.now());

    final bool isConsumption = expense.category == 'Consumo Personal';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isConsumption ? Colors.orange.withOpacity(0.05) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isConsumption ? const BorderSide(color: Colors.orange, width: 0.5) : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                (expense.isPaid
                        ? Colors.green
                        : (isOverdue ? Colors.red : const Color(0xFFC5A028)))
                    .withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getIconForCategory(expense.category),
            color: expense.isPaid
                ? Colors.green
                : (isOverdue ? Colors.red : const Color(0xFFC5A028)),
          ),
        ),
        title: Text(
          expense.description,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          'Vence: ${DateFormat("dd/MM/yyyy").format(expense.dueDate)}',
          style: TextStyle(
            color: isOverdue && !expense.isPaid ? Colors.red : Colors.grey,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${expense.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Color(0xFFC5A028),
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: (isConsumption || isAdmin)
                ? null // "A cuenta" items and Admin-observer are read-only
                : () => context.read<ExpenseBloc>().add(
                    ToggleExpensePaidEvent(expense),
                  ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: expense.isPaid
                      ? Colors.green.withOpacity(0.1)
                      : (isConsumption ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isConsumption ? 'A CUENTA' : (expense.isPaid ? 'PAGADO' : 'PENDIENTE'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: expense.isPaid ? Colors.green : (isConsumption ? Colors.orange : Colors.grey),
                  ),
                ),
              ),
            ),
          ],
        ),
        onLongPress: (isConsumption || isAdmin) ? null : () => _showDeleteConfirm(expense),
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'alquiler':
        return Icons.home;
      case 'luz':
      case 'electricidad':
        return Icons.electric_bolt;
      case 'agua':
        return Icons.water_drop;
      case 'internet':
        return Icons.wifi;
      case 'insumos':
        return Icons.shopping_basket;
      case 'consumo personal':
        return Icons.fastfood_outlined;
      default:
        return Icons.receipt_long;
    }
  }

  void _showDeleteConfirm(Expense expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Gasto'),
        content: Text('¿Estás seguro de eliminar "${expense.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              context.read<ExpenseBloc>().add(DeleteExpenseEvent(expense.id!));
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = 'Insumos';
    DateTime selectedDate = DateTime.now();
    bool isSaving = false;
    
    // Fetch staff if headBarber
    final authState = context.read<AuthBloc>().state;
    final bool isHeadBarber = authState is Authenticated && authState.user.role == UserRole.headBarber;
    String targetUserName = _currentUserName ?? 'admin';
    List<Map<String, dynamic>> staffList = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (isHeadBarber && staffList.isEmpty) {
            DatabaseHelper().database.then((db) async {
              final users = await db.query('users', where: "role != 'admin'");
              if (ctx.mounted) {
                setDialogState(() {
                  staffList = users;
                });
              }
            });
          }
          return AlertDialog(
            title: Text(isHeadBarber ? 'Asignar Gasto / Insumo' : 'Registrar Gasto Propio'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Ej: Tijeras nuevas, Alquiler de silla',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Monto (\$)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: [
                      'Insumos',
                      'Alquiler',
                      'Luz',
                      'Internet',
                      'Agua',
                      'Mantenimiento',
                      'Otros',
                    ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setDialogState(() => selectedCategory = val!),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Fecha'),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 90)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) setDialogState(() => selectedDate = date);
                    },
                  ),
                  if (isHeadBarber) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('ASIGNAR A:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: targetUserName,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_search, color: Color(0xFFC5A028)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: staffList.map((u) => DropdownMenuItem(
                        value: u['name'] as String,
                        child: Text(u['name'] as String),
                      )).toList(),
                      onChanged: (val) => setDialogState(() => targetUserName = val!),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: isSaving 
                  ? null 
                  : () {
                      if (descController.text.isEmpty || amountController.text.isEmpty) return;
                      final amount = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
                      if (amount <= 0) return;

                      setDialogState(() => isSaving = true);

                      context.read<ExpenseBloc>().add(
                        AddExpenseEvent(
                          Expense(
                            description: descController.text,
                            amount: amount,
                            dueDate: selectedDate,
                            category: selectedCategory,
                            userName: targetUserName,
                          ),
                        ),
                      );
                      Navigator.pop(ctx);
                      
                      if (isHeadBarber && targetUserName != _currentUserName) {
                        _showBossConfirmationReceipt(context, targetUserName, descController.text, amount);
                      }
                    },
                child: isSaving 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    )
                  : const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBossConfirmationReceipt(BuildContext context, String barberName, String desc, double amount) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFC5A028), width: 2),
            gradient: LinearGradient(
              colors: [Colors.black, Colors.grey[900]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long, color: Color(0xFFC5A028), size: 64),
              const SizedBox(height: 16),
              const Text(
                '¡CARGO REALIZADO!',
                style: TextStyle(color: Color(0xFFC5A028), fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 2),
              ),
              const Divider(color: Color(0xFFC5A028), height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('BARBERO:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(barberName.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('CARGO:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(desc, style: const TextStyle(color: Colors.white)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('MONTO:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text('\$${amount.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFC5A028), fontWeight: FontWeight.w900, fontSize: 24)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Este monto se descontará automáticamente de sus ganancias en el próximo reporte.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC5A028),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
