-- migrations/002_create_invoices.sql
-- Tabla principal de facturas emitidas (F1, F2, R4).

CREATE TABLE invoices (
  id                          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  serie                       VARCHAR(20)  NOT NULL,
  numero                      VARCHAR(20)  NOT NULL,
  tipo                        VARCHAR(20)  NOT NULL CHECK (tipo IN ('complete','simplified','rectificativa')),
  tipo_verifactu              VARCHAR(5)   NOT NULL CHECK (tipo_verifactu IN ('F1','F2','R4')),
  tipo_rectificativa          VARCHAR(5),
  factura_rectificada_serie   VARCHAR(20),
  factura_rectificada_numero  VARCHAR(20),
  factura_rectificada_fecha   DATE,

  -- Emisor
  emisor_nif                  VARCHAR(20)  NOT NULL,
  emisor_nombre               VARCHAR(255) NOT NULL,

  -- Destinatario
  destinatario_nif            VARCHAR(20),
  destinatario_nombre         VARCHAR(255),
  destinatario_direccion      TEXT,
  destinatario_email          VARCHAR(255),

  -- Fechas
  fecha_expedicion            TIMESTAMP    NOT NULL DEFAULT NOW(),
  fecha_operacion             TIMESTAMP    NOT NULL,

  -- Importes (en EUR, 2 decimales)
  base_imponible              NUMERIC(12,2) NOT NULL,
  tipo_iva                    NUMERIC(5,2)  NOT NULL,
  cuota_iva                   NUMERIC(12,2) NOT NULL,
  retencion_irpf              NUMERIC(12,2) NOT NULL DEFAULT 0,
  recargo                     NUMERIC(12,2) NOT NULL DEFAULT 0,
  importe_total               NUMERIC(12,2) NOT NULL,

  -- Metadatos fiscales
  descripcion                 TEXT          NOT NULL,
  clave_regimen               VARCHAR(5)    NOT NULL DEFAULT '01',
  calificacion_operacion      VARCHAR(5)    NOT NULL DEFAULT 'S1',

  -- Proveedor de pago
  referencia_externa          VARCHAR(255),
  proveedor_pago              VARCHAR(50)   NOT NULL,

  -- Verifactu
  registro_verifactu          TEXT,
  hash_verifactu              VARCHAR(255),

  -- Auditoría
  created_at                  TIMESTAMP     NOT NULL DEFAULT NOW(),
  updated_at                  TIMESTAMP     NOT NULL DEFAULT NOW()
);

-- Numeración única por serie
CREATE UNIQUE INDEX idx_invoices_serie_numero
  ON invoices(serie, numero);

-- Búsqueda por referencia externa (para detectar reembolsos)
CREATE INDEX idx_invoices_referencia
  ON invoices(referencia_externa)
  WHERE referencia_externa IS NOT NULL;

-- Búsqueda por destinatario
CREATE INDEX idx_invoices_destinatario_nif
  ON invoices(destinatario_nif)
  WHERE destinatario_nif IS NOT NULL;

-- Búsqueda por fecha
CREATE INDEX idx_invoices_fecha
  ON invoices(fecha_expedicion DESC);

-- ── Contadores de series (para numeración sin huecos) ──────────────────────

CREATE TABLE invoice_series_counters (
  serie        VARCHAR(20) PRIMARY KEY,
  last_number  INTEGER     NOT NULL DEFAULT 0,
  created_at   TIMESTAMP   NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMP   NOT NULL DEFAULT NOW()
);

-- ── Tabla de clientes (para ClientResolver) ────────────────────────────────

CREATE TABLE clients (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  nif                 VARCHAR(20),
  name                VARCHAR(255),
  email               VARCHAR(255),
  address             TEXT,
  tipo                VARCHAR(10)  DEFAULT 'b2c',
  external_reference  VARCHAR(255),
  stripe_customer_id  VARCHAR(100),
  created_at          TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_clients_external ON clients(external_reference);
CREATE INDEX idx_clients_stripe   ON clients(stripe_customer_id);
CREATE INDEX idx_clients_nif      ON clients(nif) WHERE nif IS NOT NULL;

-- ── Configuración del negocio ─────────────────────────────────────────────

CREATE TABLE business_config (
  id                    INTEGER      PRIMARY KEY DEFAULT 1,
  emisor_nif            VARCHAR(20)  NOT NULL,
  emisor_nombre         VARCHAR(255) NOT NULL,
  recargo_equivalencia  BOOLEAN      NOT NULL DEFAULT FALSE,
  sujeta_retencion_irpf BOOLEAN      NOT NULL DEFAULT FALSE,
  is_nuevo_autonomo     BOOLEAN      NOT NULL DEFAULT FALSE,
  default_product_code  VARCHAR(50)  NOT NULL DEFAULT 'default',
  created_at            TIMESTAMP    NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMP    NOT NULL DEFAULT NOW(),
  CONSTRAINT single_row CHECK (id = 1)
);

-- ── Mapeos de IVA por producto ────────────────────────────────────────────

CREATE TABLE vat_mappings (
  product_code   VARCHAR(100) PRIMARY KEY,
  vat_rate_code  VARCHAR(20)  NOT NULL
                              CHECK (vat_rate_code IN ('general','reduced','superReduced','exempt')),
  description    TEXT,
  created_at     TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Ejemplo: INSERT INTO vat_mappings VALUES ('hosteleria','reduced','Hostelería 10%',NOW());

