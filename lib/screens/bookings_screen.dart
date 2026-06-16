import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/booking.dart';
import 'add_booking_screen.dart';
import 'booking_detail_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final _searchController = TextEditingController();
  String _statusFilter = 'all';
  List<Booking> _filteredBookings = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBookings());
  }

  Future<void> _loadBookings() async {
    await context.read<AppState>().loadAllBookings();
    _applyFilter();
  }

  void _applyFilter() {
    final state = context.read<AppState>();
    final query = _searchController.text.toLowerCase().trim();
    
    setState(() {
      _filteredBookings = state.bookings.where((b) {
        final matchesSearch = query.isEmpty ||
            b.customerName.toLowerCase().contains(query) ||
            b.phone.contains(query) ||
            b.eventType.toLowerCase().contains(query);
        final matchesStatus = _statusFilter == 'all' || b.status == _statusFilter;
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddBookingScreen()),
            ).then((_) => _loadBookings()),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, event...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilter();
                        },
                      )
                    : null,
              ),
              onChanged: (_) => _applyFilter(),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 6),
                _buildFilterChip('Confirmed', 'confirmed'),
                const SizedBox(width: 6),
                _buildFilterChip('Completed', 'completed'),
                const SizedBox(width: 6),
                _buildFilterChip('Cancelled', 'cancelled'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer<AppState>(
              builder: (context, state, _) {
                if (state.bookings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.book_online, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No bookings yet', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddBookingScreen()),
                          ).then((_) => _loadBookings()),
                          icon: const Icon(Icons.add),
                          label: const Text('Add First Booking'),
                        ),
                      ],
                    ),
                  );
                }

                if (_filteredBookings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('No matching bookings', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadBookings(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: _filteredBookings.length,
                    itemBuilder: (context, index) {
                      final booking = _filteredBookings[index];
                      final dateStr = DateFormat('dd MMM yyyy').format(booking.eventDate);
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: booking.id!)),
                          ).then((_) => _loadBookings()),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  child: Text(
                                    booking.customerName[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        booking.customerName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${booking.eventType} • $dateStr',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                      ),
                                      Text(
                                        '📞 ${booking.phone}  •  ${booking.startTime}-${booking.endTime}',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${NumberFormat('#,##0', 'en_IN').format(booking.totalAmount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: booking.status == 'confirmed'
                                            ? Colors.orange.withOpacity(0.15)
                                            : booking.status == 'completed'
                                                ? Colors.green.withOpacity(0.15)
                                                : Colors.red.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        booking.status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: booking.status == 'confirmed'
                                              ? Colors.orange[800]
                                              : booking.status == 'completed'
                                                  ? Colors.green[800]
                                                  : Colors.red[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _statusFilter = value);
        _applyFilter();
      },
    );
  }
}
