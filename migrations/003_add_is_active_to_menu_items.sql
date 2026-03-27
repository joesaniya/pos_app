-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION: Add is_active column to menu_items for soft deletes
-- 
-- RUN IN: Supabase Dashboard → SQL Editor → Run
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE menu_items 
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_menu_items_is_active 
  ON menu_items(is_active);

CREATE INDEX IF NOT EXISTS idx_menu_items_business_is_active 
  ON menu_items(business_id, is_active);

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'menu_items' AND column_name = 'is_active'
ORDER BY ordinal_position;

NOTIFY pgrst, 'reload schema';
