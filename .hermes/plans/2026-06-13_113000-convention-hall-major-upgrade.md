# Convention Hall Manager — Major Upgrade Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Upgrade the Kusetty Convention Hall Manager Android app from v1.0.0 to the refined version matching previous May '26 feature set — per-month dashboard, decoration charges, PDF export, profit sharing, simplified forms, and bug fixes.

**Architecture:** Flutter + Supabase (existing). Add new Supabase table `decoration_charges`, new Flutter model, 2 new screens, and refactor 5 existing screens. Remove fl_chart dependency (charts replaced by per-transaction lists).

**Tech Stack:** Flutter 3.41.9+, supabase_flutter, provider, intl, pdf v3.11, path_provider, share_plus v10, table_calendar

---

## Task 1: Add missing dependencies (pdf, path_provider, share_plus)

**Objective:** Add PDF generation and file sharing dependencies to pubspec.yaml

**Files:**
- Modify: `pubspec.yaml`

**Changes:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  supabase_flutter: any
  table_calendar: any
  intl: any
  provider: any
  pdf: ^3.11.0
  path_provider: ^2.1.0
  share_plus: ^10.0.0
```

**Remove:**
```yaml
  fl_chart: ^0.69.0
```

**Verify:** Run `cd ~/workspace/convention_hall_manager && flutter pub get`

---

## Task 2: Create DecorationCharge model

**Objective:** New model for decoration charges with its own Supabase table

**Files:**
- Create: `lib/models/decoration_charge.dart`

```dart
class DecorationCharge {
  final int? id;
  final String customerName;
  final double amount;
  final DateTime date;
  final String? notes;

  DecorationCharge({
    this.id,
    required this.customerName,
    required this.amount,
    DateTime? date,
    this.notes,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'customer_name': customerName,
      'amount': amount,
      'date': date.toIso8601String().split('T')[0],
      'notes': notes,
    };
  }

  factory DecorationCharge.fromMap(Map<String, dynamic> map) {
    return DecorationCharge(
      id: map['id'] as int?,
      customerName: map['customer_name'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
    );
  }
}
```

---

## Task 3: Add decoration_charges DB methods to DatabaseHelper

**Objective:** Add CRUD operations for decoration charges to database_helper.dart

**Files:**
- Modify: `lib/data/database_helper.dart`

Add methods:
- `insertDecorationCharge(DecorationCharge)` — insert into `decoration_charges` table, return id
- `getAllDecorationCharges()` — select all, order by date desc
- `getDecorationChargesForMonth(int year, int month)` — filter by date LIKE 'YYYY-MM%'
- `getTotalDecorationCharges()` — RPC or sum in Dart
- `deleteDecorationCharge(int id)` — delete by id

**NOTE:** Wrapped all decoration_charges queries in try-catch returning empty/0 to handle missing table gracefully (PGRST205 error).

---

## Task 4: Refactor AppState — parallel queries, no loadDashboard cascade

**Objective:** Per skill spec — CRUD methods do minimal work (just DB op). Caller handles one targeted refresh. Also add decoration charge state.

**Files:**
- Modify: `lib/providers/app_state.dart`

**Changes:**
- Add `List<DecorationCharge> _decorationCharges` + getter
- Add `Future<void> loadAllDecorationCharges()` — load list + notify
- Remove `loadDashboard()` calls from `addBooking`, `updateBooking`, `deleteBooking`, `addPayment`, `addExpense`, `updateExpense`, `deleteExpense`
- Keep `addPayment` logic that updates advance amount + checks auto-complete
- Add `_monthRevenue`, `_monthExpenses`, `_monthNetProfit` fields per-month
- Add `loadMonthStats(int year, int month)` — parallel query: payments for month, expenses for month, decoration for month
- Add `updatePayment(Payment payment)` method for edit-payment flow
- Add `Future<Map<String, dynamic>> getMonthDetail(int year, int month)` for reports

---

## Task 5: Fix showDatePicker UTC bug everywhere

**Objective:** Every `showDatePicker` call must reconstruct DateTime to avoid UTC epoch issues in IST (UTC+5:30).

**Files affected:**
- Modify: `lib/screens/add_booking_screen.dart` (line ~157)
- Modify: `lib/screens/dashboard_screen.dart` (AddEditExpenseScreen, line ~462)
- Modify: `lib/screens/booking_detail_screen.dart` (any date pickers)

**Pattern to apply everywhere:**
```dart
if (picked != null) {
  final local = DateTime(picked.year, picked.month, picked.day);
  setState(() => _selectedDate = local);
}
```

---

## Task 6: Simplify expense categories (12 → 3)

**Objective:** Reduce to: Miscelleneous, Electricity, Renovation — synced across all 5 files.

**Files:**
- Modify: `lib/screens/dashboard_screen.dart` — `_categories` list + initState default
- Modify: `lib/screens/expenses_screen.dart` — `_getCategoryColor()` + `_getCategoryIcon()`
- Modify: `lib/screens/reports_screen.dart` — `_getCategoryColor()`

**New category list:**
```dart
final List<String> _categories = ['Miscelleneous', 'Electricity', 'Renovation'];
```

**New colors:**
- Miscelleneous → Colors.grey
- Electricity → Colors.amber
- Renovation → Colors.deepOrange

**New icons:**
- Miscelleneous → Icons.receipt
- Electricity → Icons.bolt
- Renovation → Icons.construction

---

## Task 7: Simplify hall names (5 → 2)

**Objective:** Only "Main Hall" and "Rooftop Gardenia"

**Files:**
- Modify: `lib/screens/add_booking_screen.dart` (line ~38-41)

```dart
final List<String> _hallNames = ['Main Hall', 'Rooftop Gardenia'];
```

---

## Task 8: Change event type from dropdown to free-text field

**Objective:** Event Type becomes a TextFormField, not dropdown.

**Files:**
- Modify: `lib/screens/add_booking_screen.dart`

**Changes:**
- Remove `_eventTypes` list
- Replace `DropdownButtonFormField<String>` for event type with `TextFormField`
- Add a `TextEditingController _eventTypeController`
- Remove `_eventType` state variable, use controller text

---

## Task 9: Rewrite Dashboard with month slider + per-month stats + quick actions

**Objective:** Replace all-time stats with per-month stats using month slider (← → arrows). Cards: Upcoming Functions (tappable → Bookings), Total Revenue, Total Expenses, Net Profit. Quick actions: New Booking, Decoration.

**Files:**
- Rewrite: `lib/screens/dashboard_screen.dart`

**Structure:**
- Change from StatelessWidget to StatefulWidget
- Month state: `_selectedMonth`, `_selectedYear`
- arrows → `_previousMonth()`, `_nextMonth()`
- `_loadMonthStats()` called on init + month change
- Cards: Upcoming Bookings (count, tappable), Revenue, Expenses, Net Profit
- Remove: Today's Bookings section, Signed In card, Total Revenue/Expenses/Profit as all-time
- Quick actions: New Booking, Decoration (opens decoration charges screen)
- AppBar: "Kusetty Convention Hall" title, refresh icon, logout icon

---

## Task 10: Create Decoration Charges screens

**Objective:** New screen for listing/managing decoration charges + quick-add form.

**Files:**
- Create: `lib/screens/decoration_charges_screen.dart` — list with total header, swipe-to-delete
- Create: `lib/screens/add_decoration_charge_screen.dart` — form (customer name, amount, date picker, notes)
- Create: `lib/screens/decoration_charges_list_screen.dart` — or embed in existing list

**Decoration Charges List Screen:**
- Scaffold with AppBar + add button
- Total header card
- List of decoration charges (customer name, amount, date)
- Long-press delete with confirmation

**Add Decoration Charge Form:**
- Customer name (TextFormField)
- Amount (TextFormField, number keyboard)
- Date picker (with UTC bug fix)
- Notes (optional, multiline)
- Save button

---

## Task 11: Rewrite Reports with month picker + per-transaction breakdown + PDF export

**Objective:** Remove fl_chart charts. Add month picker (← → arrows) with per-transaction income/expense/decoration breakdown. Add PDF export button.

**Files:**
- Rewrite: `lib/screens/reports_screen.dart`

**Structure:**
- StatefulWidget with month/year state + arrows
- `_loadMonthDetail(year, month)` — 4 parallel queries (payments for month with booking join, expenses for month, decoration charges for month)
- **Income section:** List of payments with booking details (customer, type, amount, date)
- **Expense section:** List of expenses (category, description, amount, date)
- **Summary card:** Total Income, Total Expenses, Net Profit
- **Profit Sharing card:** 50/50 split between Raja Gopal / Guru Prasad
- **PDF Export:** IconButton in AppBar → generates PDF with income table, decoration charges table, expense table, summary, profit sharing. Uses `Share.shareXFiles()` after save.

---

## Task 12: Add Edit Payment flow in Booking Detail

**Objective:** Tapping a payment card opens edit dialog with pre-filled amount and payment method.

**Files:**
- Modify: `lib/screens/booking_detail_screen.dart`

**Changes:**
- Add `_editPayment(Payment payment)` method
- Dialog shows amount (pre-filled) + payment method dropdown (pre-filled)
- On save: calls `state.updatePayment(payment)` then `_loadData()` refreshes totals
- Add `updatePayment` method to AppState and DatabaseHelper (supabase update by id)
- Auto-complete check: if total paid >= totalAmount after editing a final payment, mark booking completed

**DB method:**
```dart
Future<int> updatePayment(Payment payment) async {
  await _client.from('payments').update(payment.toMap()).eq('id', payment.id!);
  return payment.id!;
}
```

---

## Task 13: Add booking date to booking form

**Objective:** Show a "Booking Date" editable date picker above the "Function Date" picker.

**Files:**
- Modify: `lib/screens/add_booking_screen.dart`

**Changes:**
- Add `_bookingDate = DateTime.now()` state
- Add date picker ListTile for booking date above function date
- When creating booking with advance payment, payment date = `_bookingDate` (not `DateTime.now()`)

---

## Task 14: Add decoration_charges RLS policy (manual)

**Objective:** New table needs RLS policy for authenticated users.

**Action:** User must run in Supabase SQL editor:
```sql
ALTER TABLE decoration_charges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_all" ON decoration_charges
  FOR ALL
  TO authenticated
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');
```

User to do via Supabase dashboard at https://app.supabase.com (since dashboard has captcha).

---

## Task 15: Build APK and deploy

**Objective:** Build Android debug APK, copy to OneDrive Desktop.

**Files:**
- Output: `build/app/outputs/flutter-apk/app-debug.apk`

**Commands:**
```bash
cd ~/workspace/convention_hall_manager
export JAVA_HOME=$HOME/java/jdk-17.0.11
export ANDROID_HOME="/mnt/c/Users/Kusetty Chaithanya/AppData/Local/Android/Sdk"
~/flutter/bin/flutter build apk --debug
cp build/app/outputs/flutter-apk/app-debug.apk "/mnt/c/Users/Kusetty Chaithanya/OneDrive/Desktop/ConventionHallManager.apk"
```

---

## Risks & Tradeoffs

1. **CRUD cascade refactor (Task 4):** List screens that depend on auto-refresh (expenses list via Consumer) will appear stale until pull-to-refresh. Acceptable per previous user preference.
2. **Supabase RLS (Task 14):** Requires manual intervention — captcha on Supabase dashboard prevents automation.
3. **Existing data:** Decoration charges table is new — existing bookings/payments/expenses unaffected.
4. **Editable payment (Task 12):** Editing a payment's amount may affect auto-complete logic. Must re-check total after edit.
5. **PDF dependency versions:** pdf v3.11 uses `TableHelper.fromTextArray` with `data:` not `rows:`. Must verify.

## Verification

After all tasks:
1. `flutter analyze` — zero errors
2. `flutter build apk --debug` — success
3. APK installs on Android and all features work:
   - Login → dashboard shows per-month stats
   - Create booking with advance payment → appears in dashboard
   - Add decoration charge → appears in reports
   - Add expense → 3 categories only
   - Reports → month picker works, PDF exports
   - Booking detail → edit payment updates totals
