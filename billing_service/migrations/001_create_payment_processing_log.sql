-- migrations/001_create_payment_processing_log.sql
-- Tabla de idempotencia atómica. Un único INSERT evita race conditions.

CREATE TABLE payment_processing_log (
  event_id        VARCHAR(255) PRIMARY KEY,
  provider_id     VARCHAR(50)  NOT NULL,
  status          VARCHAR(20)  NOT NULL DEFAULT 'processing'
                               CHECK (status IN ('processing','completed',
                                                  'failed','duplicate')),
  invoice_id      VARCHAR(255),
  error_message   TEXT,
  locked_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
  completed_at    TIMESTAMP,
  created_at      TIMESTAMP    NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Índice para limpiar locks huérfanos eficientemente
CREATE INDEX idx_ppl_status_locked
  ON payment_processing_log(status, locked_at)
  WHERE status = 'processing';

-- Índice para buscar por proveedor
CREATE INDEX idx_ppl_provider
  ON payment_processing_log(provider_id, created_at DESC);

