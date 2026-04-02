-- ═══════════════════════════════════════════════════════════════════════════════
--  BULK UPLOAD INVENTORY HISTORY & DUPLICATE HANDLING
--  Date: 2026-04-01
--  Purpose: Track stock history when bulk uploading and handle duplicate detection
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 1: INVENTORY_BULK_UPLOAD_HISTORY
-- ─────────────────────────────────────────────────────────────────────────────
-- Tracks all bulk upload operations for audit trail and duplicate handling
-- Allows rollback/reverse of bulk uploads if needed

CREATE TABLE IF NOT EXISTS public.inventory_bulk_upload_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id TEXT NOT NULL,
  
  -- Upload batch tracking
  upload_batch_id UUID NOT NULL DEFAULT uuid_generate_v4(), -- Groups all items from same upload
  upload_date TIMESTAMPTZ DEFAULT NOW(),
  
  -- Item handling
  item_id UUID NOT NULL REFERENCES public.inventory_items(id) ON DELETE CASCADE,
  item_name TEXT NOT NULL,
  
  -- Stock change details
  action TEXT NOT NULL CHECK (action IN ('new_item', 'stock_appended', 'stock_updated', 'skipped', 'duplicate_detected')),
  quantity_added NUMERIC(10,3),
  stock_before NUMERIC(10,3),
  stock_after NUMERIC(10,3),
  
  -- Duplicate info (if action = 'duplicate_detected')
  duplicate_of_item_id UUID REFERENCES public.inventory_items(id) ON DELETE SET NULL,
  duplicate_detection_method TEXT CHECK (
    duplicate_detection_method IN ('exact_name_supplier', 'name_only', 'sku', NULL)
  ),
  
  -- Supplier info
  supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL,
  supplier_name TEXT,
  
  -- Entry details from spreadsheet
  cost_per_unit NUMERIC(10,2),
  unit TEXT,
  category TEXT,
  
  -- User info
  uploaded_by_uid TEXT,
  uploaded_by_name TEXT,
  uploaded_by_role TEXT,
  
  -- Notes
  notes TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_inventory_upload_history_business 
  ON public.inventory_bulk_upload_history(business_id);

CREATE INDEX IF NOT EXISTS idx_inventory_upload_history_batch 
  ON public.inventory_bulk_upload_history(upload_batch_id);

CREATE INDEX IF NOT EXISTS idx_inventory_upload_history_item 
  ON public.inventory_bulk_upload_history(item_id);

CREATE INDEX IF NOT EXISTS idx_inventory_upload_history_action 
  ON public.inventory_bulk_upload_history(action);

CREATE INDEX IF NOT EXISTS idx_inventory_upload_history_created 
  ON public.inventory_bulk_upload_history(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_inventory_upload_history_business_batch 
  ON public.inventory_bulk_upload_history(business_id, upload_batch_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 2: INVENTORY_MASTER_DATA_ADDITIONS (auto-sync events)
-- ─────────────────────────────────────────────────────────────────────────────
-- Tracks when users create new categories, suppliers, or units in templates
-- Used to immediately sync new master data for future dropdowns

CREATE TABLE IF NOT EXISTS public.inventory_master_data_additions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id TEXT NOT NULL,
  
  -- What was added
  data_type TEXT NOT NULL CHECK (data_type IN ('category', 'supplier', 'unit', 'tag')),
  value_name TEXT NOT NULL,
  
  -- Reference (if created in system tables)
  category_id UUID REFERENCES public.menu_categories(id) ON DELETE SET NULL,
  supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL,
  
  -- Context
  added_on_template BOOLEAN DEFAULT TRUE, -- Added while downloading template
  added_in_ui BOOLEAN DEFAULT FALSE, -- Added manually in UI
  upload_batch_id UUID, -- Link to upload batch that triggered creation
  
  -- User info
  created_by_uid TEXT,
  created_by_name TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Denormalized for quick template refresh
  template_version INT DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_master_data_additions_business 
  ON public.inventory_master_data_additions(business_id);

CREATE INDEX IF NOT EXISTS idx_master_data_additions_type 
  ON public.inventory_master_data_additions(data_type);

CREATE INDEX IF NOT EXISTS idx_master_data_additions_created 
  ON public.inventory_master_data_additions(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_master_data_additions_batch 
  ON public.inventory_master_data_additions(upload_batch_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- FUNCTION: fn_append_inventory_stock
-- ─────────────────────────────────────────────────────────────────────────────
-- Safely appends stock to existing inventory item and records history
-- Used when bulk upload detects duplicate and should append stock

CREATE OR REPLACE FUNCTION public.fn_append_inventory_stock(
  p_item_id UUID,
  p_business_id TEXT,
  p_quantity NUMERIC,
  p_unit TEXT,
  p_supplier_id UUID,
  p_supplier_name TEXT,
  p_cost_per_unit NUMERIC,
  p_upload_batch_id UUID,
  p_uploaded_by_uid TEXT,
  p_uploaded_by_name TEXT,
  p_uploaded_by_role TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS TABLE(
  success BOOLEAN,
  message TEXT,
  item_id UUID,
  stock_before NUMERIC,
  stock_after NUMERIC
) AS $$
DECLARE
  v_stock_before NUMERIC;
  v_stock_after NUMERIC;
  v_item_name TEXT;
  v_unit TEXT;
  v_category TEXT;
  v_cost NUMERIC;
BEGIN
  -- ✓ Fetch current item state
  SELECT current_stock, name, unit::TEXT, category, cost_per_unit
  INTO v_stock_before, v_item_name, v_unit, v_category, v_cost
  FROM inventory_items
  WHERE id = p_item_id AND business_id = p_business_id
  FOR UPDATE;

  -- ✗ Check if item exists
  IF v_stock_before IS NULL THEN
    RETURN QUERY SELECT 
      false, 
      'Item not found: ' || p_item_id::TEXT, 
      p_item_id,
      NULL,
      NULL;
    RETURN;
  END IF;

  -- ✓ Update stock by appending quantity
  v_stock_after := v_stock_before + p_quantity;

  UPDATE inventory_items
  SET 
    current_stock = v_stock_after,
    last_updated = NOW()
  WHERE id = p_item_id AND business_id = p_business_id;

  -- ✓ Record history
  INSERT INTO inventory_bulk_upload_history (
    business_id,
    upload_batch_id,
    item_id,
    item_name,
    action,
    quantity_added,
    stock_before,
    stock_after,
    supplier_id,
    supplier_name,
    cost_per_unit,
    unit,
    category,
    uploaded_by_uid,
    uploaded_by_name,
    uploaded_by_role,
    notes
  ) VALUES (
    p_business_id,
    p_upload_batch_id,
    p_item_id,
    v_item_name,
    'stock_appended',
    p_quantity,
    v_stock_before,
    v_stock_after,
    p_supplier_id,
    p_supplier_name,
    p_cost_per_unit,
    p_unit,
    v_category,
    p_uploaded_by_uid,
    p_uploaded_by_name,
    p_uploaded_by_role,
    p_notes
  );

  -- ✓ Record transaction in stock_transactions
  INSERT INTO stock_transactions (
    item_id,
    business_id,
    transaction_type,
    quantity,
    stock_before,
    stock_after,
    unit,
    note,
    updated_by_uid,
    updated_by_name,
    updated_by_role,
    supplier_id
  ) VALUES (
    p_item_id,
    p_business_id,
    'stock_in',
    p_quantity,
    v_stock_before,
    v_stock_after,
    v_unit,
    'Bulk upload stock append: ' || (p_notes || ''),
    p_uploaded_by_uid,
    p_uploaded_by_name,
    p_uploaded_by_role,
    p_supplier_id
  );

  -- ✓ Return success
  RETURN QUERY SELECT 
    true,
    'Stock appended successfully for ' || v_item_name,
    p_item_id,
    v_stock_before,
    v_stock_after;
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────────────────────────
-- FUNCTION: fn_record_bulk_upload_new_item
-- ─────────────────────────────────────────────────────────────────────────────
-- Records a new item creation from bulk upload

CREATE OR REPLACE FUNCTION public.fn_record_bulk_upload_new_item(
  p_item_id UUID,
  p_business_id TEXT,
  p_item_name TEXT,
  p_initial_stock NUMERIC,
  p_unit TEXT,
  p_category TEXT,
  p_supplier_id UUID,
  p_supplier_name TEXT,
  p_cost_per_unit NUMERIC,
  p_upload_batch_id UUID,
  p_uploaded_by_uid TEXT,
  p_uploaded_by_name TEXT,
  p_uploaded_by_role TEXT
)
RETURNS TABLE(
  success BOOLEAN,
  message TEXT,
  history_id UUID
) AS $$
DECLARE
  v_history_id UUID;
BEGIN
  v_history_id := uuid_generate_v4();

  INSERT INTO inventory_bulk_upload_history (
    id,
    business_id,
    upload_batch_id,
    item_id,
    item_name,
    action,
    stock_before,
    stock_after,
    quantity_added,
    supplier_id,
    supplier_name,
    cost_per_unit,
    unit,
    category,
    uploaded_by_uid,
    uploaded_by_name,
    uploaded_by_role
  ) VALUES (
    v_history_id,
    p_business_id,
    p_upload_batch_id,
    p_item_id,
    p_item_name,
    'new_item',
    0,
    p_initial_stock,
    p_initial_stock,
    p_supplier_id,
    p_supplier_name,
    p_cost_per_unit,
    p_unit,
    p_category,
    p_uploaded_by_uid,
    p_uploaded_by_name,
    p_uploaded_by_role
  );

  RETURN QUERY SELECT 
    true,
    'New item recorded: ' || p_item_name,
    v_history_id;
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW: v_inventory_upload_summary
-- ─────────────────────────────────────────────────────────────────────────────
-- Provides summary statistics for upload batches

CREATE OR REPLACE VIEW public.v_inventory_upload_summary AS
SELECT 
  upload_batch_id,
  business_id,
  upload_date,
  uploaded_by_name,
  COUNT(*) as total_items,
  COALESCE(SUM(CASE WHEN action = 'new_item' THEN 1 ELSE 0 END), 0) as new_items_count,
  COALESCE(SUM(CASE WHEN action = 'stock_appended' THEN 1 ELSE 0 END), 0) as appended_items_count,
  COALESCE(SUM(CASE WHEN action = 'duplicate_detected' THEN 1 ELSE 0 END), 0) as duplicate_items_count,
  COALESCE(SUM(CASE WHEN action = 'skipped' THEN 1 ELSE 0 END), 0) as skipped_items_count,
  COALESCE(SUM(quantity_added), 0) as total_quantity_added
FROM inventory_bulk_upload_history
GROUP BY upload_batch_id, business_id, upload_date, uploaded_by_name
ORDER BY upload_date DESC;

-- ─────────────────────────────────────────────────────────────────────────────
-- RLS POLICIES (Optional - Firebase Authentication)
-- ─────────────────────────────────────────────────────────────────────────────
-- NOTE: RLS policies are not needed if using Firebase auth + app-level access control
-- If you want to enable RLS later, configure it based on your Firebase user/business mapping
-- 
-- Example with Firebase custom claims (if storing business_id in Firebase claims):
-- 
-- ALTER TABLE inventory_bulk_upload_history ENABLE ROW LEVEL SECURITY;
-- 
-- CREATE POLICY "users_can_view_own_business_uploads"
--   ON inventory_bulk_upload_history
--   FOR SELECT
--   USING (business_id = current_setting('app.current_business_id', true));
-- 
-- CREATE POLICY "users_can_insert_own_business_uploads"
--   ON inventory_bulk_upload_history
--   FOR INSERT
--   WITH CHECK (business_id = current_setting('app.current_business_id', true));
--
-- Then set the business_id before queries:
-- SET app.current_business_id = 'your-business-id';
-- ─────────────────────────────────────────────────────────────────────────────
