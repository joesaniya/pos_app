-- Migration: Add SKU and Reference ID columns to inventory_items table
-- Date: April 2, 2026
-- Purpose: Support duplicate detection using SKU and Reference ID fields
-- 
-- These columns are used for:
-- 1. SKU (Stock Keeping Unit) - Unique product identifier
-- 2. Reference ID - Supplier or external reference identifier
--
-- Both columns support duplicate detection during bulk uploads

-- Add SKU column (optional, for duplicate detection)
ALTER TABLE inventory_items
ADD COLUMN IF NOT EXISTS sku VARCHAR(255) NULL UNIQUE,
ADD COLUMN IF NOT EXISTS reference_id VARCHAR(255) NULL;

-- Create indexes for faster duplicate detection
CREATE INDEX IF NOT EXISTS idx_inventory_items_sku ON inventory_items(sku) 
WHERE sku IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_inventory_items_reference_id ON inventory_items(reference_id) 
WHERE reference_id IS NOT NULL;

-- Add comments for documentation
COMMENT ON COLUMN inventory_items.sku IS 'Stock Keeping Unit - Unique product identifier for duplicate detection during bulk uploads';
COMMENT ON COLUMN inventory_items.reference_id IS 'External/supplier reference identifier for duplicate detection during bulk uploads';

-- Verify the schema
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'inventory_items' 
AND column_name IN ('sku', 'reference_id')
ORDER BY column_name;
