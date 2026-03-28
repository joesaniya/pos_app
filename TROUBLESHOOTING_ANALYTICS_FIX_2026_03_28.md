# Analytics Still Showing Wrong Data - Troubleshooting Guide
**Date:** March 28, 2026

## Problem
Analytics dashboard (Weekly/Monthly/Yearly) still shows ₹0 revenue instead of ₹79.

## Root Cause Analysis

The issue is likely one of these:

### ❌ Issue #1: SQL Function Not Deployed to Supabase
**Symptom:** Analytics shows ₹0, no RPC errors in console  
**Cause:** `fn_revenue_summary()` RPC doesn't exist or has wrong signature

**Check:** Run this diagnostic query in Supabase SQL Editor
```sql
SELECT proname, pronargs 
FROM pg_proc 
WHERE proname = 'fn_revenue_summary';
```
- If **EMPTY result**: Function doesn't exist → Deploy SQL ⬇️
- If **shows function**: May have wrong signature → Redeploy SQL ⬇️

### ❌ Issue #2: RPC Returns Data in Wrong Format
**Symptom:** RPC called but values parsed as 0  
**Cause:** Supabase deserializes RETURNS TABLE as List, not Map

**Check:** Look for in Flutter console:
```
📈 current period RPC raw result: [...]
📈 current period RPC raw result: {...}
```
- If shows `[...]` (List): Enhanced parser handles it ✅
- If shows `{...}` (Map): Enhanced parser handles it ✅

### ❌ Issue #3: Business ID Mismatch
**Symptom:** RPC returns empty, no orders found  
**Cause:** Analytics using different business_id than dashboard

**Check:** In Flutter console, look for:
```
📈 AnalyticsProvider: role=... biz=...
```
- Copy the `biz=` value
- In Supabase SQL Editor, verify orders exist for that business:
```sql
SELECT COUNT(*) FROM orders WHERE business_id = 'that-business-id';
```

### ❌ Issue #4: Date Range Excludes Today's Orders
**Symptom:** Weekly view shows 0 when should show today's data  
**Cause:** Timezone conversion issue between local and UTC

**Check:** In Flutter console, look for:
```
📈 Weekly date ranges:
  Current: 2026-03-24... → 2026-03-31...
  UTC: 2026-03-24... → 2026-03-30...
```
- If dates look wrong (off by 1 day): May be timezone issue

---

## ✅ Complete Fix - Do This Now

### Step 1: Deploy the SQL Function to Supabase

**Copy this ENTIRE query** and run in Supabase SQL Editor:

```sql
-- Drop old function (if exists)
DROP FUNCTION IF EXISTS fn_revenue_summary(TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) CASCADE;

-- Create CORRECTED function
CREATE FUNCTION fn_revenue_summary(
  p_business_id TEXT,
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ,
  p_staff_uid TEXT DEFAULT NULL
)
RETURNS TABLE (
  total_revenue DECIMAL,
  total_orders BIGINT,
  avg_order DECIMAL,
  completed BIGINT,
  cancelled BIGINT,
  cancel_rate DECIMAL
) LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_total_revenue DECIMAL := 0;
  v_avg_order DECIMAL := 0;
  v_completed BIGINT := 0;
  v_cancelled BIGINT := 0;
  v_total_orders BIGINT := 0;
  v_cancel_rate DECIMAL := 0;
BEGIN
  -- Get completed orders (with paid payment status)
  SELECT
    COALESCE(SUM(total_amount), 0)::DECIMAL,
    CASE WHEN COUNT(*) > 0 THEN COALESCE(AVG(total_amount), 0)::DECIMAL ELSE 0 END,
    COUNT(*)::BIGINT
  INTO v_total_revenue, v_avg_order, v_completed
  FROM orders
  WHERE business_id = p_business_id
    AND status = 'completed'
    AND payment_status = 'paid'
    AND created_at >= p_from
    AND created_at < p_to
    AND (p_staff_uid IS NULL OR created_by_uid = p_staff_uid);

  -- Get cancelled orders
  SELECT COUNT(*)::BIGINT
  INTO v_cancelled
  FROM orders
  WHERE business_id = p_business_id
    AND status = 'cancelled'
    AND created_at >= p_from
    AND created_at < p_to
    AND (p_staff_uid IS NULL OR created_by_uid = p_staff_uid);

  v_total_orders := v_completed + v_cancelled;

  v_cancel_rate := CASE 
    WHEN v_total_orders > 0 THEN ROUND((v_cancelled::DECIMAL / v_total_orders::DECIMAL * 100), 2)
    ELSE 0
  END;

  RETURN QUERY SELECT v_total_revenue, v_total_orders, v_avg_order, v_completed, v_cancelled, v_cancel_rate;
END;
$$;

GRANT EXECUTE ON FUNCTION fn_revenue_summary(TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT)
TO anon, authenticated;
```

**Expected:** ✅ PostgreSQL function created successfully

### Step 2: Test the Function in Supabase

Run this query to verify it works (replace business-id):

```sql
SELECT * FROM fn_revenue_summary(
  'your-actual-business-id-here',
  NOW() - INTERVAL '7 days',
  NOW()
);
```

**Expected Result:**
```
total_revenue | total_orders | avg_order | completed | cancelled | cancel_rate
──────────────┼──────────────┼───────────┼───────────┼───────────┼────────────
79            | 20           | 79        | 1         | 19        | 95.00
```

If empty or wrong data → Check business ID and order data

### Step 3: Update Flutter Code (Already Done ✅)

The Dart code has been updated with:
- ✅ Better RPC response parsing (handles List and Map)
- ✅ Enhanced error handling and logging
- ✅ Debug logging for all steps

**Just hot restart the app:**

```bash
# Option 1: In VS Code
Ctrl+Shift+P → "Flutter: Clean"
then F5 or "Flutter: Hot Reload"

# Option 2: Terminal
cd d:\SriSoftwarez-projects\pos_app
flutter clean
flutter pub get
flutter run -d windows
```

### Step 4: Monitor Debug Output

Watch the Flutter console for these logs:

```
📈 Weekly date ranges (LOCAL timezone):
  Current: ... → ...
  UTC: ... → ...

📈 Weekly current period RPC raw result: {...} or [...]
  Parsed: {total_revenue: 79, total_orders: 20, ...}

📈 Weekly RPC results (parsed):
  Current: revenue=79 orders=20 completed=1 cancelled=19

📈 Weekly extracted metrics:
  totalRevenue: 79.0
  totalOrders: 20
  completed: 1
  cancelled: 19

📈 Weekly stats: total=₹79 avg=₹79 highest=₹79 orders=20
```

If you see these values correctly, **the fix is working!** ✅

---

## 🔍 Debugging Checklist

- [ ] **Deployed SQL function to Supabase?**
  - Verify in Supabase SQL Editor
  - Run test query returns correct data

- [ ] **Business ID matches between dashboard and analytics?**
  - Check Firebase Firestore user doc for correct businessId
  - Verify orders exist for that businessId

- [ ] **Hot restarted Flutter app?**
  - Not just hot reload, but full clean + restart
  - Watch console for debug logs

- [ ] **Checking console debug output?**
  - Look for `📈` prefixed messages
  - Verify values are not 0

- [ ] **Date ranges in UTC are correct?**
  - Local time should convert properly to UTC
  - Check timezone setting matches IST (Asia/Kolkata)

---

## Quick Verification

After deployment, visit the dashboard:

1. **Go to Analytics → Weekly**
2. Should see:
   - Total Revenue: ₹79 ✅
   - Order Count: 20 ✅
   - Average: ₹79 ✅
   - Highest: ₹79 ✅
   - Chart with data ✅

3. **Compare with Overview:**
   - Revenue should match ✅
   - Order count should match ✅

---

## If Still Not Working

1. **Check Supabase function exists:**
```sql
SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'fn_revenue_summary');
-- Should return: true
```

2. **Check orders table has data:**
```sql
SELECT COUNT(*) FROM orders WHERE business_id IN (
  SELECT DISTINCT business_id FROM orders
);
```

3. **Test RPC directly from browser console** (if accessible):
```javascript
// In browser console on analytics dashboard
const result = await supabaseClient.rpc('fn_revenue_summary', {
  p_business_id: 'YOUR-BUSINESS-ID',
  p_from: '2026-03-28T00:00:00Z',
  p_to: '2026-03-29T00:00:00Z'
});
console.log(result);
```

4. **Check Firebase Firestore** for correct user roleand businessId:
   - Collection: `users`
   - Doc: Your user's UID
   - Fields: `role`, `businessId`

---

## Success Indicators ✅

- [ ] SQL function deployed and tested
- [ ] Flutter console shows correct parsed values
- [ ] Analytics Weekly shows ₹79 (not ₹0)
- [ ] Analytics Overview and Weekly match
- [ ] Charts show data (not empty)
- [ ] Growth rate calculates correctly

**File Status:**
- ✅ `FIX_REVENUE_ANALYTICS_DASHBOARD_2026_03_28.sql` - Ready to use
- ✅ `lib/providers/analytics_provider.dart` - Updated with better parsing & error handling
- ✅ `DIAGNOSTIC_ANALYTICS_FIX_2026_03_28.sql` - Use for troubleshooting
- ✅ `DEPLOYMENT_GUIDE_ANALYTICS_FIX_2026_03_28.md` - Full deployment steps
