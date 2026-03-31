-- Add business_id column to order_items table
-- Fixes: PostgrestException: Could not find the 'business_id' column of 'order_items' in the schema cache
-- Date: March 31, 2026

-- Step 1: Add business_id column to order_items table (nullable initially)
-- Type: TEXT to match orders.business_id format (e.g., "POS001")
ALTER TABLE public.order_items
ADD COLUMN IF NOT EXISTS business_id TEXT;

-- Step 2: Update existing order items with business_id from their related orders
-- This ensures existing data is consistent with the new schema
UPDATE public.order_items oi
SET business_id = o.business_id
FROM public.orders o
WHERE oi.order_id = o.id
AND oi.business_id IS NULL;

-- Step 2b: Add NOT NULL constraint after populating the column
ALTER TABLE public.order_items
ALTER COLUMN business_id SET NOT NULL;

-- Step 3: Add foreign key constraint to businesses table (optional)
-- Only if businesses table has business_id as a key. Adjust or remove if using different schema
-- ALTER TABLE public.order_items
-- ADD CONSTRAINT fk_order_items_business_id 
-- FOREIGN KEY (business_id) REFERENCES public.businesses(business_id) ON DELETE CASCADE;

-- Step 4: Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_order_items_business_id 
ON public.order_items(business_id);

CREATE INDEX IF NOT EXISTS idx_order_items_order_business 
ON public.order_items(order_id, business_id);

-- Step 5: Add comment to document the column
COMMENT ON COLUMN public.order_items.business_id IS 'Business ID (TEXT format like "POS001") for routing items to correct kitchen displays and inventory systems.';

-- Verification query
SELECT 
    c.column_name,
    c.data_type,
    c.column_default,
    c.is_nullable
FROM information_schema.columns c
WHERE c.table_name = 'order_items' 
AND c.column_name = 'business_id';
