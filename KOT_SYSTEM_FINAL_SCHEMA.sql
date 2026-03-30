-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- 🔥 COMPLETE KITCHEN ORDER TOKEN (KOT) SYSTEM - PRODUCTION READY SCHEMA
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- Date: 2026-03-31
-- Purpose: Real-time KOT management with dynamic item addition, multi-kitchen routing, and offline support
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For full-text search

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- 1. KITCHEN CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.kitchen_stations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id TEXT NOT NULL,
  name TEXT NOT NULL, -- 'grill', 'beverages', 'pastry', 'main'
  display_name TEXT NOT NULL,
  display_order INT DEFAULT 0,
  
  -- Routing
  categories TEXT[] DEFAULT ARRAY[]::TEXT[], -- Categories this kitchen handles
  keywords TEXT[] DEFAULT ARRAY[]::TEXT[], -- Keywords for flexible routing
  
  -- Configuration
  avg_prep_time_seconds INT DEFAULT 900, -- Average prep time (15 min)
  max_concurrent_orders INT DEFAULT 10,
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  is_online BOOLEAN DEFAULT TRUE,
  last_heartbeat TIMESTAMPTZ,
  
  -- Audit
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(business_id, name)
);

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- 2. KOT ORDER MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.kot_orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id TEXT NOT NULL,
  order_id UUID, -- Reference to main orders table
  
  -- KOT tracking
  kot_number TEXT NOT NULL UNIQUE, -- KOT-2026-00001 format
  kot_sequence BIGSERIAL NOT NULL,
  
  -- Status
  status TEXT NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'in_progress', 'ready', 'served', 'cancelled', 'paused')
  ),
  priority TEXT NOT NULL DEFAULT 'normal' CHECK (
    priority IN ('urgent', 'high', 'normal', 'low')
  ),
  
  -- Order details
  total_items INT NOT NULL DEFAULT 0,
  prepared_items INT NOT NULL DEFAULT 0,
  served_items INT NOT NULL DEFAULT 0,
  cancelled_items INT NOT NULL DEFAULT 0,
  
  -- Kitchen routing
  primary_kitchen_id UUID REFERENCES public.kitchen_stations(id),
  assigned_kitchens UUID[] DEFAULT ARRAY[]::UUID[], -- All kitchens involved
  
  -- Timing
  kot_created_at TIMESTAMPTZ DEFAULT NOW(),
  sent_to_kitchen_at TIMESTAMPTZ,
  started_preparing_at TIMESTAMPTZ,
  first_ready_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  
  -- Calculated prep time
  total_prep_time_seconds INT,
  sla_seconds INT DEFAULT 900, -- Standard 15min SLA
  sla_tier TEXT DEFAULT 'standard' CHECK (sla_tier IN ('standard', 'express', 'urgent')),
  is_delayed BOOLEAN DEFAULT FALSE,
  
  -- Item details (JSONB for flexibility)
  item_summary JSONB DEFAULT '{}', -- {item_id: status, ...}
  batch_count INT DEFAULT 1,
  current_batch_number INT DEFAULT 1,
  
  -- Notes & special instructions
  notes TEXT,
  special_instructions TEXT,
  table_number INT,
  customer_name TEXT,
  
  -- Offline support
  is_synced_to_cloud BOOLEAN DEFAULT FALSE,
  is_offline_created BOOLEAN DEFAULT FALSE,
  synced_at TIMESTAMPTZ,
  last_sync_attempt TIMESTAMPTZ,
  sync_attempt_count INT DEFAULT 0,
  
  -- Audit
  created_by_uid TEXT,
  created_by_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_kot_orders_business ON public.kot_orders(business_id);
CREATE INDEX IF NOT EXISTS idx_kot_orders_status ON public.kot_orders(business_id, status);
CREATE INDEX IF NOT EXISTS idx_kot_orders_number ON public.kot_orders(kot_number);
CREATE INDEX IF NOT EXISTS idx_kot_orders_kitchen ON public.kot_orders(primary_kitchen_id);
CREATE INDEX IF NOT EXISTS idx_kot_orders_created ON public.kot_orders(business_id, kot_created_at DESC);
CREATE INDEX IF NOT EXISTS idx_kot_orders_delayed ON public.kot_orders(business_id, is_delayed) WHERE is_delayed = TRUE;

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- 3. KOT ITEM BATCHES (Support dynamic item addition)
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.kot_item_batches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  kot_id UUID NOT NULL REFERENCES public.kot_orders(id) ON DELETE CASCADE,
  business_id TEXT NOT NULL,
  
  -- Batch tracking
  batch_number INT NOT NULL, -- 1 = original items, 2+ = additional items
  batch_status TEXT NOT NULL DEFAULT 'active' CHECK (
    batch_status IN ('active', 'paused', 'completed', 'cancelled')
  ),
  
  -- Batch type
  is_new_item_batch BOOLEAN DEFAULT FALSE, -- TRUE if added after initial KOT
  batch_added_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Items in batch
  item_count INT DEFAULT 0,
  prepared_count INT DEFAULT 0,
  
  -- Progress
  completion_percentage INT DEFAULT 0,
  expected_completion_at TIMESTAMPTZ,
  
  -- Timing
  batch_started_at TIMESTAMPTZ,
  batch_completed_at TIMESTAMPTZ,
  
  -- Notes
  notes TEXT,
  
  -- Audit
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_batches_kot ON public.kot_item_batches(kot_id);
CREATE INDEX IF NOT EXISTS idx_batches_status ON public.kot_item_batches(business_id, batch_status);

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- 4. KOT ITEMS (Individual item tracking with SLA)
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.kot_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  kot_id UUID NOT NULL REFERENCES public.kot_orders(id) ON DELETE CASCADE,
  batch_id UUID NOT NULL REFERENCES public.kot_item_batches(id) ON DELETE CASCADE,
  business_id TEXT NOT NULL,
  
  -- Item details
  item_id UUID, -- Reference to order_items
  item_name TEXT NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  item_price NUMERIC(10,2),
  
  -- Category for routing
  category TEXT, -- 'grill', 'beverages', 'pastry', etc.
  is_veg BOOLEAN DEFAULT TRUE,
  
  -- Kitchen assignment
  assigned_kitchen_id UUID REFERENCES public.kitchen_stations(id),
  
  -- Status tracking
  status TEXT NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'preparing', 'ready', 'served', 'cancelled')
  ),
  
  -- Timing & SLA
  created_at TIMESTAMPTZ DEFAULT NOW(),
  started_preparing_at TIMESTAMPTZ,
  ready_at TIMESTAMPTZ,
  served_at TIMESTAMPTZ,
  
  prep_time_seconds INT, -- (ready_at - started_preparing_at)
  sla_seconds INT DEFAULT 900,
  is_sla_violated BOOLEAN DEFAULT FALSE,
  delay_seconds INT, -- (current_time - sla_deadline)
  
  -- Special handling
  special_instructions TEXT,
  is_veg_badge BOOLEAN DEFAULT FALSE,
  has_allergens BOOLEAN DEFAULT FALSE,
  allergens TEXT, -- Comma-separated: peanuts, dairy, etc.
  
  -- Offline sync
  is_synced_to_cloud BOOLEAN DEFAULT FALSE,
  synced_at TIMESTAMPTZ,
  
  -- Audit
  updated_by_uid TEXT,
  updated_by_name TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_items_kot ON public.kot_items(kot_id);
CREATE INDEX IF NOT EXISTS idx_items_batch ON public.kot_items(batch_id);
CREATE INDEX IF NOT EXISTS idx_items_kitchen ON public.kot_items(assigned_kitchen_id);
CREATE INDEX IF NOT EXISTS idx_items_status ON public.kot_items(business_id, status);
CREATE INDEX IF NOT EXISTS idx_items_delayed ON public.kot_items(business_id, is_sla_violated) WHERE is_sla_violated = TRUE;
CREATE INDEX IF NOT EXISTS idx_items_category ON public.kot_items(business_id, category);

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- 5. KOT ITEM STATUS HISTORY (Audit trail for each item)
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.kot_item_status_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  item_id UUID NOT NULL REFERENCES public.kot_items(id) ON DELETE CASCADE,
  kot_id UUID NOT NULL,
  business_id TEXT NOT NULL,
  
  from_status TEXT,
  to_status TEXT NOT NULL,
  
  status_changed_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Manual or auto
  changed_by_uid TEXT,
  changed_by_name TEXT,
  change_reason TEXT, -- 'manual', 'auto', 'conflict_resolved'
  
  -- Metadata
  time_in_previous_status_seconds INT,
  CONSTRAINT valid_status CHECK (to_status IN ('pending', 'preparing', 'ready', 'served', 'cancelled'))
);

CREATE INDEX IF NOT EXISTS idx_history_item ON public.kot_item_status_history(item_id);
CREATE INDEX IF NOT EXISTS idx_history_kot ON public.kot_item_status_history(kot_id);
CREATE INDEX IF NOT EXISTS idx_history_time ON public.kot_item_status_history(business_id, status_changed_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- 6. KOT AUDIT LOGS (Complete change logging for compliance)
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.kot_audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  kot_id UUID REFERENCES public.kot_orders(id) ON DELETE CASCADE,
  business_id TEXT NOT NULL,
  
  action TEXT NOT NULL CHECK (action IN (
    'KOT_CREATED',
    'KOT_SENT_TO_KITCHEN',
    'ITEMS_ADDED_TO_KOT',
    'BATCH_CREATED',
    'ITEM_STATUS_UPDATED',
    'ITEM_ROUTED_TO_KITCHEN',
    'BATCH_COMPLETED',
    'KOT_COMPLETED',
    'DELAY_ALERT_CREATED',
    'DELAY_ALERT_ACKNOWLEDGED',
    'KOT_CANCELLED',
    'CONFLICT_DETECTED',
    'CONFLICT_RESOLVED',
    'OFFLINE_SYNC_STARTED',
    'OFFLINE_SYNC_COMPLETED'
  )),
  
  -- Details
  details TEXT,
  changes JSONB, -- {field: {old: value, new: value}, ...}
  
  -- User/Device
  user_id TEXT,
  user_name TEXT,
  device_id TEXT,
  
  -- Action timestamp
  action_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Sync status
  is_synced_to_cloud BOOLEAN DEFAULT FALSE,
  synced_at TIMESTAMPTZ,
  
  CONSTRAINT audit_has_details CHECK (details IS NOT NULL OR changes IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_audit_kot ON public.kot_audit_logs(kot_id);
CREATE INDEX IF NOT EXISTS idx_audit_business ON public.kot_audit_logs(business_id, action_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_action ON public.kot_audit_logs(business_id, action);
CREATE INDEX IF NOT EXISTS idx_audit_user ON public.kot_audit_logs(user_id);

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- 7. KITCHEN METRICS (Performance tracking)
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.kitchen_metrics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id TEXT NOT NULL,
  kitchen_id UUID NOT NULL REFERENCES public.kitchen_stations(id) ON DELETE CASCADE,
  
  -- Counts
  active_orders INT DEFAULT 0,
  completed_orders INT DEFAULT 0,
  cancelled_orders INT DEFAULT 0,
  delayed_orders INT DEFAULT 0,
  
  -- Timings
  avg_prep_time_seconds INT,
  max_prep_time_seconds INT,
  min_prep_time_seconds INT,
  
  -- SLA
  sla_compliance_percentage NUMERIC(5,2) DEFAULT 100,
  total_items_delayed INT DEFAULT 0,
  
  -- Performance score
  efficiency_score NUMERIC(5,2) DEFAULT 100, -- 0-100
  
  -- Period
  measured_at TIMESTAMPTZ DEFAULT NOW(),
  period_start TIMESTAMPTZ,
  period_end TIMESTAMPTZ,
  
  -- Metadata
  performance_stats JSONB DEFAULT '{}',
  
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_metrics_kitchen ON public.kitchen_metrics(kitchen_id);
CREATE INDEX IF NOT EXISTS idx_metrics_business ON public.kitchen_metrics(business_id, measured_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- 8. KITCHEN ROUTING RULES (Auto-routing configuration)
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.kitchen_routing_rules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id TEXT NOT NULL,
  
  -- Rule config
  rule_priority INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  
  -- Matching criteria
  match_type TEXT NOT NULL CHECK (match_type IN ('category', 'keyword', 'custom')),
  match_value TEXT NOT NULL,
  
  -- Target kitchen
  target_kitchen_id UUID NOT NULL REFERENCES public.kitchen_stations(id) ON DELETE CASCADE,
  
  -- Load balancing strategy
  load_balancing_strategy TEXT DEFAULT 'round_robin' CHECK (
    load_balancing_strategy IN ('round_robin', 'priority', 'load_balanced', 'random')
  ),
  
  -- SLA
  sla_seconds INT DEFAULT 900,
  
  -- Audit
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(business_id, match_type, match_value)
);

CREATE INDEX IF NOT EXISTS idx_routing_business ON public.kitchen_routing_rules(business_id);
CREATE INDEX IF NOT EXISTS idx_routing_priority ON public.kitchen_routing_rules(business_id, rule_priority DESC);

-- Example rules (commented out - requires target_kitchen_id to reference existing kitchen stations)
-- INSERT INTO public.kitchen_routing_rules (business_id, match_type, match_value, rule_priority, target_kitchen_id)
-- SELECT 'default', 'category', 'grill', 1, id FROM public.kitchen_stations WHERE business_id = 'default' AND name = 'grill' LIMIT 1
-- UNION ALL
-- SELECT 'default', 'category', 'beverages', 2, id FROM public.kitchen_stations WHERE business_id = 'default' AND name = 'beverages' LIMIT 1
-- UNION ALL
-- SELECT 'default', 'category', 'desserts', 3, id FROM public.kitchen_stations WHERE business_id = 'default' AND name = 'pastry' LIMIT 1
-- ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- 9. KOT DELAY ALERTS (Delay management)
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.kot_delay_alerts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  kot_id UUID NOT NULL REFERENCES public.kot_orders(id) ON DELETE CASCADE,
  item_id UUID REFERENCES public.kot_items(id) ON DELETE SET NULL,
  business_id TEXT NOT NULL,
  kitchen_id UUID REFERENCES public.kitchen_stations(id),
  
  -- Alert level
  alert_type TEXT NOT NULL CHECK (
    alert_type IN ('warning', 'critical', 'urgent')
  ),
  
  -- SLA info
  sla_deadline TIMESTAMPTZ,
  exceeded_by_seconds INT,
  
  -- Status
  is_acknowledged BOOLEAN DEFAULT FALSE,
  acknowledged_at TIMESTAMPTZ,
  acknowledged_by_uid TEXT,
  acknowledged_by_name TEXT,
  
  -- Resolution
  is_resolved BOOLEAN DEFAULT FALSE,
  resolved_at TIMESTAMPTZ,
  resolution_notes TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_alerts_kot ON public.kot_delay_alerts(kot_id);
CREATE INDEX IF NOT EXISTS idx_alerts_kitchen ON public.kot_delay_alerts(kitchen_id);
CREATE INDEX IF NOT EXISTS idx_alerts_unresolved ON public.kot_delay_alerts(business_id, is_resolved) WHERE is_resolved = FALSE;
CREATE INDEX IF NOT EXISTS idx_alerts_time ON public.kot_delay_alerts(business_id, created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- 10. KOT OFFLINE SYNC QUEUE (Offline support)
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.kot_offline_sync_queue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  
  -- Operation
  operation_type TEXT NOT NULL CHECK (
    operation_type IN ('create_kot', 'add_items', 'update_item_status', 'complete_batch')
  ),
  
  -- Target
  kot_id UUID,
  item_id UUID,
  batch_id UUID,
  
  -- Changes
  changes JSONB NOT NULL,
  
  -- Status
  sync_status TEXT DEFAULT 'pending' CHECK (
    sync_status IN ('pending', 'syncing', 'synced', 'conflict', 'failed')
  ),
  
  -- Conflict resolution
  conflict_detected_at TIMESTAMPTZ,
  conflict_details JSONB,
  conflict_resolution_strategy TEXT DEFAULT 'use_cloud' CHECK (
    conflict_resolution_strategy IN ('use_cloud', 'use_local', 'merge')
  ),
  
  -- Retry
  attempt_count INT DEFAULT 0,
  max_attempts INT DEFAULT 3,
  last_attempt_at TIMESTAMPTZ,
  last_error TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  synced_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sync_queue_device ON public.kot_offline_sync_queue(device_id, sync_status);
CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON public.kot_offline_sync_queue(business_id, sync_status);

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- 11. VIEWS
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════

-- View: Active KOT orders
CREATE OR REPLACE VIEW public.v_active_kot_orders AS
SELECT
  ko.id,
  ko.business_id,
  ko.kot_number,
  ko.status,
  ko.priority,
  ko.total_items,
  ko.prepared_items,
  ko.served_items,
  ko.kot_created_at,
  ko.sent_to_kitchen_at,
  ko.completed_at,
  ko.is_delayed,
  ko.sla_tier,
  ko.total_prep_time_seconds,
  ks.display_name AS primary_kitchen,
  ko.table_number,
  ko.customer_name,
  ko.notes,
  ko.special_instructions,
  ko.current_batch_number,
  COUNT(DISTINCT kib.id) FILTER (WHERE kib.is_new_item_batch = TRUE)::INT AS new_batch_count,
  COUNT(DISTINCT ki.id)::INT AS total_items_count,
  COUNT(DISTINCT ki.id) FILTER (WHERE ki.status = 'ready')::INT AS ready_items_count,
  COUNT(DISTINCT ki.id) FILTER (WHERE ki.status = 'pending')::INT AS pending_items_count,
  COUNT(DISTINCT ki.id) FILTER (WHERE ki.status = 'preparing')::INT AS preparing_items_count,
  ROUND(100.0 * (COUNT(DISTINCT ki.id) FILTER (WHERE ki.status IN ('ready', 'served')) / 
    NULLIF(COUNT(DISTINCT ki.id), 0))::NUMERIC, 2)::NUMERIC AS completion_percentage,
  EXTRACT(EPOCH FROM (COALESCE(ko.completed_at, NOW()) - ko.kot_created_at))::INT AS elapsed_seconds
FROM public.kot_orders ko
LEFT JOIN public.kitchen_stations ks ON ko.primary_kitchen_id = ks.id
LEFT JOIN public.kot_item_batches kib ON ko.id = kib.kot_id
LEFT JOIN public.kot_items ki ON kib.id = ki.batch_id
WHERE ko.status IN ('pending', 'in_progress', 'ready')
GROUP BY ko.id, ks.id;

-- View: Delayed items
CREATE OR REPLACE VIEW public.v_delayed_kot_items AS
SELECT
  ki.id,
  ki.kot_id,
  ki.business_id,
  ki.item_name,
  ki.category,
  ki.status,
  ki.assigned_kitchen_id,
  ks.display_name AS kitchen_name,
  ki.created_at,
  ki.started_preparing_at,
  ki.ready_at,
  ki.sla_seconds,
  ki.delay_seconds,
  ki.is_sla_violated,
  ko.kot_number,
  ko.priority,
  kda.alert_type,
  kda.id AS alert_id,
  kda.is_acknowledged
FROM public.kot_items ki
JOIN public.kot_orders ko ON ki.kot_id = ko.id
LEFT JOIN public.kitchen_stations ks ON ki.assigned_kitchen_id = ks.id
LEFT JOIN public.kot_delay_alerts kda ON ki.id = kda.item_id AND kda.is_resolved = FALSE
WHERE ki.is_sla_violated = TRUE AND ki.status != 'served'
ORDER BY ki.delay_seconds DESC;

-- View: Kitchen workload
CREATE OR REPLACE VIEW public.v_kitchen_workload AS
SELECT
  ks.id,
  ks.business_id,
  ks.name,
  ks.display_name,
  COUNT(DISTINCT ko.id) FILTER (WHERE ko.status IN ('pending', 'in_progress'))::INT AS active_orders,
  COUNT(DISTINCT ki.id) FILTER (WHERE ki.status = 'pending')::INT AS pending_items,
  COUNT(DISTINCT ki.id) FILTER (WHERE ki.status = 'preparing')::INT AS preparing_items,
  COUNT(DISTINCT ki.id) FILTER (WHERE ki.status = 'ready')::INT AS ready_items,
  AVG(km.avg_prep_time_seconds)::INT AS avg_prep_time_seconds,
  AVG(km.efficiency_score)::NUMERIC(5,2) AS efficiency_score,
  COUNT(DISTINCT kda.id) FILTER (WHERE kda.is_resolved = FALSE)::INT AS active_delays,
  ks.is_online,
  ks.last_heartbeat
FROM public.kitchen_stations ks
LEFT JOIN public.kot_items ki ON ks.id = ki.assigned_kitchen_id
LEFT JOIN public.kot_orders ko ON ki.kot_id = ko.id
LEFT JOIN public.kitchen_metrics km ON ks.id = km.kitchen_id
LEFT JOIN public.kot_delay_alerts kda ON ks.id = kda.kitchen_id
GROUP BY ks.id;

-- View: Batch summary
CREATE OR REPLACE VIEW public.v_batch_summary AS
SELECT
  kib.id,
  kib.kot_id,
  kib.business_id,
  kib.batch_number,
  kib.is_new_item_batch,
  kib.batch_status,
  kib.item_count,
  kib.prepared_count,
  kib.completion_percentage,
  COUNT(DISTINCT ki.id)::INT AS total_items,
  COUNT(DISTINCT ki.id) FILTER (WHERE ki.status = 'pending')::INT AS pending_items,
  COUNT(DISTINCT ki.id) FILTER (WHERE ki.status = 'preparing')::INT AS preparing_items,
  COUNT(DISTINCT ki.id) FILTER (WHERE ki.status = 'ready')::INT AS ready_items,
  COUNT(DISTINCT ki.id) FILTER (WHERE ki.status = 'served')::INT AS served_items,
  ko.kot_number,
  ko.status AS kot_status,
  kib.batch_added_at,
  kib.batch_completed_at
FROM public.kot_item_batches kib
JOIN public.kot_orders ko ON kib.kot_id = ko.id
LEFT JOIN public.kot_items ki ON kib.id = ki.batch_id
GROUP BY kib.id, ko.id;

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- 12. SEQUENCE FOR KOT NUMBERS
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════

CREATE SEQUENCE IF NOT EXISTS kot_number_sequence START WITH 1 INCREMENT BY 1;

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- 13. TRIGGERS
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════

-- Trigger: Generate KOT number
CREATE OR REPLACE FUNCTION fn_generate_kot_number()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_seq_value BIGINT;
  v_year TEXT;
BEGIN
  IF NEW.kot_number IS NULL THEN
    v_seq_value := nextval('kot_number_sequence');
    v_year := TO_CHAR(NOW(), 'YYYY');
    NEW.kot_number := 'KOT-' || v_year || '-' || LPAD(v_seq_value::TEXT, 5, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_generate_kot_number ON public.kot_orders;
CREATE TRIGGER trg_generate_kot_number
BEFORE INSERT ON public.kot_orders
FOR EACH ROW EXECUTE FUNCTION fn_generate_kot_number();

-- Trigger: Auto-update KOT status based on items
CREATE OR REPLACE FUNCTION fn_update_kot_status()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_total_items INT;
  v_pending_items INT;
  v_preparing_items INT;
  v_ready_items INT;
  v_served_items INT;
  v_new_status TEXT;
BEGIN
  SELECT
    COUNT(*)::INT,
    COUNT(*) FILTER (WHERE status = 'pending')::INT,
    COUNT(*) FILTER (WHERE status = 'preparing')::INT,
    COUNT(*) FILTER (WHERE status = 'ready')::INT,
    COUNT(*) FILTER (WHERE status = 'served')::INT
  INTO v_total_items, v_pending_items, v_preparing_items, v_ready_items, v_served_items
  FROM public.kot_items
  WHERE kot_id = NEW.kot_id OR NEW.kot_id IN (
    SELECT kot_id FROM public.kot_items WHERE id = NEW.id
  );

  -- Determine status
  IF v_total_items = 0 THEN
    v_new_status := 'pending';
  ELSIF v_pending_items > 0 THEN
    v_new_status := 'pending';
  ELSIF v_preparing_items > 0 THEN
    v_new_status := 'in_progress';
  ELSIF v_ready_items = v_total_items THEN
    v_new_status := 'ready';
  ELSIF v_served_items = v_total_items THEN
    v_new_status := 'served';
  ELSE
    v_new_status := 'in_progress';
  END IF;

  UPDATE public.kot_orders
  SET status = v_new_status,
      prepared_items = v_ready_items + v_served_items,
      served_items = v_served_items,
      updated_at = NOW()
  WHERE id = COALESCE(NEW.kot_id, NEW.batch_id);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_kot_status ON public.kot_items;
CREATE TRIGGER trg_update_kot_status
AFTER UPDATE OF status ON public.kot_items
FOR EACH ROW EXECUTE FUNCTION fn_update_kot_status();

-- Trigger: Auto-detect SLA violations
CREATE OR REPLACE FUNCTION fn_detect_sla_violation()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_sla_deadline TIMESTAMPTZ;
  v_delay_seconds INT;
BEGIN
  IF NEW.status IN ('preparing', 'ready', 'served') AND NEW.started_preparing_at IS NOT NULL THEN
    v_sla_deadline := NEW.started_preparing_at + INTERVAL '1 second' * COALESCE(NEW.sla_seconds, 900);
    
    IF NOW() > v_sla_deadline THEN
      v_delay_seconds := EXTRACT(EPOCH FROM (NOW() - v_sla_deadline))::INT;
      NEW.is_sla_violated := TRUE;
      NEW.delay_seconds := v_delay_seconds;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_detect_sla_violation ON public.kot_items;
CREATE TRIGGER trg_detect_sla_violation
BEFORE UPDATE ON public.kot_items
FOR EACH ROW EXECUTE FUNCTION fn_detect_sla_violation();

-- Trigger: Record item status history
CREATE OR REPLACE FUNCTION fn_record_item_status_history()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_time_in_prev_status INT;
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    v_time_in_prev_status := EXTRACT(EPOCH FROM (NOW() - 
      COALESCE(
        CASE OLD.status
          WHEN 'pending' THEN OLD.created_at
          WHEN 'preparing' THEN OLD.started_preparing_at
          WHEN 'ready' THEN OLD.ready_at
          WHEN 'served' THEN OLD.served_at
        END,
        OLD.created_at
      )
    ))::INT;

    INSERT INTO public.kot_item_status_history (
      item_id, kot_id, business_id, from_status, to_status,
      status_changed_at, time_in_previous_status_seconds
    ) VALUES (
      NEW.id, NEW.kot_id, NEW.business_id, OLD.status, NEW.status,
      NOW(), v_time_in_prev_status
    );

    -- Auto-set timestamps
    CASE NEW.status
      WHEN 'preparing' THEN NEW.started_preparing_at := NOW();
      WHEN 'ready' THEN NEW.ready_at := NOW();
      WHEN 'served' THEN NEW.served_at := NOW();
    END CASE;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_record_item_status_history ON public.kot_items;
CREATE TRIGGER trg_record_item_status_history
BEFORE UPDATE ON public.kot_items
FOR EACH ROW EXECUTE FUNCTION fn_record_item_status_history();

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- 14. ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.kot_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kot_item_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kot_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kot_item_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kot_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kitchen_stations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kitchen_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kot_delay_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kot_offline_sync_queue ENABLE ROW LEVEL SECURITY;

-- Open policies for now (tighten based on auth)
CREATE POLICY "allow_all_kot_orders" ON public.kot_orders FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_batches" ON public.kot_item_batches FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_items" ON public.kot_items FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_history" ON public.kot_item_status_history FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_audit" ON public.kot_audit_logs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_stations" ON public.kitchen_stations FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_metrics" ON public.kitchen_metrics FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_alerts" ON public.kot_delay_alerts FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_sync" ON public.kot_offline_sync_queue FOR ALL USING (true) WITH CHECK (true);

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- 15. DATABASE FUNCTIONS FOR OPERATIONS
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════

-- Function: Create KOT order
CREATE OR REPLACE FUNCTION fn_create_kot_order(
  p_business_id TEXT,
  p_order_id UUID,
  p_priority TEXT DEFAULT 'normal',
  p_table_number INT DEFAULT NULL,
  p_customer_name TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
  kot_id UUID,
  kot_number TEXT,
  created_at TIMESTAMPTZ
) LANGUAGE plpgsql AS $$
DECLARE
  v_kot_id UUID;
BEGIN
  INSERT INTO public.kot_orders (
    business_id, order_id, priority, table_number,
    customer_name, notes, status, sent_to_kitchen_at
  ) VALUES (
    p_business_id, p_order_id, p_priority, p_table_number,
    p_customer_name, p_notes, 'pending', NOW()
  ) RETURNING id INTO v_kot_id;

  RETURN QUERY SELECT v_kot_id, t.kot_number, t.kot_created_at
  FROM public.kot_orders t WHERE t.id = v_kot_id;
END;
$$;

-- Function: Add items to KOT (creates new batch)
CREATE OR REPLACE FUNCTION fn_add_items_to_kot(
  p_kot_id UUID,
  p_items JSONB -- [{item_id, item_name, category, quantity}]
)
RETURNS TABLE (
  batch_id UUID,
  batch_number INT,
  items_added INT
) LANGUAGE plpgsql AS $$
DECLARE
  v_batch_id UUID;
  v_batch_number INT;
  v_item JSONB;
  v_items_added INT := 0;
  v_kot_record RECORD;
BEGIN
  -- Get KOT
  SELECT id, current_batch_number, business_id INTO v_kot_record
  FROM public.kot_orders WHERE id = p_kot_id;

  IF v_kot_record IS NULL THEN
    RAISE EXCEPTION 'KOT not found: %', p_kot_id;
  END IF;

  -- Create new batch
  v_batch_number := v_kot_record.current_batch_number + 1;
  
  INSERT INTO public.kot_item_batches (
    kot_id, business_id, batch_number, is_new_item_batch,
    item_count, batch_added_at
  ) VALUES (
    p_kot_id, v_kot_record.business_id, v_batch_number, TRUE,
    JSONB_ARRAY_LENGTH(p_items), NOW()
  ) RETURNING id INTO v_batch_id;

  -- Add items
  FOR v_item IN SELECT jsonb_array_elements(p_items)
  LOOP
    INSERT INTO public.kot_items (
      kot_id, batch_id, business_id, item_name, category,
      quantity, status, created_at
    ) VALUES (
      p_kot_id, v_batch_id, v_kot_record.business_id,
      v_item->>'item_name', v_item->>'category',
      COALESCE((v_item->>'quantity')::INT, 1), 'pending', NOW()
    );
    v_items_added := v_items_added + 1;
  END LOOP;

  -- Update KOT
  UPDATE public.kot_orders
  SET current_batch_number = v_batch_number,
      batch_count = v_batch_number,
      status = 'in_progress',
      updated_at = NOW()
  WHERE id = p_kot_id;

  RETURN QUERY SELECT v_batch_id, v_batch_number, v_items_added;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- 16. SEND NOTIFICATIONS
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════

NOTIFY pgrst, 'reload schema';

-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
-- ✅ SCHEMA COMPLETE
-- ═══════════════════════════════════════════════════════════════════════════════════════════════════════
