import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/expense_bloc.dart';
import '../bloc/expense_event.dart';
import '../bloc/expense_state.dart';
import '../../domain/entities/expense.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Control de Gastos',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: BlocListener<ExpenseBloc, ExpenseState>(
        listener: (context, state) {
          if (state.status == ExpenseStatus.success &&
              state.lastUpdatedExpense != null) {
            if (state.lastUpdatedExpense!.isPaid) {
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
                _buildSummaryHeader(pending),
                Expanded(
                  child: state.expenses.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.expenses.length,
                          itemBuilder: (context, index) {
                            final expense = state.expenses[index];
                            return _buildExpenseCard(expense);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
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
            'TOTAL PENDIENTE',
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
          const Text(
            '¡Mantén tus cuentas al día!',
            style: TextStyle(color: Colors.grey),
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
            'No hay gastos registrados',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    final bool isOverdue =
        !expense.isPaid && expense.dueDate.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          'Vence: ${DateFormat('dd/MM/yyyy').format(expense.dueDate)}',
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
              onTap: () => context.read<ExpenseBloc>().add(
                ToggleExpensePaidEvent(expense),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: expense.isPaid
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  expense.isPaid ? 'PAGADO' : 'PENDIENTE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: expense.isPaid ? Colors.green : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
        onLongPress: () => _showDeleteConfirm(expense),
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
    String selectedCategory = 'Luz';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Registrar Gasto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (ej: Alquiler Marzo)',
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
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items:
                      [
                            'Luz',
                            'Alquiler',
                            'Internet',
                            'Agua',
                            'Insumos',
                            'Otros',
                          ]
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedCategory = val!),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Fecha de Vencimiento'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 30),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setDialogState(() => selectedDate = date);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (descController.text.isEmpty ||
                    amountController.text.isEmpty) {
                  return;
                }
                final amount =
                    double.tryParse(
                      amountController.text.replaceAll(',', '.'),
                    ) ??
                    0;
                if (amount <= 0) return;

                context.read<ExpenseBloc>().add(
                  AddExpenseEvent(
                    Expense(
                      description: descController.text,
                      amount: amount,
                      dueDate: selectedDate,
                      category: selectedCategory,
                    ),
                  ),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
