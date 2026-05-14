import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/expense.dart';
import 'dashboard_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadAllExpenses();
    });
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,##0', 'en_IN').format(amount);
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete "${expense.description}" for ₹${_formatAmount(expense.amount)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<AppState>().deleteExpense(expense.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditExpenseScreen()),
            ).then((_) => context.read<AppState>().loadAllExpenses()),
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          if (state.expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No expenses recorded', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddEditExpenseScreen()),
                    ).then((_) => context.read<AppState>().loadAllExpenses()),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Expense'),
                  ),
                ],
              ),
            );
          }

          // Calculate total
          final totalExpenses = state.expenses.fold<double>(0, (sum, e) => sum + e.amount);

          return RefreshIndicator(
            onRefresh: () => state.loadAllExpenses(),
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                // Total header
                Card(
                  color: Colors.red.withOpacity(0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.money_off, color: Colors.red, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Expenses', style: TextStyle(color: Colors.grey[600])),
                            Text(
                              '₹${_formatAmount(totalExpenses)}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...state.expenses.map((expense) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getCategoryColor(expense.category).withOpacity(0.2),
                      child: Icon(
                        _getCategoryIcon(expense.category),
                        color: _getCategoryColor(expense.category),
                      ),
                    ),
                    title: Text(expense.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${expense.category} • ${DateFormat('dd MMM yyyy').format(expense.date)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    trailing: Text(
                      '₹${_formatAmount(expense.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.red[700],
                      ),
                    ),
                    onLongPress: () => _deleteExpense(expense),
                  ),
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Electricity': return Colors.amber;
      case 'Water': return Colors.blue;
      case 'Maintenance': return Colors.brown;
      case 'Staff Salary': return Colors.teal;
      case 'Cleaning': return Colors.cyan;
      case 'Decoration': return Colors.pink;
      case 'Catering': return Colors.orange;
      case 'Security': return Colors.indigo;
      case 'Renovation': return Colors.deepOrange;
      case 'Transport': return Colors.lime;
      case 'Insurance': return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Electricity': return Icons.bolt;
      case 'Water': return Icons.water_drop;
      case 'Maintenance': return Icons.build;
      case 'Staff Salary': return Icons.people;
      case 'Cleaning': return Icons.cleaning_services;
      case 'Decoration': return Icons.palette;
      case 'Catering': return Icons.restaurant;
      case 'Security': return Icons.security;
      case 'Renovation': return Icons.construction;
      case 'Transport': return Icons.local_shipping;
      case 'Insurance': return Icons.verified;
      default: return Icons.receipt;
    }
  }
}
