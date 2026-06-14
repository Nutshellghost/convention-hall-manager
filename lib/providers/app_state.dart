import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/booking.dart';
import '../models/payment.dart';
import '../models/expense.dart';
import '../models/decoration_charge.dart';

class AppState extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // Bookings
  List<Booking> _bookings = [];
  int _upcomingCount = 0;

  // Payments
  List<Payment> _payments = [];

  // Expenses
  List<Expense> _expenses = [];

  // Decoration charges
  List<DecorationCharge> _decorationCharges = [];

  // Dashboard all-time stats
  double _totalRevenue = 0;
  double _totalExpenses = 0;
  double _netProfit = 0;

  // Month-specific stats
  double _monthRevenue = 0;
  double _monthExpenses = 0;
  double _monthNetProfit = 0;
  double _monthDecoration = 0;

  bool _loading = false;

  // Getters
  List<Booking> get bookings => _bookings;
  List<Payment> get payments => _payments;
  List<Expense> get expenses => _expenses;
  List<DecorationCharge> get decorationCharges => _decorationCharges;
  int get upcomingCount => _upcomingCount;
  double get totalRevenue => _totalRevenue;
  double get totalExpenses => _totalExpenses;
  double get netProfit => _netProfit;
  double get monthRevenue => _monthRevenue;
  double get monthExpenses => _monthExpenses;
  double get monthNetProfit => _monthNetProfit;
  double get monthDecoration => _monthDecoration;
  bool get loading => _loading;

  // Dashboard — all-time totals
  Future<void> loadDashboard() async {
    _loading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _db.getUpcomingBookingsCount(),
        _db.getTotalPayments(),
        _db.getTotalExpenses(),
        _db.getTotalDecorationCharges(),
      ]);

      _upcomingCount = results[0] as int;
      _totalRevenue = (results[1] as num).toDouble();
      _totalExpenses = (results[2] as num).toDouble();
      final decorationTotal = (results[3] as num).toDouble();
      _netProfit = _totalRevenue + decorationTotal - _totalExpenses;
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    }

    _loading = false;
    notifyListeners();
  }

  // Month-specific stats (with upcoming count)
  Future<void> loadMonthStats(int year, int month) async {
    try {
      final results = await Future.wait([
        _db.getTotalPaymentsForPeriod(
          DateTime(year, month, 1),
          DateTime(year, month + 1, 0),
        ),
        _db.getTotalExpensesForPeriod(
          DateTime(year, month, 1),
          DateTime(year, month + 1, 0),
        ),
        _db.getDecorationChargesForMonth(year, month),
        _db.getUpcomingBookingsCount(),
      ]);

      _monthRevenue = results[0] as double;
      _monthExpenses = results[1] as double;
      final decorationList = results[2] as List<DecorationCharge>;
      _monthDecoration = decorationList.fold<double>(0, (sum, c) => sum + c.amount);
      _monthNetProfit = _monthRevenue + _monthDecoration - _monthExpenses;
      _upcomingCount = results[3] as int;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading month stats: $e');
    }
  }

  // Bookings
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
    return await _db.insertBooking(booking);
  }

  Future<void> updateBooking(Booking booking) async {
    await _db.updateBooking(booking);
  }

  Future<void> deleteBooking(int id) async {
    await _db.deleteBooking(id);
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
    if (payment.type == 'advance') {
      final booking = await _db.getBooking(payment.bookingId);
      if (booking != null) {
        final totalAdvance = booking.advanceAmount + payment.amount;
        await _db.updateBooking(booking.copyWith(advanceAmount: totalAdvance));
      }
    }
    if (payment.type == 'final') {
      final booking = await _db.getBooking(payment.bookingId);
      if (booking != null) {
        final totalPaid = await _db.getTotalPaymentsForBooking(payment.bookingId);
        if (totalPaid >= booking.totalAmount) {
          await _db.updateBooking(booking.copyWith(status: 'completed'));
        }
      }
    }
    return id;
  }

  Future<void> updatePayment(Payment payment) async {
    await _db.updatePayment(payment);
    // Re-check auto-complete after edit
    if (payment.type == 'final') {
      final booking = await _db.getBooking(payment.bookingId);
      if (booking != null) {
        final totalPaid = await _db.getTotalPaymentsForBooking(payment.bookingId);
        if (totalPaid >= booking.totalAmount) {
          await _db.updateBooking(booking.copyWith(status: 'completed'));
        }
      }
    }
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
    return await _db.insertExpense(expense);
  }

  Future<void> updateExpense(Expense expense) async {
    await _db.updateExpense(expense);
  }

  Future<void> deleteExpense(int id) async {
    await _db.deleteExpense(id);
  }

  // Decoration Charges
  Future<void> loadAllDecorationCharges() async {
    _decorationCharges = await _db.getAllDecorationCharges();
    notifyListeners();
  }

  Future<int> addDecorationCharge(DecorationCharge charge) async {
    final id = await _db.insertDecorationCharge(charge);
    return id;
  }

  Future<void> deleteDecorationCharge(int id) async {
    await _db.deleteDecorationCharge(id);
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

  // Delete all data
  Future<void> deleteAllData() async {
    await _db.deleteAllData();
    _bookings = [];
    _payments = [];
    _expenses = [];
    _decorationCharges = [];
    _totalRevenue = 0;
    _totalExpenses = 0;
    _netProfit = 0;
    _monthRevenue = 0;
    _monthExpenses = 0;
    _monthNetProfit = 0;
    _monthDecoration = 0;
    _upcomingCount = 0;
    notifyListeners();
  }
}
