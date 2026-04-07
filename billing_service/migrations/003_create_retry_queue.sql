-- migrations/003_create_retry_queue.sql
-- Cola de reintentos con backoff exponencial.

CREATE TABLE retry_queue (
  event_id        VARCHAR(255) PRIMARY KEY,
  provider_id     VARCHAR(50)  NOT NULL,
  payload         JSONB        NOT NULL,
  status          VARCHAR(20)  NOT NULL DEFAULT 'pending'
                               CHECK (status IN ('pending','retrying',
                                                  'completed','dead_letter')),
  attempt_count   INTEGER      NOT NULL DEFAULT 0,
  next_attempt_at TIMESTAMP    NOT NULL DEFAULT NOW(),
  last_error      TEXT,
  created_at      TIMESTAMP    NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Índice para procesar la cola ordenadamente
CREATE INDEX idx_retry_due
  ON retry_queue(next_attempt_at, status)
  WHERE status IN ('pending','retrying');

-- Índice para consultas de monitoreo
CREATE INDEX idx_retry_status_updated
  ON retry_queue(status, updated_at DESC);

