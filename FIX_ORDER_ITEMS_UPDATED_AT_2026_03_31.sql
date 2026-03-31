-- Add updated_at column to order_items table
-- Fixes: PostgrestException: column "updated_at" of relation "order_items" does not exist
-- Date: March 31, 2026

-- Step 1: Add updated_at column to order_items table
ALTER TABLE public.order_items
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Step 2: Create trigger to auto-update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_order_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Create trigger that fires before any UPDATE on order_items
DROP TRIGGER IF EXISTS trigger_update_order_items_updated_at ON public.order_items;

CREATE TRIGGER trigger_update_order_items_updated_at
BEFORE UPDATE ON public.order_items
FOR EACH ROW
EXECUTE FUNCTION update_order_items_updated_at();

-- Step 4: Add index on updated_at for faster queries
CREATE INDEX IF NOT EXISTS idx_order_items_updated_at 
ON public.order_items(updated_at DESC);

-- Step 5: Add comment to document the column
COMMENT ON COLUMN public.order_items.updated_at IS 'Timestamp of last update. Auto-managed by trigger.';

-- Verification query
SELECT 
    c.column_name,
    c.data_type,
    c.column_default,
    c.is_nullable
FROM information_schema.columns c
WHERE c.table_name = 'order_items' 
AND c.column_name IN ('updated_at', 'business_id');
