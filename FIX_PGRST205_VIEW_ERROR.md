# Fix: PGRST205 - View 'vw_orders_with_items' Not Found

## Error

```
PostgrestException(message: {"code":"PGRST205","details":null,"hint":"Perhaps you meant the table 'public.order_items'","message":"Could not find the table 'public.vw_orders_with_items' in the schema cache"}
```

## Root Cause

The PostgreSQL view `public.vw_orders_with_items` is missing from the Supabase database or Postgrest hasn't refreshed its introspection cache.

## Solution

### Step 1: Execute the Migration on Supabase

1. Go to **Supabase Dashboard** → Your Project
2. Navigate to **SQL Editor**
3. Create a new query and paste the SQL from:
   ```
   migrations/002_create_vw_orders_with_items.sql
   ```
4. Execute the query

### OR Run via SQL File

In your terminal:

```bash
# Using supabase CLI
supabase db push

# OR manually via psql
psql "postgresql://[user]:[password]@[host]:[port]/[database]" < migrations/002_create_vw_orders_with_items.sql
```

### Step 2: Force Postgrest Cache Refresh (if needed)

If the error persists after creating the view:

1. Go to **Supabase Dashboard** → **Settings** → **API**
2. Click **Regenerate API keys** (this forces a Postgrest restart)
3. OR restart the Postgres instance via Supabase Dashboard

### Step 3: Rebuild Flutter App

```bash
flutter clean
flutter pub get
flutter run
```

## What This View Does

The view aggregates order data with its associated items:

- Joins `orders` table with `order_items` table
- Aggregates items into a JSON array for each order
- Used by `OrdersService` for realtime order updates and fetching

## Files Modified

- ✅ `migrations/002_create_vw_orders_with_items.sql` - Migration to create the view
- ✅ `lib/services/order_service.dart` - Added fallback error handling for realtime callbacks

## Verification

After executing the migration, verify the view exists in Supabase SQL Editor:

```sql
SELECT * FROM public.vw_orders_with_items LIMIT 1;
```

You should see orders with an `items` column containing JSON array of order items.
