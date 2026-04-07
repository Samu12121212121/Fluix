-- migrations/005_multi_tenant.sql
-- Arquitectura multi-tenant: cada empresa (tenant) tiene sus propios datos
-- aislados con tenant_id en todas las tablas.

-- ── Extensión para gen_random_uuid (si no existe) ────────────────────────
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ══════════════════════════════════════════════════════════════════════════
-- TABLA PRINCIPAL DE TENANTS
-- ══════════════════════════════════════════════════════════════════════════

CREATE TABLE tenants (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre          VARCHAR(255) NOT NULL,
  nif             VARCHAR(20)  NOT NULL UNIQUE,
  email_admin     VARCHAR(255) NOT NULL UNIQUE,
  plan            VARCHAR(20)  NOT NULL DEFAULT 'basic'
                               CHECK (plan IN ('basic','pro','enterprise')),
  activo          BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMP    NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════════════════
-- CREDENCIALES DE PAGO POR TENANT (cifradas AES-256-GCM)
-- ══════════════════════════════════════════════════════════════════════════
-- NUNCA guardar credenciales en texto plano.
-- El campo `credentials` es un JSON cifrado con AES-256-GCM a nivel de app.

CREATE TABLE tenant_payment_credentials (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID         NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  provider        VARCHAR(30)  NOT NULL
                               CHECK (provider IN ('stripe','redsys',
                                                    'psd2_caixabank','psd2_santander',
                                                    'psd2_bbva','psd2_sabadell',
                                                    'psd2_bankinter')),
  credentials     TEXT         NOT NULL,   -- JSON cifrado con AES-256-GCM
  activo          BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMP    NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMP    NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, provider)
);

-- ══════════════════════════════════════════════════════════════════════════
-- CONFIGURACIÓN FISCAL POR TENANT
-- ══════════════════════════════════════════════════════════════════════════

CREATE TABLE tenant_business_config (
  tenant_id                 UUID         PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE,
  emisor_nif                VARCHAR(20)  NOT NULL,
  emisor_nombre             VARCHAR(255) NOT NULL,
  emisor_direccion          TEXT         NOT NULL DEFAULT '',
  emisor_cp                 VARCHAR(10),
  emisor_municipio          VARCHAR(100),
  sujeta_retencion_irpf     BOOLEAN      NOT NULL DEFAULT FALSE,
  is_nuevo_autonomo         BOOLEAN      NOT NULL DEFAULT FALSE,
  recargo_equivalencia      BOOLEAN      NOT NULL DEFAULT FALSE,
  default_product_code      VARCHAR(100) NOT NULL DEFAULT 'SERVICIOS_GENERALES',
  updated_at                TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════════════════
-- MAPEO PRODUCTO → IVA POR TENANT
-- ══════════════════════════════════════════════════════════════════════════

CREATE TABLE tenant_vat_mappings (
  tenant_id       UUID         NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  product_code    VARCHAR(100) NOT NULL,
  vat_rate        VARCHAR(20)  NOT NULL
                               CHECK (vat_rate IN ('general','reduced',
                                                    'super_reduced','exempt')),
  description     VARCHAR(255),
  updated_at      TIMESTAMP    NOT NULL DEFAULT NOW(),
  PRIMARY KEY (tenant_id, product_code)
);

-- ══════════════════════════════════════════════════════════════════════════
-- USUARIOS DE LA APP (uno o varios por tenant)
-- ══════════════════════════════════════════════════════════════════════════

CREATE TABLE tenant_users (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID         NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  email           VARCHAR(255) NOT NULL UNIQUE,
  password_hash   VARCHAR(255) NOT NULL,   -- bcrypt
  role            VARCHAR(20)  NOT NULL DEFAULT 'employee'
                               CHECK (role IN ('admin','employee','superadmin')),
  activo          BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════════════════
-- MODIFICAR TABLAS EXISTENTES: añadir tenant_id
-- ══════════════════════════════════════════════════════════════════════════

-- Crear un tenant "default" para datos existentes
INSERT INTO tenants (id, nombre, nif, email_admin, plan)
VALUES ('00000000-0000-0000-0000-000000000000', 'Tenant Migración', 'MIGRATION', 'migration@system', 'enterprise')
ON CONFLICT DO NOTHING;

-- payment_processing_log
ALTER TABLE payment_processing_log
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES tenants(id);
UPDATE payment_processing_log SET tenant_id = '00000000-0000-0000-0000-000000000000' WHERE tenant_id IS NULL;
ALTER TABLE payment_processing_log ALTER COLUMN tenant_id SET NOT NULL;

-- invoices (auto_invoices en el prompt, pero la tabla real se llama "invoices")
ALTER TABLE invoices
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES tenants(id);
UPDATE invoices SET tenant_id = '00000000-0000-0000-0000-000000000000' WHERE tenant_id IS NULL;
ALTER TABLE invoices ALTER COLUMN tenant_id SET NOT NULL;

-- retry_queue
ALTER TABLE retry_queue
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES tenants(id);
UPDATE retry_queue SET tenant_id = '00000000-0000-0000-0000-000000000000' WHERE tenant_id IS NULL;
ALTER TABLE retry_queue ALTER COLUMN tenant_id SET NOT NULL;

-- psd2_consents
ALTER TABLE psd2_consents
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES tenants(id);
UPDATE psd2_consents SET tenant_id = '00000000-0000-0000-0000-000000000000' WHERE tenant_id IS NULL;
ALTER TABLE psd2_consents ALTER COLUMN tenant_id SET NOT NULL;

-- invoice_series_counters — recrear con tenant_id en la PK
ALTER TABLE invoice_series_counters
  ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES tenants(id);
UPDATE invoice_series_counters SET tenant_id = '00000000-0000-0000-0000-000000000000' WHERE tenant_id IS NULL;
ALTER TABLE invoice_series_counters ALTER COLUMN tenant_id SET NOT NULL;
-- La numeración es única POR TENANT
ALTER TABLE invoice_series_counters DROP CONSTRAINT IF EXISTS invoice_series_counters_pkey;
ALTER TABLE invoice_series_counters ADD PRIMARY KEY (tenant_id, serie);

-- ══════════════════════════════════════════════════════════════════════════
-- ÍNDICES DE RENDIMIENTO
-- ══════════════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_ppl_tenant          ON payment_processing_log(tenant_id);
CREATE INDEX IF NOT EXISTS idx_invoices_tenant      ON invoices(tenant_id);
CREATE INDEX IF NOT EXISTS idx_retry_tenant         ON retry_queue(tenant_id);
CREATE INDEX IF NOT EXISTS idx_consents_tenant      ON psd2_consents(tenant_id);
CREATE INDEX IF NOT EXISTS idx_credentials_tenant   ON tenant_payment_credentials(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_users_tenant  ON tenant_users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_invoices_tenant_date ON invoices(tenant_id, fecha_expedicion DESC);

