import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/booking.dart';
import '../models/payment.dart';
import '../models/expense.dart';

class AppState extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // Data
  List<Booking> _bookings = [];
  List<Payment> _payments = [];
  List<Expense> _expenses = [];
  List<Booking> _todayBookings = [];

  // Dashboard stats
  int _upcomingCount = 0;
  double _totalRevenue = 0;
  double _totalExpenses = 0;
  double _netProfit = 0;

  bool _loading = false;

  // Getters
  List<Booking> get bookings => _bookings;
  List<Payment> get payments => _payments;
  List<Expense> get expenses => _expenses;
  List<Booking> get todayBookings => _todayBookings;
  int get upcomingCount => _upcomingCount;
  double get totalRevenue => _totalRevenue;
  double get totalExpenses => _totalExpenses;
  double get netProfit => _netProfit;
  bool get loading => _loading;

  Future<void> loadDashboard() async {
    _loading = true;
    notifyListeners();

    try {
      _upcomingCount = await _db.getUpcomingBookingsCount();
      _totalRevenue = await _db.getTotalPayments();
      _totalExpenses = await _db.getTotalExpenses();
      _netProfit = _totalRevenue - _totalExpenses;

      // Today's bookings
      final today = DateTime.now();
      _todayBookings = await _db.getBookingsForDate(today);
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> loadAllBookings() async {
    _bookings = await _db.getAllBookings();
    notifyListeners();
  }

  Future<List<Booking>> getBookingsForDate(DateTime date) async {
    return await _db.getBookingsForDate(date);
  }

  Future<List<Booking>> getBookingsForMonth(int year, int month) async {
    return await _db.getBookingsForMonth(year, month);
  }

  Future<Booking?> getBooking(int id) async {
    return await _db.getBooking(id);
  }

  Future<int> addBooking(Booking booking) async {
    final id = await _db.insertBooking(booking);
    await loadDashboard();
    return id;
  }

  Future<void> updateBooking(Booking booking) async {
    await _db.updateBooking(booking);
    await loadDashboard();
  }

  Future<void> deleteBooking(int id) async {
    await _db.deleteBooking(id);
    await loadDashboard();
  }

  Future<List<Booking>> searchBookings(String query) async {
    return await _db.searchBookings(query);
  }

  // Payments
  Future<List<Payment>> getPaymentsForBooking(int bookingId) async {
    return await _db.getPaymentsForBooking(bookingId);
  }

  Future<double> getTotalPaymentsForBooking(int bookingId) async {
    return await _db.getTotalPaymentsForBooking(bookingId);
  }

  Future<int> addPayment(Payment payment) async {
    final id = await _db.insertPayment(payment);
    // Update booking advance amount if it's an advance payment
    if (payment.type == 'advance') {
      final booking = await _db.getBooking(payment.bookingId);
      if (booking != null) {
        final totalAdvance = booking.advanceAmount + payment.amount;
        await _db.updateBooking(booking.copyWith(advanceAmount: totalAdvance));
      }
    }
    // Update booking status to completed if final payment brings it to total
    if (payment.type == 'final') {
      final booking = await _db.getBooking(payment.bookingId);
      if (booking != null) {
        final totalPaid = await _db.getTotalPaymentsForBooking(payment.bookingId);
        if (totalPaid >= booking.totalAmount) {
          await _db.updateBooking(booking.copyWith(status: 'completed'));
        }
      }
    }
    await loadDashboard();
    return id;
  }

  Future<void> deletePayment(int id) async {
    await _db.deletePayment(id);
  }

  Future<List<Payment>> getAllPayments() async {
    return await _db.getAllPayments();
  }

  // Expenses
  Future<void> loadAllExpenses() async {
    _expenses = await _db.getAllExpenses();
    notifyListeners();
  }

  Future<int> addExpense(Expense expense) async {
    final id = await _db.insertExpense(expense);
    await loadDashboard();
    return id;
  }

  Future<void> updateExpense(Expense expense) async {
    await _db.updateExpense(expense);
    await loadDashboard();
  }

  Future<void> deleteExpense(int id) async {
    await _db.deleteExpense(id);
    await loadDashboard();
  }

  // Reports
  Future<Map<String, double>> getExpenseSummaryByCategory() async {
    return await _db.getExpenseSummaryByCategory();
  }

  Future<List<Map<String, dynamic>>> getMonthlyProfitReport() async {
    return await _db.getMonthlyProfitReport();
  }

  Future<double> getTotalExpensesForPeriod(DateTime start, DateTime end) async {
    return await _db.getTotalExpensesForPeriod(start, end);
  }

  Future<double> getTotalPaymentsForPeriod(DateTime start, DateTime end) async {
    return await _db.getTotalPaymentsForPeriod(start, end);
  }
}
