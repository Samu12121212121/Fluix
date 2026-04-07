import '../domain/modelos/factura.dart';
import '../domain/modelos/factura_recibida.dart';
import 'exportadores_aeat/mod_349_exporter.dart';

class Mod349Service {
  static final RegExp _regexVatBase = RegExp(r'^[A-Z]{2}[A-Z0-9]{2,12}$');

  List<Operador349> calcularOperadoresPeriodo(
    List<Factura> facturas,
    List<FacturaRecibida> recibidas,
    String periodo,
    int ejercicio,
  ) {
    final acumulado = <String, double>{};
    final meta = <String, _MetaOperador>{};

    for (final f in facturas) {
      if (f.estado == EstadoFactura.anulada) continue;
      if (!_enPeriodo(f.fechaEmision, periodo, ejercicio)) continue;

      final vat = _extraerVatCliente(f);
      if (vat == null) continue;
      if (!esVatIntracomunitarioValido(vat)) continue;

      final partes = _splitVat(vat);
      final clave = _claveDesdeCodigo(determinarClaveDesdeFactura(f));
      final key = '${partes.codigoPais}|${partes.numero}|${clave.codigo}';

      acumulado[key] = (acumulado[key] ?? 0) + f.subtotal;
      meta[key] = _MetaOperador(
        codigoPais: partes.codigoPais,
        numeroNif: partes.numero,
        razonSocial: f.datosFiscales?.razonSocial ?? f.clienteNombre,
        clave: clave,
      );
    }

    for (final r in recibidas) {
      if (r.estado == EstadoFacturaRecibida.rechazada) continue;
      if (!_enPeriodo(r.fechaRecepcion, periodo, ejercicio)) continue;

      final vat = _extraerVatProveedor(r);
      if (vat == null) continue;
      if (!esVatIntracomunitarioValido(vat)) continue;

      final partes = _splitVat(vat);
      final clave = _claveDesdeCodigo(determinarClaveDesdeFacturaRecibida(r));
      final key = '${partes.codigoPais}|${partes.numero}|${clave.codigo}';

      acumulado[key] = (acumulado[key] ?? 0) + r.baseImponible;
      meta[key] = _MetaOperador(
        codigoPais: partes.codigoPais,
        numeroNif: partes.numero,
        razonSocial: r.nombreProveedor,
        clave: clave,
      );
    }

    final out = <Operador349>[];
    for (final e in acumulado.entries) {
      final m = meta[e.key]!;
      out.add(
        Operador349(
          codigoPaisNif: m.codigoPais,
          numeroNif: m.numeroNif,
          razonSocial: m.razonSocial,
          claveOperacion: m.clave,
          baseImponible: e.value,
        ),
      );
    }

    out.sort((a, b) {
      final c = a.codigoPaisNif.compareTo(b.codigoPaisNif);
      if (c != 0) return c;
      final n = a.numeroNif.compareTo(b.numeroNif);
      if (n != 0) return n;
      return a.claveOperacion.codigo.compareTo(b.claveOperacion.codigo);
    });

    return out;
  }

  bool requierePresentacion(List<Operador349> operadores) => operadores.isNotEmpty;

  String inferirPeriodo(DateTime fecha) {
    if (fecha.month <= 3) return '1T';
    if (fecha.month <= 6) return '2T';
    if (fecha.month <= 9) return '3T';
    return '4T';
  }

  String determinarClaveDesdeFactura(Factura f) {
    if (f.tipo == TipoFactura.servicio) {
      return 'S';
    }
    return 'E';
  }

  String determinarClaveDesdeFacturaRecibida(FacturaRecibida r) {
    final texto = (r.notas ?? '').toLowerCase();
    if (texto.contains('servicio')) {
      return 'I';
    }
    return 'A';
  }

  ClaveOperacion349 _claveDesdeCodigo(String codigo) {
    return ClaveOperacion349.values.firstWhere(
      (e) => e.codigo == codigo,
      orElse: () => ClaveOperacion349.entregasExentas,
    );
  }

  bool esVatIntracomunitarioValido(String vat) {
    final limpio = vat.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (!_regexVatBase.hasMatch(limpio)) return false;

    final codigo = limpio.substring(0, 2);
    final numero = limpio.substring(2);
    final patron = _patronesPorPais[codigo];
    if (patron == null) return false;
    return patron.hasMatch(numero);
  }

  bool _enPeriodo(DateTime fecha, String periodo, int ejercicio) {
    if (fecha.year != ejercicio) return false;

    if (RegExp(r'^[0-9]{2}$').hasMatch(periodo)) {
      return fecha.month.toString().padLeft(2, '0') == periodo;
    }

    return inferirPeriodo(fecha) == periodo;
  }

  String? _extraerVatCliente(Factura f) {
    final dynamic datos = f.datosFiscales;
    if (datos == null) return null;

    final candidato = ((datos.nifIvaComunitario ?? datos.nif ?? '') as String).trim();
    if (candidato.isEmpty) return null;

    final limpio = candidato.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (!RegExp(r'^[A-Z]{2}').hasMatch(limpio)) return null;

    final esIntra = (datos.esIntracomunitario as bool?) ?? false;
    final pais = ((datos.pais ?? '') as String).trim().toUpperCase();
    if (esIntra || (pais.isNotEmpty && !pais.startsWith('ESP'))) {
      return limpio;
    }

    return null;
  }

  String? _extraerVatProveedor(FacturaRecibida r) {
    final dynamic recibida = r;
    final candidato =
        ((recibida.nifIvaComunitario ?? recibida.nifProveedor) as String).trim();
    if (candidato.isEmpty) return null;

    final limpio = candidato.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (!RegExp(r'^[A-Z]{2}').hasMatch(limpio)) return null;

    final esIntra = (recibida.esIntracomunitario as bool?) ?? false;
    if (esIntra || recibida.nifIvaComunitario != null) {
      return limpio;
    }

    return null;
  }

  ({String codigoPais, String numero}) _splitVat(String vat) {
    final limpio = vat.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return (codigoPais: limpio.substring(0, 2), numero: limpio.substring(2));
  }

  static final Map<String, RegExp> _patronesPorPais = {
    'AT': RegExp(r'^[A-Z0-9]{9}$'),
    'BE': RegExp(r'^[0-9]{10}$'),
    'BG': RegExp(r'^[0-9]{9,10}$'),
    'CY': RegExp(r'^[A-Z0-9]{9}$'),
    'HR': RegExp(r'^[0-9]{11}$'),
    'CZ': RegExp(r'^[0-9]{8,10}$'),
    'DE': RegExp(r'^[0-9]{9}$'),
    'DK': RegExp(r'^[0-9]{8}$'),
    'EE': RegExp(r'^[0-9]{9}$'),
    'EL': RegExp(r'^[0-9]{9}$'),
    'FI': RegExp(r'^[0-9]{8}$'),
    'FR': RegExp(r'^[A-Z0-9]{11}$'),
    'GB': RegExp(r'^([A-Z0-9]{5}|[A-Z0-9]{9}|[A-Z0-9]{12})$'),
    'HU': RegExp(r'^[0-9]{8}$'),
    'IE': RegExp(r'^[A-Z0-9]{8,9}$'),
    'IT': RegExp(r'^[0-9]{11}$'),
    'LT': RegExp(r'^[0-9]{9,12}$'),
    'LU': RegExp(r'^[0-9]{8}$'),
    'LV': RegExp(r'^[0-9]{11}$'),
    'MT': RegExp(r'^[0-9]{8}$'),
    'NL': RegExp(r'^[A-Z0-9]{12}$'),
    'PL': RegExp(r'^[0-9]{10}$'),
    'PT': RegExp(r'^[0-9]{9}$'),
    'RO': RegExp(r'^[0-9]{2,10}$'),
    'SE': RegExp(r'^[0-9]{12}$'),
    'SI': RegExp(r'^[0-9]{8}$'),
    'SK': RegExp(r'^[0-9]{10}$'),
    'XI': RegExp(r'^([A-Z0-9]{5}|[A-Z0-9]{9}|[A-Z0-9]{12})$'),
  };
}

class _MetaOperador {
  final String codigoPais;
  final String numeroNif;
  final String razonSocial;
  final ClaveOperacion349 clave;

  const _MetaOperador({
    required this.codigoPais,
    required this.numeroNif,
    required this.razonSocial,
    required this.clave,
  });
}



