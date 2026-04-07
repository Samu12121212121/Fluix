-- migrations/004_create_psd2_tables.sql
-- Tablas para gestión de consentimientos y cursores PSD2.

CREATE TABLE psd2_consents (
  bank_id               VARCHAR(50)  PRIMARY KEY,
  access_token          TEXT         NOT NULL,
  refresh_token         TEXT,
  expires_at            TIMESTAMP    NOT NULL,
  status                VARCHAR(20)  NOT NULL DEFAULT 'active'
                                     CHECK (status IN ('active','expired','revoked')),
  last_notification_at  TIMESTAMP,
  created_at            TIMESTAMP    NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Cursor por cuenta: hasta dónde hemos procesado en cada banco+cuenta
CREATE TABLE psd2_account_cursors (
  bank_id           VARCHAR(50)  NOT NULL,
  account_id        VARCHAR(255) NOT NULL,
  last_processed_at TIMESTAMP    NOT NULL,
  PRIMARY KEY (bank_id, account_id)
);

CREATE INDEX idx_psd2_consents_expires
  ON psd2_consents(expires_at)
  WHERE status = 'active';

