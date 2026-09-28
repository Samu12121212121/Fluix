import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO IA — OpenAI (GPT) y Anthropic (Claude)
//
// La API key se guarda en Firestore bajo:
//   usuarios/{uid}/configuracion/api_keys
//   → campo: 'openai'  o  'claude'
//
// Uso:
//   final ia = IaService();
//   final resp = await ia.pregunta('Resume lo que pasa hoy en mi negocio: ...');
// ─────────────────────────────────────────────────────────────────────────────

enum ProveedorIA { openai, claude, ninguno }

class IaService {
  static final IaService _i = IaService._();
  factory IaService() => _i;
  IaService._();

  final _db = FirebaseFirestore.instance;

  // ── Obtener API key guardada ──────────────────────────────────────────────

  Future<String?> obtenerApiKey(String apiId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final doc = await _db
          .collection('usuarios').doc(uid)
          .collection('configuracion').doc('api_keys')
          .get();
      return doc.data()?[apiId] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> guardarApiKey(String apiId, String key) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('usuarios').doc(uid)
        .collection('configuracion').doc('api_keys')
        .set({apiId: key.trim()}, SetOptions(merge: true));
  }

  Future<void> eliminarApiKey(String apiId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('usuarios').doc(uid)
        .collection('configuracion').doc('api_keys')
        .update({apiId: FieldValue.delete()});
  }

  // ── Detectar qué proveedor tiene configurado ──────────────────────────────

  Future<ProveedorIA> proveedorDisponible() async {
    final openaiKey = await obtenerApiKey('openai');
    if (openaiKey != null && openaiKey.isNotEmpty) return ProveedorIA.openai;
    final claudeKey = await obtenerApiKey('claude');
    if (claudeKey != null && claudeKey.isNotEmpty) return ProveedorIA.claude;
    return ProveedorIA.ninguno;
  }

  // ── Llamada principal — elige el proveedor disponible ────────────────────

  /// Envía un [prompt] y devuelve la respuesta en texto.
  /// Usa OpenAI si está configurado, si no Claude, si no devuelve null.
  Future<String?> pregunta(
    String prompt, {
    String? sistemaPrompt,
    int maxTokens = 512,
  }) async {
    final proveedor = await proveedorDisponible();
    switch (proveedor) {
      case ProveedorIA.openai:
        return _llamarOpenAI(prompt, sistemaPrompt: sistemaPrompt, maxTokens: maxTokens);
      case ProveedorIA.claude:
        return _llamarClaude(prompt, sistemaPrompt: sistemaPrompt, maxTokens: maxTokens);
      case ProveedorIA.ninguno:
        return null;
    }
  }

  // ── OpenAI ────────────────────────────────────────────────────────────────

  Future<String?> _llamarOpenAI(
    String prompt, {
    String? sistemaPrompt,
    int maxTokens = 512,
  }) async {
    final key = await obtenerApiKey('openai');
    if (key == null || key.isEmpty) return null;

    final messages = <Map<String, String>>[
      if (sistemaPrompt != null) {'role': 'system', 'content': sistemaPrompt},
      {'role': 'user', 'content': prompt},
    ];

    try {
      final resp = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',        // barato y rápido
          'messages': messages,
          'max_tokens': maxTokens,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['choices'] as List).first['message']['content'] as String?;
      }
      debugPrint('❌ OpenAI error ${resp.statusCode}: ${resp.body}');
      return null;
    } catch (e) {
      debugPrint('❌ OpenAI exception: $e');
      return null;
    }
  }

  // ── Claude (Anthropic) ───────────────────────────────────────────────────

  Future<String?> _llamarClaude(
    String prompt, {
    String? sistemaPrompt,
    int maxTokens = 512,
  }) async {
    final key = await obtenerApiKey('claude');
    if (key == null || key.isEmpty) return null;

    try {
      final body = <String, dynamic>{
        'model': 'claude-haiku-4-5-20251001',   // más barato y rápido
        'max_tokens': maxTokens,
        'messages': [{'role': 'user', 'content': prompt}],
        if (sistemaPrompt != null) 'system': sistemaPrompt,
      };

      final resp = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': key,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final content = (data['content'] as List).first;
        return content['text'] as String?;
      }
      debugPrint('❌ Claude error ${resp.statusCode}: ${resp.body}');
      return null;
    } catch (e) {
      debugPrint('❌ Claude exception: $e');
      return null;
    }
  }

  // ── Briefing matutino IA ─────────────────────────────────────────────────

  /// Genera un briefing inteligente del día basado en los datos del negocio.
  Future<String?> generarBriefingIA({
    required int reservasHoy,
    required int pedidosHoy,
    required int facturasHoy,
    required int tareasAbiertas,
    required int facturasPendientes,
    required String nombreEmpresa,
  }) async {
    final prompt = '''
Eres el asistente de negocio de $nombreEmpresa. Genera un resumen matutino
breve (máx 2 frases) y accionable con estos datos de hoy:
- Reservas/citas hoy: $reservasHoy
- Pedidos nuevos: $pedidosHoy
- Facturas emitidas hoy: $facturasHoy
- Tareas abiertas: $tareasAbiertas
- Facturas pendientes de cobro: $facturasPendientes

Habla en primera persona del plural (nosotros), en español, tono profesional
y motivador. No repitas los números literalmente. Sugiere la prioridad del día.
''';

    return pregunta(
      prompt,
      sistemaPrompt:
          'Eres un asistente de negocio conciso y útil. Responde siempre en español, máximo 2 frases.',
      maxTokens: 150,
    );
  }
}

