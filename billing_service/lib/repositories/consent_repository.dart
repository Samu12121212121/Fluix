// lib/repositories/consent_repository.dart

import '../database/database.dart';
import '../models/psd2_consent.dart';

class ConsentRepository {
  final Database _db;
  ConsentRepository(this._db);

  Future<List<Psd2Consent>> getAll() async {
    final rows = await _db.queryMany(
      "SELECT * FROM psd2_consents WHERE status = 'active'",
    );
    return rows.map(_fromRow).toList();
  }

  Future<Psd2Consent?> getByBankId(String bankId) async {
    final row = await _db.queryOne(
      'SELECT * FROM psd2_consents WHERE bank_id = @bankId',
      {'bankId': bankId},
    );
    return row != null ? _fromRow(row) : null;
  }

  Future<void> upsert(Psd2Consent consent) async {
    await _db.execute('''
      INSERT INTO psd2_consents
        (bank_id, access_token, refresh_token, expires_at, status, updated_at)
      VALUES
        (@bankId, @accessToken, @refreshToken, @expiresAt, 'active', NOW())
      ON CONFLICT (bank_id) DO UPDATE SET
        access_token  = EXCLUDED.access_token,
        refresh_token = EXCLUDED.refresh_token,
        expires_at    = EXCLUDED.expires_at,
        status        = 'active',
        updated_at    = NOW()
    ''', {
      'bankId':       consent.bankId,
      'accessToken':  consent.accessToken,
      'refreshToken': consent.refreshToken,
      'expiresAt':    consent.expiresAt,
    });
  }

  Future<void> markExpired(String bankId) async {
    await _db.execute(
      "UPDATE psd2_consents SET status = 'expired', updated_at = NOW() "
      'WHERE bank_id = @bankId',
      {'bankId': bankId},
    );
  }

  Future<bool> wasNotifiedRecently(String bankId) async {
    final row = await _db.queryOne(
      'SELECT last_notification_at FROM psd2_consents WHERE bank_id = @bankId',
      {'bankId': bankId},
    );
    if (row == null || row['last_notification_at'] == null) return false;
    final last = row['last_notification_at'] as DateTime;
    return DateTime.now().difference(last).inHours < 24;
  }

  Future<void> markNotified(String bankId) async {
    await _db.execute(
      'UPDATE psd2_consents SET last_notification_at = NOW() '
      'WHERE bank_id = @bankId',
      {'bankId': bankId},
    );
  }

  Future<DateTime?> getLastProcessedDate(String bankId, String accountId) async {
    final row = await _db.queryOne(
      'SELECT last_processed_at FROM psd2_account_cursors '
      'WHERE bank_id = @bankId AND account_id = @accountId',
      {'bankId': bankId, 'accountId': accountId},
    );
    return row?['last_processed_at'] as DateTime?;
  }

  Future<void> updateLastProcessedDate(
    String bankId,
    String accountId,
    DateTime date,
  ) async {
    await _db.execute('''
      INSERT INTO psd2_account_cursors
        (bank_id, account_id, last_processed_at)
      VALUES
        (@bankId, @accountId, @date)
      ON CONFLICT (bank_id, account_id) DO UPDATE SET
        last_processed_at = EXCLUDED.last_processed_at
    ''', {'bankId': bankId, 'accountId': accountId, 'date': date});
  }

  Psd2Consent _fromRow(Map<String, dynamic> r) => Psd2Consent(
    bankId:       r['bank_id'] as String,
    accessToken:  r['access_token'] as String,
    refreshToken: r['refresh_token'] as String?,
    expiresAt:    r['expires_at'] as DateTime,
    status:       r['status'] as String,
  );
}

