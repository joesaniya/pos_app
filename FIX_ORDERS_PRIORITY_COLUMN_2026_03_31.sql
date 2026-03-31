-- Add priority column to orders table
-- Fixes: PostgrestException: record "new" has no field "priority"
-- Date: March 31, 2026

-- Step 1: Add priority column to orders table
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'normal'
CHECK (priority IN ('urgent', 'high', 'normal', 'low'));

-- Step 2: Add comment to document the column
COMMENT ON COLUMN public.orders.priority IS 'Order priority level: urgent, high, normal, or low. Used for KOT prioritization.';

-- Step 3: Create index for faster priority-based queries
CREATE INDEX IF NOT EXISTS idx_orders_priority 
ON public.orders(business_id, priority DESC, created_at DESC);

-- Step 4: Update existing records (if any) to ensure they have the default priority
UPDATE public.orders 
SET priority = 'normal' 
WHERE priority IS NULL;

-- Verification query
SELECT 
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'orders' AND column_name = 'priority';
