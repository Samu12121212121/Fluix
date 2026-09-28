import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'impresora_bluetooth_service.dart';
import 'impresora_windows_service.dart';
import '../../domain/modelos/configuracion_facturacion_tpv.dart';

/// Servicio unificado de impresión que funciona en todas las plataformas:
/// - Android/iOS: Usa Bluetooth térmico
/// - Windows/Mac/Linux/Web: Usa sistema de impresión del OS
class ImpresoraService {
  static final ImpresoraService _instance = ImpresoraService._();
  factory ImpresoraService() => _instance;
  ImpresoraService._();

  final ImpressoraBluetooth _btService = ImpressoraBluetooth();
  final ImpresoraWindowsService _winService = ImpresoraWindowsService();

  bool get esDesktop => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  bool get esMovil => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Imprimir PDF usando el método apropiado según la plataforma
  Future<void> imprimirPdf(Uint8List pdfBytes, {String? nombreArchivo}) async {
    if (esDesktop || kIsWeb) {
      // En desktop/web: usar impresoras del sistema
      await _imprimirDesktop(pdfBytes, nombreArchivo: nombreArchivo);
    } else {
      // En móvil: Bluetooth si hay impresora conectada, si no sistema
      try {
        final conectada = await _btService.estaConectada();
        if (conectada) {
          await _btService.imprimirPdfComoTicket(pdfBytes);
        } else {
          await _imprimirDesktop(pdfBytes, nombreArchivo: nombreArchivo);
        }
      } catch (_) {
        await _imprimirDesktop(pdfBytes, nombreArchivo: nombreArchivo);
      }
    }
  }

  /// Imprimir usando impresoras del sistema operativo
  Future<void> _imprimirDesktop(Uint8List pdfBytes, {String? nombreArchivo}) async {
    await Printing.layoutPdf(
      onLayout: (_) => pdfBytes,
      name: nombreArchivo ?? 'documento',
      format: PdfPageFormat.a4,
    );
  }

  /// Obtener lista de impresoras disponibles
  Future<List<Printer>> obtenerImpresorasDisponibles() async {
    if (esDesktop || kIsWeb) {
      return await Printing.listPrinters();
    } else {
      // En móvil retornar lista vacía (usa Bluetooth)
      return [];
    }
  }

  /// Imprimir directamente en una impresora específica sin diálogo
  Future<void> imprimirDirecto({
    required Uint8List pdfBytes,
    required Printer impresora,
  }) async {
    if (esDesktop || kIsWeb) {
      await Printing.directPrintPdf(
        printer: impresora,
        onLayout: (_) => pdfBytes,
      );
    }
  }

  /// Guardar impresora por defecto
  Future<void> guardarImpresoraPorDefecto(String nombreImpresora) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('impresora_defecto_desktop', nombreImpresora);
  }

  /// Obtener impresora por defecto guardada
  Future<String?> obtenerImpresoraPorDefecto() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('impresora_defecto_desktop');
  }

  /// Verificar si hay impresora configurada (Bluetooth o Desktop)
  Future<bool> hayImpresoraConfigurada() async {
    if (esMovil) {
      return await _btService.estaConectada();
    } else {
      final defecto = await obtenerImpresoraPorDefecto();
      return defecto != null;
    }
  }

  /// Configurar impresora (abre diálogo según plataforma)
  Future<bool> configurarImpresora() async {
    if (esMovil) {
      // En móvil: buscar impresoras Bluetooth
      try {
        final impresoras = await _btService.escanearImpresoras();
        if (impresoras.isEmpty) {
          throw Exception('No se encontraron impresoras Bluetooth vinculadas');
        }
        // Retornar true si hay impresoras disponibles
        // La UI debe manejar la selección
        return impresoras.isNotEmpty;
      } catch (e) {
        debugPrint('Error al buscar impresoras Bluetooth: $e');
        return false;
      }
    } else {
      // En desktop: listar impresoras del sistema
      try {
        final impresoras = await obtenerImpresorasDisponibles();
        return impresoras.isNotEmpty;
      } catch (e) {
        debugPrint('Error al listar impresoras: $e');
        return false;
      }
    }
  }

  /// Abrir cajón respetando la configuración del tenant.
  ///
  /// [metodoPago] debe ser 'efectivo', 'tarjeta', etc.
  /// Solo abre si la config del tenant lo permite para ese método de pago.
  Future<void> abrirCajonSiProcede({
    required ConfiguracionFacturacionTpv config,
    required String metodoPago,
  }) async {
    if (!config.abrirCajonAlCobrar) return;
    if (config.abrirCajonSoloEfectivo && metodoPago != 'efectivo') return;

    try {
      if (esMovil) {
        await _btService.abrirCajon(pin: config.drawerPin);
      } else if (esDesktop) {
        await _winService.abrirCajon(pin: config.drawerPin);
      }
    } catch (e) {
      debugPrint('⚠️ No se pudo abrir el cajón: $e');
      // No propagar — el cajón es opcional, no debe bloquear el cobro
    }
  }

  /// Imprimir ticket ESC/POS por Bluetooth (móvil).
  /// En desktop imprime como PDF por el sistema.
  Future<void> imprimirTicket(TicketData ticket) async {
    if (esMovil) {
      try {
        final conectada = await _btService.estaConectada();
        if (conectada) {
          await _btService.imprimirTicket(ticket);
          return;
        }
      } catch (_) {}
    }
    // Fallback: imprimir como PDF
    final pdfBytes = await _ticketComoPdf(ticket);
    await imprimirPdf(pdfBytes, nombreArchivo: 'ticket_${ticket.numeroTicket}');
  }

  /// Genera un PDF minimalista de ticket para el fallback desktop.
  Future<Uint8List> _ticketComoPdf(TicketData ticket) async {
    // Reutiliza el layout del servicio de impresión desktop
    return await Printing.convertHtml(
      format: PdfPageFormat.roll80,
      html: _ticketHtml(ticket),
    );
  }

  String _ticketHtml(TicketData ticket) {
    final lineas = ticket.lineas.map((l) =>
        '<tr><td>${l.nombre}</td><td>${l.cantidad}x</td>'
        '<td style="text-align:right">${l.subtotal.toStringAsFixed(2)}€</td></tr>'
    ).join();
    return '''<!DOCTYPE html><html><body style="font-family:monospace;font-size:11px;width:72mm">
<h3 style="text-align:center">${ticket.nombreEmpresa}</h3>
<p style="text-align:center">Ticket #${ticket.numeroTicket}<br>${ticket.fecha.toString().substring(0, 16)}</p>
<hr><table width="100%">$lineas</table><hr>
<p style="font-size:14px;font-weight:bold;text-align:right">TOTAL: ${ticket.total.toStringAsFixed(2)}€</p>
<p>Pago: ${ticket.metodoPago}</p>
<p style="text-align:center">¡Gracias por su compra!</p>
</body></html>''';
  }

  /// Imprimir con configuración automática (usa impresora por defecto si está configurada)
  Future<void> imprimirAutomatico(Uint8List pdfBytes, {String? nombreArchivo}) async {
    if (esDesktop) {
      final nombreDefecto = await obtenerImpresoraPorDefecto();
      if (nombreDefecto != null) {
        final impresoras = await obtenerImpresorasDisponibles();
        final impresora = impresoras.where((p) => p.name == nombreDefecto).firstOrNull;
        if (impresora != null) {
          await imprimirDirecto(pdfBytes: pdfBytes, impresora: impresora);
          return;
        }
      }
    }

    // Si no hay impresora por defecto o falla, mostrar diálogo
    await imprimirPdf(pdfBytes, nombreArchivo: nombreArchivo);
  }
}


