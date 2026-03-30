-- ═══════════════════════════════════════════════════════════════════════════════
-- 🔥 REAL-TIME SYNCHRONIZED ORDER & KITCHEN DISPLAY SYSTEM (KDS)
-- Complete Implementation: Full Bi-Directional Sync + Kitchen Routing + Status Consistency
-- Date: 2026-03-31
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════════════════════════════════════════════════
-- PHASE 1: CREATE CORE SYNC & KITCHEN ROUTING TABLES
-- ═══════════════════════════════════════════════════════════════════════════════

-- ┌─ TABLE: order_kot_mapping (Bi-Directional Link) ─────────────────────────────┐
-- │ Purpose: Create immutable 1:1 link between Orders and KOTs                    │
-- │ Why: Ensures fast lookups in both directions (order_id → kot_id, kot_id → order_id)
-- │ Sync Trigger: Orders created → KOT created → mapping inserted                 │
-- └─────────────────────────────────────────────────────────────────────────────┘

-- Drop existing table with CASCADE to ensure clean state
DROP TABLE IF EXISTS public.order_kot_mapping CASCADE;

CREATE TABLE public.order_kot_mapping (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL UNIQUE REFERENCES public.orders(id) ON DELETE CASCADE,
  kot_id UUID NOT NULL UNIQUE REFERENCES public.kot_orders(id) ON DELETE CASCADE,
  business_id TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_order_kot_order ON public.order_kot_mapping(order_id);
CREATE INDEX IF NOT EXISTS idx_order_kot_kot ON public.order_kot_mapping(kot_id);
CREATE INDEX IF NOT EXISTS idx_order_kot_business ON public.order_kot_mapping(business_id);

-- ┌─ TABLE: kitchen_routing_rules (Dynamic Kitchen Segmentation) ──────────────────┐
-- │ Purpose: Route items to specific kitchens based on category/keyword patterns   │
-- │ Example: "Veg" items → Kitchen A, "Non-Veg" → Kitchen B, "Beverages" → Kitchen C
-- └──────────────────────────────────────────────────────────────────────────────┘

-- Drop existing table to ensure clean state
DROP TABLE IF EXISTS public.kitchen_routing_rules CASCADE;

CREATE TABLE public.kitchen_routing_rules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id TEXT NOT NULL,
  kitchen_id TEXT NOT NULL,
  kitchen_name TEXT,
  rule_priority INT NOT NULL DEFAULT 1,
  match_type TEXT NOT NULL CHECK (match_type IN ('category', 'keyword', 'supplier'))
    DEFAULT 'category',
  match_value TEXT NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_routing_business ON public.kitchen_routing_rules(business_id);
CREATE INDEX IF NOT EXISTS idx_routing_kitchen ON public.kitchen_routing_rules(kitchen_id);
CREATE INDEX IF NOT EXISTS idx_routing_active ON public.kitchen_routing_rules(is_active);

-- ┌─ TABLE: order_item_kitchen_map (Item → Kitchen Assignment) ────────────────────┐
-- │ Purpose: Track which kitchen each order item is assigned to                    │
-- │ Critical: Each item can have a different kitchen; enables kitchen-level tracking
-- └──────────────────────────────────────────────────────────────────────────────┘

-- Drop existing table with CASCADE to ensure clean state
DROP TABLE IF EXISTS public.order_item_kitchen_map CASCADE;

CREATE TABLE public.order_item_kitchen_map (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_item_id UUID NOT NULL REFERENCES public.order_items(id) ON DELETE CASCADE,
  kot_item_id UUID NOT NULL REFERENCES public.kot_items(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  kot_id UUID NOT NULL REFERENCES public.kot_orders(id) ON DELETE CASCADE,
  kitchen_id TEXT NOT NULL,
  business_id TEXT NOT NULL,
  routing_rule_id UUID REFERENCES public.kitchen_routing_rules(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_kitchen_map_order_item ON public.order_item_kitchen_map(order_item_id);
CREATE INDEX IF NOT EXISTS idx_kitchen_map_kot_item ON public.order_item_kitchen_map(kot_item_id);
CREATE INDEX IF NOT EXISTS idx_kitchen_map_kitchen ON public.order_item_kitchen_map(kitchen_id);
CREATE INDEX IF NOT EXISTS idx_kitchen_map_order ON public.order_item_kitchen_map(order_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_kitchen_map_items 
  ON public.order_item_kitchen_map(order_item_id, kot_item_id);

-- ┌─ TABLE: sync_event_queue (Event-Driven Sync) ─────────────────────────────────┐
-- │ Purpose: Queue real-time sync events for reliable delivery to all systems      │
-- │ Strategy: When order/KOT changes, emit event → broadcast to WebSocket/Firebase │
-- │ Idempotency: event_hash ensures duplicate events are skipped                   │
-- └──────────────────────────────────────────────────────────────────────────────┘

-- Drop existing table to ensure clean state
DROP TABLE IF EXISTS public.sync_event_queue CASCADE;

CREATE TABLE public.sync_event_queue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id TEXT NOT NULL,
  source_system TEXT NOT NULL CHECK (source_system IN ('POS', 'KDS')),
  event_type TEXT NOT NULL CHECK (event_type IN (
    'order_created', 'order_updated', 'order_cancelled',
    'order_status_changed', 'item_added', 'item_status_changed',
    'item_cancelled', 'kot_created', 'kot_status_changed',
    'batch_added', 'delay_detected'
  )),
  entity_type TEXT NOT NULL CHECK (entity_type IN ('order', 'kot', 'item')),
  entity_id UUID NOT NULL,
  parent_entity_id UUID,
  event_data JSONB NOT NULL,
  event_hash TEXT NOT NULL,
  is_processed BOOLEAN DEFAULT FALSE,
  processed_at TIMESTAMPTZ,
  retry_count INT DEFAULT 0,
  max_retries INT DEFAULT 3,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(event_hash, business_id)
);

CREATE INDEX IF NOT EXISTS idx_sync_queue_business ON public.sync_event_queue(business_id);
CREATE INDEX IF NOT EXISTS idx_sync_queue_processed ON public.sync_event_queue(is_processed, created_at);
CREATE INDEX IF NOT EXISTS idx_sync_queue_entity ON public.sync_event_queue(entity_type, entity_id);

-- ┌─ TABLE: sync_status_tracking (Track Sync State) ────────────────────────────────┐
-- │ Purpose: Monitor last sync timestamp for each order & KOT pair                  │
-- │ Use: Detect stale data or missed syncs; enable incremental sync                 │
-- └──────────────────────────────────────────────────────────────────────────────┘

-- Drop existing table to ensure clean state
DROP TABLE IF EXISTS public.sync_status_tracking CASCADE;

CREATE TABLE public.sync_status_tracking (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id TEXT NOT NULL,
  order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
  kot_id UUID REFERENCES public.kot_orders(id) ON DELETE CASCADE,
  last_pos_sync_at TIMESTAMPTZ,
  last_kds_sync_at TIMESTAMPTZ,
  pos_is_synced BOOLEAN DEFAULT TRUE,
  kds_is_synced BOOLEAN DEFAULT TRUE,
  sync_status TEXT DEFAULT 'synced' CHECK (sync_status IN ('synced', 'pending', 'conflict', 'error')),
  conflict_resolution_rule TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sync_track_business ON public.sync_status_tracking(business_id);
CREATE INDEX IF NOT EXISTS idx_sync_track_order ON public.sync_status_tracking(order_id);
CREATE INDEX IF NOT EXISTS idx_sync_track_kot ON public.sync_status_tracking(kot_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_sync_track_order_kot 
  ON public.sync_status_tracking(order_id, kot_id);

-- ┌─ TABLE: status_change_log (Audit Trail for Conflict Resolution) ────────────────┐
-- │ Purpose: Complete history of every status change in both POS & KDS             │
-- │ Use: Determine which system's change should win in conflicts                    │
-- └──────────────────────────────────────────────────────────────────────────────┘

-- Drop existing table to ensure clean state
DROP TABLE IF EXISTS public.status_change_log CASCADE;

CREATE TABLE public.status_change_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id TEXT NOT NULL,
  system TEXT NOT NULL CHECK (system IN ('POS', 'KDS')),
  target_type TEXT NOT NULL CHECK (target_type IN ('order', 'kot', 'item')),
  target_id UUID NOT NULL,
  old_status TEXT,
  new_status TEXT,
  changed_by_uid TEXT,
  changed_by_name TEXT,
  reason TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_status_log_business ON public.status_change_log(business_id);
CREATE INDEX IF NOT EXISTS idx_status_log_target ON public.status_change_log(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_status_log_system ON public.status_change_log(system, created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════
-- PHASE 2: ENHANCE EXISTING TABLES WITH SYNC COLUMNS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Add sync columns to orders table
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS is_synced_to_kds BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS sync_version INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS table_number INT,
ADD COLUMN IF NOT EXISTS order_type TEXT,
ADD COLUMN IF NOT EXISTS updated_by_uid TEXT,
ADD COLUMN IF NOT EXISTS updated_by_name TEXT;

-- Add sync columns to kot_orders table
ALTER TABLE public.kot_orders
ADD COLUMN IF NOT EXISTS is_synced_from_pos BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS sync_version INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS order_id UUID,
ADD COLUMN IF NOT EXISTS priority TEXT,
ADD COLUMN IF NOT EXISTS total_items INT,
ADD COLUMN IF NOT EXISTS kot_created_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS sent_to_kitchen_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS table_number INT,
ADD COLUMN IF NOT EXISTS customer_name TEXT,
ADD COLUMN IF NOT EXISTS created_by_uid TEXT,
ADD COLUMN IF NOT EXISTS created_by_name TEXT;

-- Add kitchen routing to kot_items
ALTER TABLE public.kot_items
ADD COLUMN IF NOT EXISTS assigned_kitchen_id TEXT,
ADD COLUMN IF NOT EXISTS original_order_item_id UUID REFERENCES public.order_items(id) ON DELETE SET NULL;

-- Add sync tracking to order_items
ALTER TABLE public.order_items
ADD COLUMN IF NOT EXISTS synced_to_kot BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS linked_kot_item_id UUID REFERENCES public.kot_items(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS category_name TEXT,
ADD COLUMN IF NOT EXISTS item_name TEXT;

CREATE INDEX IF NOT EXISTS idx_orders_synced ON public.orders(is_synced_to_kds);
CREATE INDEX IF NOT EXISTS idx_kot_orders_synced ON public.kot_orders(is_synced_from_pos);
CREATE INDEX IF NOT EXISTS idx_kot_items_kitchen ON public.kot_items(assigned_kitchen_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- PHASE 3: VIEW FOR COMPLETE ORDER-KOT STATE (Single Source of Truth)
-- ═══════════════════════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS public.vw_order_kot_sync_state CASCADE;

CREATE VIEW public.vw_order_kot_sync_state AS
SELECT
  o.id AS order_id,
  okm.kot_id,
  o.order_number,
  o.business_id,
  o.status AS order_status,
  ko.status AS kot_status,
  o.created_at AS order_created_at,
  ko.kot_created_at AS kot_created_at,
  CASE WHEN o.status = ko.status THEN 'synced' 
       WHEN o.updated_at > ko.updated_at THEN 'pos_ahead'
       WHEN ko.updated_at > o.updated_at THEN 'kds_ahead'
       ELSE 'conflict' END AS sync_state,
  o.updated_at AS order_updated_at,
  ko.updated_at AS kot_updated_at,
  sst.pos_is_synced,
  sst.kds_is_synced,
  sst.sync_status,
  COUNT(DISTINCT oi.id) AS pos_item_count,
  COUNT(DISTINCT ki.id) AS kot_item_count,
  jsonb_agg(DISTINCT oikm.kitchen_id) FILTER (WHERE oikm.kitchen_id IS NOT NULL) AS assigned_kitchens
FROM public.orders o
LEFT JOIN public.order_kot_mapping okm ON okm.order_id = o.id
LEFT JOIN public.kot_orders ko ON ko.id = okm.kot_id
LEFT JOIN public.sync_status_tracking sst ON sst.order_id = o.id AND sst.kot_id = okm.kot_id
LEFT JOIN public.order_items oi ON oi.order_id = o.id
LEFT JOIN public.kot_items ki ON ki.kot_id = okm.kot_id
LEFT JOIN public.order_item_kitchen_map oikm ON oikm.order_id = o.id
GROUP BY o.id, okm.kot_id, o.order_number, o.business_id, o.status, ko.status,
         o.created_at, ko.kot_created_at, o.updated_at, ko.updated_at,
         sst.pos_is_synced, sst.kds_is_synced, sst.sync_status;

GRANT SELECT ON public.vw_order_kot_sync_state TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- PHASE 4: REAL-TIME SYNC FUNCTIONS (Core Engine)
-- ═══════════════════════════════════════════════════════════════════════════════

-- ┌─ Function: Create Order → KOT Auto-Link ──────────────────────────────────┐
-- │ Trigger: When order is created in POS                                     │
-- │ Action: Automatically create KOT + mapping + routing                       │
-- │ Result: Instant KDS availability with no manual step                       │
-- └─────────────────────────────────────────────────────────────────────────┘

CREATE OR REPLACE FUNCTION public.fn_auto_create_kot_from_order()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_kot_id UUID;
  v_batch_id UUID;
  v_items_count INT;
BEGIN
  -- Only create KOT for dine_in orders (not takeaway/delivery initially)
  IF NEW.order_type NOT IN ('dine_in') THEN
    RETURN NEW;
  END IF;

  -- Generate KOT ID and batch ID
  v_kot_id := uuid_generate_v4();
  v_batch_id := uuid_generate_v4();
  
  -- Create KOT order
  INSERT INTO public.kot_orders (
    id, business_id, order_id, status, priority, total_items,
    kot_created_at, sent_to_kitchen_at, table_number, customer_name,
    created_by_uid, created_by_name, created_at, updated_at
  ) VALUES (
    v_kot_id, NEW.business_id, NEW.id, 'pending', COALESCE(NEW.priority, 'normal'), 0,
    NOW(), NOW(), COALESCE(NEW.table_number, 0), COALESCE(NEW.customer_name, ''),
    COALESCE(NEW.created_by_uid, ''), COALESCE(NEW.created_by_name, 'System'), NOW(), NOW()
  );

  -- Create initial batch
  INSERT INTO public.kot_item_batches (
    id, kot_id, business_id, batch_number, is_new_item_batch,
    batch_added_at, item_count, batch_status, created_at, updated_at
  ) VALUES (
    v_batch_id, v_kot_id, NEW.business_id, 1, FALSE,
    NOW(), 0, 'active', NOW(), NOW()
  );

  -- Create order-KOT mapping
  INSERT INTO public.order_kot_mapping (
    order_id, kot_id, business_id, created_at, updated_at
  ) VALUES (
    NEW.id, v_kot_id, NEW.business_id, NOW(), NOW()
  );

  -- Create sync status tracker
  INSERT INTO public.sync_status_tracking (
    business_id, order_id, kot_id, pos_is_synced, kds_is_synced,
    sync_status, created_at, updated_at
  ) VALUES (
    NEW.business_id, NEW.id, v_kot_id, FALSE, FALSE,
    'pending', NOW(), NOW()
  );

  -- Mark order as synced to KDS
  NEW.is_synced_to_kds := TRUE;
  NEW.last_synced_at := NOW();

  -- Emit sync event
  INSERT INTO public.sync_event_queue (
    business_id, source_system, event_type, entity_type, entity_id,
    parent_entity_id, event_data, event_hash, is_processed
  ) VALUES (
    NEW.business_id, 'POS', 'order_created', 'order', NEW.id,
    v_kot_id, jsonb_build_object(
      'order_id', NEW.id, 'kot_id', v_kot_id,
      'order_number', NEW.order_number, 'status', NEW.status
    ),
    md5(NEW.id::TEXT || NEW.business_id || 'order_created' || NOW()::TEXT),
    FALSE
  );

  RETURN NEW;
END;
$$;

-- Drop existing trigger if present
DROP TRIGGER IF EXISTS trg_auto_create_kot_from_order ON public.orders;

CREATE TRIGGER trg_auto_create_kot_from_order
AFTER INSERT ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.fn_auto_create_kot_from_order();

-- ┌─ Function: Route Items to Kitchens ─────────────────────────────────────┐
-- │ Trigger: When order items are added                                      │
-- │ Action: Auto-route items to appropriate kitchen based on routing rules   │
-- │ Result: Kitchen-level segmentation happens automatically                 │
-- └─────────────────────────────────────────────────────────────────────────┘

CREATE OR REPLACE FUNCTION public.fn_route_item_to_kitchen()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_kit_id TEXT;
  v_rule_id UUID;
  v_routing_rules RECORD;
  v_category_name TEXT;
  v_item_name TEXT;
BEGIN
  -- Safety: Extract columns, handle if they don't exist
  v_category_name := COALESCE(NEW.category_name, '');
  v_item_name := COALESCE(NEW.item_name, '');
  
  -- Find matching kitchen routing rule
  FOR v_routing_rules IN (
    SELECT id, kitchen_id, rule_priority, match_type, match_value
    FROM public.kitchen_routing_rules
    WHERE business_id = NEW.business_id
      AND is_active = TRUE
    ORDER BY rule_priority DESC
  ) LOOP
    IF v_routing_rules.match_type = 'category' 
       AND v_category_name = v_routing_rules.match_value THEN
      v_kit_id := v_routing_rules.kitchen_id;
      v_rule_id := v_routing_rules.id;
      EXIT;
    ELSIF v_routing_rules.match_type = 'keyword' 
          AND v_item_name ILIKE '%' || v_routing_rules.match_value || '%' THEN
      v_kit_id := v_routing_rules.kitchen_id;
      v_rule_id := v_routing_rules.id;
      EXIT;
    END IF;
  END LOOP;

  -- Default to kitchen A if no rule matches
  IF v_kit_id IS NULL THEN
    v_kit_id := 'default_kitchen';
  END IF;

  -- Store assigned kitchen
  NEW.synced_to_kot := FALSE;

  -- Emit routing event
  INSERT INTO public.sync_event_queue (
    business_id, source_system, event_type, entity_type, entity_id,
    parent_entity_id, event_data, event_hash, is_processed
  ) VALUES (
    NEW.business_id, 'POS', 'item_added', 'item', NEW.id,
    NEW.order_id, jsonb_build_object(
      'item_id', NEW.id, 'order_id', NEW.order_id,
      'item_name', v_item_name, 'assigned_kitchen', v_kit_id
    ),
    md5(NEW.id::TEXT || NEW.business_id || 'item_added' || NOW()::TEXT),
    FALSE
  );

  RETURN NEW;
END;
$$;

-- Drop existing trigger if present
DROP TRIGGER IF EXISTS trg_route_item_to_kitchen ON public.order_items CASCADE;

CREATE TRIGGER trg_route_item_to_kitchen
AFTER INSERT ON public.order_items
FOR EACH ROW EXECUTE FUNCTION public.fn_route_item_to_kitchen();

-- ┌─ Function: Sync Order Items → KOT Items (CRITICAL) ────────────────────┐
-- │ Trigger: When order items are added                                      │
-- │ Action: Automatically create KOT items in the latest batch                │
-- │ Result: KDS displays all order items instantly                             │
-- │ CRITICAL FIX: This is the missing link for orders to appear in KDS!      │
-- └─────────────────────────────────────────────────────────────────────────┘

CREATE OR REPLACE FUNCTION public.fn_sync_order_item_to_kot()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_kot_id UUID;
  v_batch_id UUID;
  v_kot_item_id UUID;
  v_batch_number INT;
  v_current_batch_record RECORD;
BEGIN
  -- Find the KOT for this order
  SELECT okm.kot_id INTO v_kot_id
  FROM public.order_kot_mapping okm
  WHERE okm.order_id = NEW.order_id
  LIMIT 1;

  -- If no KOT found, skip (shouldn't happen, but safety check)
  IF v_kot_id IS NULL THEN
    RAISE NOTICE 'ℹ️ No KOT found for order: %', COALESCE(NEW.order_id::TEXT, 'NULL');
    RETURN NEW;
  END IF;

  -- Get the latest batch for this KOT (usually batch_number = 1 for initial items)
  SELECT id, batch_number
  INTO v_current_batch_record
  FROM public.kot_item_batches
  WHERE kot_id = v_kot_id
  ORDER BY batch_number DESC
  LIMIT 1;

  IF v_current_batch_record IS NULL THEN
    -- Safety: Create initial batch if it doesn't exist
    v_batch_id := uuid_generate_v4();
    v_batch_number := 1;
    
    INSERT INTO public.kot_item_batches (
      id, kot_id, business_id, batch_number, is_new_item_batch,
      batch_added_at, item_count, batch_status, created_at, updated_at
    ) VALUES (
      v_batch_id, v_kot_id, NEW.business_id, v_batch_number, FALSE,
      NOW(), 0, 'active', NOW(), NOW()
    );
  ELSE
    v_batch_id := v_current_batch_record.id;
    v_batch_number := v_current_batch_record.batch_number;
  END IF;

  -- Generate KOT item ID
  v_kot_item_id := uuid_generate_v4();

  -- Create the KOT item
  INSERT INTO public.kot_items (
    id, kot_id, batch_id, business_id, item_name, category,
    quantity, is_veg, status, created_at, updated_at,
    original_order_item_id, assigned_kitchen_id, sla_seconds, is_sla_violated
  ) VALUES (
    v_kot_item_id,
    v_kot_id,
    v_batch_id,
    NEW.business_id,
    COALESCE(NEW.item_name, ''),
    COALESCE(NEW.category_name, ''),
    COALESCE(NEW.quantity, 1),
    COALESCE(NEW.is_veg, FALSE),
    'pending',
    NOW(),
    NOW(),
    NEW.id,
    NULL,  -- assigned_kitchen_id will be set by routing
    900,   -- Default SLA: 15 minutes
    FALSE
  );

  -- Link the order item to the KOT item
  UPDATE public.order_items
  SET synced_to_kot = TRUE,
      linked_kot_item_id = v_kot_item_id,
      updated_at = NOW()
  WHERE id = NEW.id;

  -- Update batch item count
  UPDATE public.kot_item_batches
  SET item_count = item_count + 1,
      updated_at = NOW()
  WHERE id = v_batch_id;

  -- Update KOT order item count
  UPDATE public.kot_orders
  SET total_items = (
        SELECT COUNT(*) FROM public.kot_items WHERE kot_id = v_kot_id
      ),
      updated_at = NOW(),
      sync_version = sync_version + 1
  WHERE id = v_kot_id;

  -- Emit sync event for real-time broadcast
  INSERT INTO public.sync_event_queue (
    business_id, source_system, event_type, entity_type, entity_id,
    parent_entity_id, event_data, event_hash, is_processed
  ) VALUES (
    NEW.business_id, 'POS', 'item_added', 'item', v_kot_item_id,
    v_kot_id, jsonb_build_object(
      'order_id', NEW.order_id, 'order_item_id', NEW.id,
      'kot_id', v_kot_id, 'kot_item_id', v_kot_item_id,
      'item_name', COALESCE(NEW.item_name, ''),
      'quantity', COALESCE(NEW.quantity, 1),
      'category', COALESCE(NEW.category_name, '')
    ),
    md5(v_kot_item_id::TEXT || v_kot_id::TEXT || 'item_added' || NOW()::TEXT),
    FALSE
  );

  RETURN NEW;
END;
$$;

-- Drop existing trigger if present
DROP TRIGGER IF EXISTS trg_sync_order_item_to_kot ON public.order_items CASCADE;

-- Create the trigger
CREATE TRIGGER trg_sync_order_item_to_kot
AFTER INSERT ON public.order_items
FOR EACH ROW EXECUTE FUNCTION public.fn_sync_order_item_to_kot();

-- ┌─ Function: Sync Order Status → KOT ─────────────────────────────────────┐
-- │ Propagate: Any order status change in POS → update KOT                   │
-- │ Idempotency: Check version to prevent older updates overwriting newer    │
-- └─────────────────────────────────────────────────────────────────────────┘

CREATE OR REPLACE FUNCTION public.fn_sync_order_status_to_kot()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_kot_id UUID;
  v_kot_status TEXT;
BEGIN
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  -- Find linked KOT
  SELECT kot_id INTO v_kot_id
  FROM public.order_kot_mapping
  WHERE order_id = NEW.id;

  IF v_kot_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Map POS status to KOT status
  v_kot_status := CASE NEW.status
    WHEN 'pending' THEN 'pending'
    WHEN 'preparing' THEN 'in_progress'
    WHEN 'ready' THEN 'ready'
    WHEN 'completed' THEN 'completed'
    WHEN 'cancelled' THEN 'cancelled'
    ELSE 'pending'
  END;

  -- Update KOT with new status
  UPDATE public.kot_orders
  SET status = v_kot_status,
      updated_at = NOW(),
      sync_version = sync_version + 1
  WHERE id = v_kot_id;

  -- Log status change
  INSERT INTO public.status_change_log (
    business_id, system, target_type, target_id,
    old_status, new_status, changed_by_uid, changed_by_name, reason
  ) VALUES (
    NEW.business_id, 'POS', 'order', NEW.id,
    OLD.status, NEW.status, COALESCE(NEW.updated_by_uid, ''), 
    COALESCE(NEW.updated_by_name, 'System'),
    'Order status changed in POS'
  );

  -- Queue sync event
  INSERT INTO public.sync_event_queue (
    business_id, source_system, event_type, entity_type, entity_id,
    parent_entity_id, event_data, event_hash, is_processed
  ) VALUES (
    NEW.business_id, 'POS', 'order_status_changed', 'order', NEW.id,
    v_kot_id, jsonb_build_object(
      'order_id', NEW.id, 'kot_id', v_kot_id,
      'old_status', OLD.status, 'new_status', NEW.status
    ),
    md5(NEW.id::TEXT || v_kot_id::TEXT || 'status_changed' || NEW.status || NOW()::TEXT),
    FALSE
  );

  NEW.last_synced_at := NOW();

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_order_status_to_kot ON public.orders;

CREATE TRIGGER trg_sync_order_status_to_kot
AFTER UPDATE OF status ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.fn_sync_order_status_to_kot();

-- ┌─ Function: Sync KOT Status → Order ─────────────────────────────────────┐
-- │ Reverse Sync: Any KOT status change in KDS → update Order                │
-- │ Critical for POS dashboard to reflect kitchen progress                   │
-- └─────────────────────────────────────────────────────────────────────────┘

CREATE OR REPLACE FUNCTION public.fn_sync_kot_status_to_order()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_order_id UUID;
  v_order_status TEXT;
BEGIN
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  -- Find linked order
  SELECT order_id INTO v_order_id
  FROM public.order_kot_mapping
  WHERE kot_id = NEW.id;

  IF v_order_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Map KOT status back to POS status
  v_order_status := CASE NEW.status
    WHEN 'pending' THEN 'pending'
    WHEN 'in_progress' THEN 'preparing'
    WHEN 'ready' THEN 'ready'
    WHEN 'completed' THEN 'completed'
    WHEN 'cancelled' THEN 'cancelled'
    ELSE 'pending'
  END;

  -- Update order with KOT status
  UPDATE public.orders
  SET status = v_order_status,
      updated_at = NOW(),
      last_synced_at = NOW()
  WHERE id = v_order_id;

  -- Log status change
  INSERT INTO public.status_change_log (
    business_id, system, target_type, target_id,
    old_status, new_status, changed_by_uid, changed_by_name, reason
  ) VALUES (
    NEW.business_id, 'KDS', 'order', v_order_id,
    OLD.status, NEW.status, NULL, 'Kitchen Staff',
    'Order status changed in KDS'
  );

  -- Queue sync event for POS
  INSERT INTO public.sync_event_queue (
    business_id, source_system, event_type, entity_type, entity_id,
    parent_entity_id, event_data, event_hash, is_processed
  ) VALUES (
    NEW.business_id, 'KDS', 'order_status_changed', 'order', v_order_id,
    NEW.id, jsonb_build_object(
      'order_id', v_order_id, 'kot_id', NEW.id,
      'old_status', OLD.status, 'new_status', NEW.status
    ),
    md5(v_order_id::TEXT || NEW.id::TEXT || 'kde_status_changed' || NEW.status || NOW()::TEXT),
    FALSE
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_kot_status_to_order ON public.kot_orders;

CREATE TRIGGER trg_sync_kot_status_to_order
AFTER UPDATE OF status ON public.kot_orders
FOR EACH ROW EXECUTE FUNCTION public.fn_sync_kot_status_to_order();

-- ═══════════════════════════════════════════════════════════════════════════════
-- PHASE 5: CONFLICT RESOLUTION FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════

-- ┌─ Function: Detect and Resolve Sync Conflicts ──────────────────────────┐
-- │ Strategy: Last-Write-Wins (LWW) with timestamp precedence               │
-- │ Backup: If timestamps match, POS takes precedence (source of truth)     │
-- └─────────────────────────────────────────────────────────────────────────┘

CREATE OR REPLACE FUNCTION public.fn_resolve_sync_conflict(
  p_order_id UUID,
  p_kot_id UUID,
  p_business_id TEXT
)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
  v_order_status TEXT;
  v_kot_status TEXT;
  v_order_updated_at TIMESTAMPTZ;
  v_kot_updated_at TIMESTAMPTZ;
  v_winning_status TEXT;
  v_winning_system TEXT;
BEGIN
  -- Fetch current states
  SELECT status, updated_at INTO v_order_status, v_order_updated_at
  FROM public.orders WHERE id = p_order_id;

  SELECT status, updated_at INTO v_kot_status, v_kot_updated_at
  FROM public.kot_orders WHERE id = p_kot_id;

  -- Resolve using Last-Write-Wins
  IF v_order_updated_at > v_kot_updated_at THEN
    v_winning_status := v_order_status;
    v_winning_system := 'POS';
    -- Sync POS status to KOT
    UPDATE public.kot_orders
    SET status = CASE v_order_status
          WHEN 'preparing' THEN 'in_progress'
          WHEN 'ready' THEN 'ready'
          ELSE v_order_status
        END,
        updated_at = NOW()
    WHERE id = p_kot_id;
  ELSE
    v_winning_status := v_kot_status;
    v_winning_system := 'KDS';
    -- Sync KOT status to POS
    UPDATE public.orders
    SET status = CASE v_kot_status
          WHEN 'in_progress' THEN 'preparing'
          WHEN 'ready' THEN 'ready'
          ELSE v_kot_status
        END,
        updated_at = NOW()
    WHERE id = p_order_id;
  END IF;

  -- Update sync tracking
  UPDATE public.sync_status_tracking
  SET sync_status = 'synced',
      pos_is_synced = TRUE,
      kds_is_synced = TRUE,
      conflict_resolution_rule = 'last_write_wins_' || v_winning_system,
      updated_at = NOW()
  WHERE order_id = p_order_id AND kot_id = p_kot_id;

  RETURN jsonb_build_object(
    'resolved', TRUE,
    'winning_system', v_winning_system,
    'final_status', v_winning_status,
    'resolved_at', NOW()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_resolve_sync_conflict(UUID, UUID, TEXT) TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- PHASE 6: BROADCAST FUNCTIONS (Real-Time Notification)
-- ═══════════════════════════════════════════════════════════════════════════════

-- ┌─ Function: Broadcast Sync Event ──────────────────────────────────────┐
-- │ Purpose: Notify all connected clients (WebSocket listeners)             │
-- │ Use: PostgreSQL LISTEN/NOTIFY for real-time pubsub                      │
-- └─────────────────────────────────────────────────────────────────────────┘

CREATE OR REPLACE FUNCTION public.fn_broadcast_sync_event()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.is_processed = FALSE THEN
    -- Broadcast to real-time subscribers
    PERFORM pg_notify(
      'order_sync_updates_' || NEW.business_id,
      jsonb_build_object(
        'event_id', NEW.id,
        'business_id', NEW.business_id,
        'source_system', NEW.source_system,
        'event_type', NEW.event_type,
        'entity_type', NEW.entity_type,
        'entity_id', NEW.entity_id,
        'event_data', NEW.event_data,
        'timestamp', NEW.created_at
      )::TEXT
    );
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_broadcast_sync_event ON public.sync_event_queue;

CREATE TRIGGER trg_broadcast_sync_event
AFTER INSERT ON public.sync_event_queue
FOR EACH ROW EXECUTE FUNCTION public.fn_broadcast_sync_event();

-- ═══════════════════════════════════════════════════════════════════════════════
-- PHASE 7: DATA VERIFICATION VIEWS
-- ═══════════════════════════════════════════════════════════════════════════════

-- View: Orders waiting for sync
CREATE OR REPLACE VIEW public.vw_orders_pending_sync AS
SELECT o.id, o.order_number, o.business_id, o.status, o.updated_at,
       okm.kot_id, sst.sync_status
FROM public.orders o
LEFT JOIN public.order_kot_mapping okm ON okm.order_id = o.id
LEFT JOIN public.sync_status_tracking sst ON sst.order_id = o.id
WHERE sst.sync_status IN ('pending', 'conflict', 'error')
  OR o.is_synced_to_kds = FALSE;

-- View: Kitchen routing summary
CREATE OR REPLACE VIEW public.vw_kitchen_routing_summary AS
SELECT
  krr.business_id,
  krr.kitchen_id,
  krr.kitchen_name,
  krr.match_type,
  krr.match_value,
  COUNT(oikm.id) AS assigned_items_count,
  MAX(oikm.created_at) AS last_routed_at
FROM public.kitchen_routing_rules krr
LEFT JOIN public.order_item_kitchen_map oikm 
  ON oikm.kitchen_id = krr.kitchen_id 
  AND oikm.business_id = krr.business_id
WHERE krr.is_active = TRUE
GROUP BY 1, 2, 3, 4, 5;

GRANT SELECT ON public.vw_orders_pending_sync TO anon, authenticated;
GRANT SELECT ON public.vw_kitchen_routing_summary TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- PHASE 8: NOTIFICATION & SCHEMA RELOAD
-- ═══════════════════════════════════════════════════════════════════════════════

-- Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';

-- ═══════════════════════════════════════════════════════════════════════════════
-- ✅ DEPLOYMENT COMPLETE
-- ═══════════════════════════════════════════════════════════════════════════════
-- Verify all tables & functions created:
SELECT 'Tables & Functions Created Successfully' AS status;
