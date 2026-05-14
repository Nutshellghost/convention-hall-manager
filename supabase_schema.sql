-- ========================================
-- Kusetty Convention Hall - Full Schema
-- ========================================

-- 1. TABLES

CREATE TABLE IF NOT EXISTS bookings (
  id SERIAL PRIMARY KEY,
  customer_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  event_date TEXT NOT NULL,
  event_type TEXT NOT NULL,
  hall_name TEXT NOT NULL,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  total_amount REAL NOT NULL,
  advance_amount REAL DEFAULT 0,
  status TEXT DEFAULT 'confirmed',
  notes TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS payments (
  id SERIAL PRIMARY KEY,
  booking_id INTEGER NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  amount REAL NOT NULL,
  type TEXT NOT NULL,
  payment_method TEXT DEFAULT 'cash',
  date TEXT NOT NULL,
  notes TEXT
);

CREATE TABLE IF NOT EXISTS expenses (
  id SERIAL PRIMARY KEY,
  category TEXT NOT NULL,
  description TEXT NOT NULL,
  amount REAL NOT NULL,
  date TEXT NOT NULL,
  notes TEXT
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_bookings_date ON bookings(event_date);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);
CREATE INDEX IF NOT EXISTS idx_payments_booking ON payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date);

-- 2. RPC FUNCTIONS (used by the app for aggregate queries)

CREATE OR REPLACE FUNCTION get_total_payments_for_booking(p_booking_id INTEGER)
RETURNS REAL AS $$
  SELECT COALESCE(SUM(amount), 0) FROM payments WHERE booking_id = p_booking_id;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_total_payments()
RETURNS REAL AS $$
  SELECT COALESCE(SUM(amount), 0) FROM payments;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_total_expenses()
RETURNS REAL AS $$
  SELECT COALESCE(SUM(amount), 0) FROM expenses;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_total_expenses_for_period(p_start TEXT, p_end TEXT)
RETURNS REAL AS $$
  SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE date >= p_start AND date <= p_end;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_total_payments_for_period(p_start TEXT, p_end TEXT)
RETURNS REAL AS $$
  SELECT COALESCE(SUM(amount), 0) FROM payments WHERE date >= p_start AND date <= p_end;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_monthly_profit_report()
RETURNS TABLE(month TEXT, total_payments REAL, total_expenses REAL, net_profit REAL) AS $$
  WITH payment_totals AS (
    SELECT substr(date, 1, 7) as m, SUM(amount) as tp
    FROM payments GROUP BY m
  ),
  expense_totals AS (
    SELECT substr(date, 1, 7) as m, SUM(amount) as te
    FROM expenses GROUP BY m
  ),
  all_months AS (
    SELECT DISTINCT m FROM (
      SELECT substr(date, 1, 7) as m FROM payments
      UNION
      SELECT substr(date, 1, 7) as m FROM expenses
    ) months
  )
  SELECT
    all_months.m,
    COALESCE(payment_totals.tp, 0),
    COALESCE(expense_totals.te, 0),
    COALESCE(payment_totals.tp, 0) - COALESCE(expense_totals.te, 0)
  FROM all_months
  LEFT JOIN payment_totals ON all_months.m = payment_totals.m
  LEFT JOIN expense_totals ON all_months.m = expense_totals.m
  ORDER BY all_months.m DESC;
$$ LANGUAGE SQL;

-- 3. RLS POLICIES (allow authenticated users full access to all tables)

ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'bookings' AND policyname = 'auth_all') THEN
    CREATE POLICY auth_all ON bookings
      USING (auth.role() = 'authenticated')
      WITH CHECK (auth.role() = 'authenticated');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'payments' AND policyname = 'auth_all') THEN
    CREATE POLICY auth_all ON payments
      USING (auth.role() = 'authenticated')
      WITH CHECK (auth.role() = 'authenticated');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'expenses' AND policyname = 'auth_all') THEN
    CREATE POLICY auth_all ON expenses
      USING (auth.role() = 'authenticated')
      WITH CHECK (auth.role() = 'authenticated');
  END IF;
END $$;

-- 4. Enable auth users to sign up (email/password)
-- This is enabled by default in Supabase Auth settings
