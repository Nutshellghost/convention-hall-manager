import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/booking.dart';
import 'booking_detail_screen.dart';
import 'add_booking_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _format = CalendarFormat.month;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<Booking>> _bookingsByDate = {};
  List<Booking> _selectedDayBookings = [];

  @override
  void initState() {
    super.initState();
    _loadBookingsForMonth(_focusedDay.year, _focusedDay.month);
    _updateSelectedDayBookings();
  }

  Future<void> _loadBookingsForMonth(int year, int month) async {
    final state = context.read<AppState>();
    final bookings = await state.getBookingsForMonth(year, month);
    
    final map = <DateTime, List<Booking>>{};
    for (var b in bookings) {
      final date = DateTime(b.eventDate.year, b.eventDate.month, b.eventDate.day);
      map.putIfAbsent(date, () => []).add(b);
    }
    
    setState(() {
      _bookingsByDate = map;
    });
    _updateSelectedDayBookings();
  }

  void _updateSelectedDayBookings() {
    final date = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    setState(() {
      _selectedDayBookings = _bookingsByDate[date] ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddBookingScreen()),
            ).then((_) {
              _loadBookingsForMonth(_focusedDay.year, _focusedDay.month);
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8),
            child: TableCalendar(
              firstDay: DateTime(2023),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: _format,
              onFormatChanged: (format) => setState(() => _format = format),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _updateSelectedDayBookings();
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _loadBookingsForMonth(focusedDay.year, focusedDay.month);
              },
              eventLoader: (day) {
                final date = DateTime(day.year, day.month, day.day);
                return _bookingsByDate[date] ?? [];
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isNotEmpty) {
                    return Positioned(
                      bottom: 1,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  }
                  return null;
                },
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  DateFormat('d MMM yyyy').format(_selectedDay),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  '${_selectedDayBookings.length} booking${_selectedDayBookings.length != 1 ? 's' : ''}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Expanded(
            child: _selectedDayBookings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('No bookings on this date', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _selectedDayBookings.length,
                    itemBuilder: (context, index) {
                      final booking = _selectedDayBookings[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: booking.status == 'confirmed'
                                ? Colors.orange.withOpacity(0.2)
                                : booking.status == 'completed'
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                            child: Icon(
                              Icons.person,
                              color: booking.status == 'confirmed'
                                  ? Colors.orange
                                  : booking.status == 'completed'
                                      ? Colors.green
                                      : Colors.red,
                            ),
                          ),
                          title: Text(booking.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${booking.eventType} • ${booking.startTime}-${booking.endTime}'),
                          trailing: Text(
                            '₹${booking.totalAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: booking.id!)),
                          ).then((_) {
                            _loadBookingsForMonth(_focusedDay.year, _focusedDay.month);
                          }),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
