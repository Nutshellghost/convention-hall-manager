import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/decoration_charge.dart';
import 'add_decoration_charge_screen.dart';

class DecorationChargesScreen extends StatefulWidget {
  const DecorationChargesScreen({super.key});

  @override
  State<DecorationChargesScreen> createState() => _DecorationChargesScreenState();
}

class _DecorationChargesScreenState extends State<DecorationChargesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadAllDecorationCharges();
    });
  }

  Future<void> _deleteCharge(DecorationCharge charge) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete decoration charge for ${charge.customerName}?'),
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
      await context.read<AppState>().deleteDecorationCharge(charge.id!);
      if (context.mounted) {
        context.read<AppState>().loadAllDecorationCharges();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decoration Charges'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddDecorationChargeScreen()),
            ).then((_) {
              context.read<AppState>().loadAllDecorationCharges();
            }),
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          if (state.decorationCharges.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.palette, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No decoration charges', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddDecorationChargeScreen()),
                    ).then((_) => context.read<AppState>().loadAllDecorationCharges()),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Decoration Charge'),
                  ),
                ],
              ),
            );
          }

          final total = state.decorationCharges.fold<double>(0, (sum, c) => sum + c.amount);

          return RefreshIndicator(
            onRefresh: () => state.loadAllDecorationCharges(),
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                // Total header
                Card(
                  color: Colors.purple.withOpacity(0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.palette, color: Colors.purple, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Decoration Charges', style: TextStyle(color: Colors.grey[600])),
                            Text(
                              '₹${NumberFormat('#,##0', 'en_IN').format(total)}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purple),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...state.decorationCharges.map((charge) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.withOpacity(0.2),
                      child: const Icon(Icons.palette, color: Colors.purple),
                    ),
                    title: Text(charge.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      DateFormat('dd MMM yyyy').format(charge.date),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    trailing: Text(
                      '₹${NumberFormat('#,##0', 'en_IN').format(charge.amount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.purple,
                      ),
                    ),
                    onLongPress: () => _deleteCharge(charge),
                  ),
                )),
              ],
            ),
          );
        },
      ),
    );
  }
}
