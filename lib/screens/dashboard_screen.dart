import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_state.dart';
import '../models/booking.dart';
import '../models/expense.dart';
import 'booking_detail_screen.dart';
import 'add_booking_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Kusetty Convention Hall'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => state.loadDashboard(),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => _logout(context),
              ),
            ],
          ),
          body: state.loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => state.loadDashboard(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Welcome header
                      Card(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.primary.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Convention Hall Manager',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Manage bookings, payments & expenses',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats grid
                      _buildStatCard(
                        context,
                        'Upcoming Bookings',
                        '${state.upcomingCount}',
                        Icons.event_available,
                        Colors.orange,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Total Revenue',
                              '₹${_formatAmount(state.totalRevenue)}',
                              Icons.account_balance_wallet,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Total Expenses',
                              '₹${_formatAmount(state.totalExpenses)}',
                              Icons.money_off,
                              Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Net Profit',
                              '₹${_formatAmount(state.netProfit)}',
                              Icons.trending_up,
                              state.netProfit >= 0 ? Colors.teal : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Replaced Pending Amount with user info
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.person, color: Colors.purple, size: 28),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Signed In',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    FutureBuilder<String>(
                                      future: _getUserEmail(),
                                      builder: (context, snapshot) {
                                        final email = snapshot.data ?? '...';
                                        return Text(
                                          email.length > 15 ? '${email.substring(0, 12)}...' : email,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                                          textAlign: TextAlign.center,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Quick actions
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickAction(
                              context,
                              Icons.add_circle,
                              'New Booking',
                              Colors.purple,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AddBookingScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildQuickAction(
                              context,
                              Icons.add_chart,
                              'Add Expense',
                              Colors.orange,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddEditExpenseScreen(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Today's bookings
                      Text(
                        "Today's Bookings",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (state.todayBookings.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No bookings for today',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ...state.todayBookings.map(
                          (b) => _buildBookingCard(context, b),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Future<String> _getUserEmail() async {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.email ?? 'Unknown';
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(BuildContext context, Booking booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            booking.customerName[0].toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(booking.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${booking.eventType} • ${booking.startTime}-${booking.endTime}'),
        trailing: Chip(
          label: Text(booking.status.toUpperCase()),
          backgroundColor: booking.status == 'confirmed'
              ? Colors.orange.withOpacity(0.2)
              : booking.status == 'completed'
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
          labelStyle: TextStyle(
            fontSize: 11,
            color: booking.status == 'confirmed'
                ? Colors.orange[800]
                : booking.status == 'completed'
                    ? Colors.green[800]
                    : Colors.red[800],
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: booking.id!)),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,##0.00', 'en_IN').format(amount);
  }
}

// Import AddEditExpenseScreen here to avoid circular import

class AddEditExpenseScreen extends StatefulWidget {
  const AddEditExpenseScreen({super.key});

  @override
  State<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends State<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _category = 'Maintenance';

  final List<String> _categories = [
    'Maintenance', 'Electricity', 'Water', 'Cleaning',
    'Staff Salary', 'Decoration', 'Catering', 'Security',
    'Renovation', 'Transport', 'Insurance', 'Other',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text('Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2023),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saveExpense,
                icon: const Icon(Icons.save),
                label: const Text('Save Expense'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final expense = Expense(
      category: _category,
      description: _descriptionController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      date: _selectedDate,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    await context.read<AppState>().addExpense(expense);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense added successfully')),
      );
    }
  }
}
