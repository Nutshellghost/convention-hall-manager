import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking.dart';
import '../models/payment.dart';
import '../models/expense.dart';
import '../models/decoration_charge.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  DatabaseHelper._init();

  SupabaseClient get _client => Supabase.instance.client;

  // === BOOKINGS ===

  Future<int> insertBooking(Booking booking) async {
    final data = booking.toMap();
    data.remove('id');
    final result = await _client
        .from('bookings')
        .insert(data)
        .select('id')
        .single();
    return result['id'] as int;
  }

  Future<int> updateBooking(Booking booking) async {
    if (booking.id == null) throw Exception('Booking ID required for update');
    await _client
        .from('bookings')
        .update(booking.toMap())
        .eq('id', booking.id!);
    return booking.id!;
  }

  Future<int> deleteBooking(int id) async {
    await _client.from('payments').delete().eq('booking_id', id);
    await _client.from('bookings').delete().eq('id', id);
    return id;
  }

  Future<List<Booking>> getAllBookings() async {
    final data = await _client
        .from('bookings')
        .select()
        .order('event_date', ascending: false);
    return (data as List).map((r) => Booking.fromMap(r)).toList();
  }

  Future<Booking?> getBooking(int id) async {
    final data = await _client
        .from('bookings')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Booking.fromMap(data);
  }

  Future<List<Booking>> getBookingsForDate(DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final data = await _client
        .from('bookings')
        .select()
        .eq('event_date', dateStr)
        .order('start_time', ascending: true);
    return (data as List).map((r) => Booking.fromMap(r)).toList();
  }

  Future<List<Booking>> getBookingsForMonth(int year, int month) async {
    final monthStr = month.toString().padLeft(2, '0');
    final data = await _client
        .from('bookings')
        .select()
        .like('event_date', '$year-$monthStr%')
        .order('event_date', ascending: true);
    return (data as List).map((r) => Booking.fromMap(r)).toList();
  }

  Future<List<Booking>> searchBookings(String query) async {
    final data = await _client
        .from('bookings')
        .select()
        .or('customer_name.ilike.%$query%,phone.ilike.%$query%')
        .order('event_date', ascending: false);
    return (data as List).map((r) => Booking.fromMap(r)).toList();
  }

  // === PAYMENTS ===

  Future<int> insertPayment(Payment payment) async {
    final map = payment.toMap();
    map.remove('id');
    final result = await _client
        .from('payments')
        .insert(map)
        .select('id')
        .single();
    return result['id'] as int;
  }

  Future<List<Payment>> getPaymentsForBooking(int bookingId) async {
    final data = await _client
        .from('payments')
        .select()
        .eq('booking_id', bookingId)
        .order('date', ascending: true);
    return (data as List).map((r) => Payment.fromMap(r)).toList();
  }

  Future<double> getTotalPaymentsForBooking(int bookingId) async {
    final result = await _client
        .rpc('get_total_payments_for_booking', params: {'p_booking_id': bookingId});
    return ((result ?? 0) as num).toDouble();
  }

  Future<double> getTotalPayments() async {
    final result = await _client.rpc('get_total_payments');
    return ((result ?? 0) as num).toDouble();
  }

  Future<List<Payment>> getAllPayments() async {
    final data = await _client
        .from('payments')
        .select()
        .order('date', ascending: false);
    return (data as List).map((r) => Payment.fromMap(r)).toList();
  }

  Future<int> deletePayment(int id) async {
    await _client.from('payments').delete().eq('id', id);
    return id;
  }

  Future<int> updatePayment(Payment payment) async {
    if (payment.id == null) throw Exception('Payment ID required for update');
    await _client
        .from('payments')
        .update(payment.toMap())
        .eq('id', payment.id!);
    return payment.id!;
  }

  // === EXPENSES ===

  Future<int> insertExpense(Expense expense) async {
    final map = expense.toMap();
    map.remove('id');
    final result = await _client
        .from('expenses')
        .insert(map)
        .select('id')
        .single();
    return result['id'] as int;
  }

  Future<int> updateExpense(Expense expense) async {
    if (expense.id == null) throw Exception('Expense ID required for update');
    await _client
        .from('expenses')
        .update(expense.toMap())
        .eq('id', expense.id!);
    return expense.id!;
  }

  Future<int> deleteExpense(int id) async {
    await _client.from('expenses').delete().eq('id', id);
    return id;
  }

  Future<List<Expense>> getAllExpenses() async {
    final data = await _client
        .from('expenses')
        .select()
        .order('date', ascending: false);
    return (data as List).map((r) => Expense.fromMap(r)).toList();
  }

  Future<List<Expense>> getExpensesForMonth(int year, int month) async {
    final monthStr = month.toString().padLeft(2, '0');
    final data = await _client
        .from('expenses')
        .select()
        .like('date', '$year-$monthStr%')
        .order('date', ascending: true);
    return (data as List).map((r) => Expense.fromMap(r)).toList();
  }

  Future<double> getTotalExpenses() async {
    final result = await _client.rpc('get_total_expenses');
    return ((result ?? 0) as num).toDouble();
  }

  Future<double> getTotalExpensesForPeriod(DateTime start, DateTime end) async {
    final startStr = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endStr = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    final result = await _client.rpc('get_total_expenses_for_period', params: {
      'p_start': startStr,
      'p_end': endStr,
    });
    return ((result ?? 0) as num).toDouble();
  }

  Future<double> getTotalPaymentsForPeriod(DateTime start, DateTime end) async {
    final startStr = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endStr = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    final result = await _client.rpc('get_total_payments_for_period', params: {
      'p_start': startStr,
      'p_end': endStr,
    });
    return ((result ?? 0) as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getPaymentsWithBookingDetails(int year, int month) async {
    final monthStr = month.toString().padLeft(2, '0');
    final data = await _client
        .from('payments')
        .select('''
          id, amount, type, payment_method, date, notes,
          bookings!left(customer_name, event_type, hall_name, event_date, created_at)
        ''')
        .like('date', '$year-$monthStr%')
        .order('date', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, double>> getExpenseSummaryByCategory() async {
    final data = await _client
        .from('expenses')
        .select()
        .order('category', ascending: true);
    final map = <String, double>{};
    for (var row in (data as List)) {
      final cat = row['category'] as String;
      final amt = (row['amount'] as num).toDouble();
      map[cat] = (map[cat] ?? 0) + amt;
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> getMonthlyProfitReport() async {
    final result = await _client.rpc('get_monthly_profit_report');
    return (result as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  // === DECORATION CHARGES ===

  Future<int> insertDecorationCharge(DecorationCharge charge) async {
    final map = charge.toMap();
    map.remove('id');
    try {
      final result = await _client
          .from('decoration_charges')
          .insert(map)
          .select('id')
          .single();
      return result['id'] as int;
    } catch (e) {
      debugPrint('Error inserting decoration charge: $e');
      rethrow;
    }
  }

  Future<List<DecorationCharge>> getDecorationChargesForMonth(int year, int month) async {
    try {
      final monthStr = month.toString().padLeft(2, '0');
      final data = await _client
          .from('decoration_charges')
          .select()
          .like('date', '$year-$monthStr%')
          .order('date', ascending: true);
      return (data as List).map((r) => DecorationCharge.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error loading decoration charges: $e');
      return [];
    }
  }

  Future<List<DecorationCharge>> getAllDecorationCharges() async {
    try {
      final data = await _client
          .from('decoration_charges')
          .select()
          .order('date', ascending: false);
      return (data as List).map((r) => DecorationCharge.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error loading all decoration charges: $e');
      return [];
    }
  }

  Future<double> getTotalDecorationCharges() async {
    try {
      final data = await _client
          .from('decoration_charges')
          .select('amount');
      double total = 0;
      for (var row in (data as List)) {
        total += (row['amount'] as num).toDouble();
      }
      return total;
    } catch (e) {
      debugPrint('Error getting total decoration charges: $e');
      return 0;
    }
  }

  Future<int> deleteDecorationCharge(int id) async {
    try {
      await _client.from('decoration_charges').delete().eq('id', id);
      return id;
    } catch (e) {
      debugPrint('Error deleting decoration charge: $e');
      rethrow;
    }
  }

  // === DASHBOARD STATS ===

  Future<int> getUpcomingBookingsCount() async {
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final response = await _client
        .from('bookings')
        .select('id')
        .gte('event_date', dateStr)
        .eq('status', 'confirmed')
        .count(CountOption.exact);
    return response.count ?? 0;
  }

  Future close() async {
    // No-op for Supabase; connection is managed globally
  }
}
