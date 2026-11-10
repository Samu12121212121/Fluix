import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';
import '../../../core/providers/empresa_config_provider.dart';
import '../../../domain/modelos/empresa.dart';
import '../../../domain/modelos/empresa_config.dart';
import '../../../core/utils/validador_nif_cif.dart';
import '../../fiscal/pantallas/subir_certificado_verifactu_screen.dart';
import '../../../core/widgets/fluix_app_bar.dart';

class PantallaConfiguracionFiscalEmpresa extends StatefulWidget {
  const PantallaConfiguracionFiscalEmpresa({super.key});

  @override
  State<PantallaConfiguracionFiscalEmpresa> createState() =>
      _PantallaConfiguracionFiscalEmpresaState();
}

class _PantallaConfiguracionFiscalEmpresaState
    extends State<PantallaConfiguracionFiscalEmpresa> {
  final _formKey = GlobalKey<FormState>();
  bool _inicializado = false;
  bool _tieneCertificadoVf = false;

  final _nifCtrl = TextEditingController();
  final _razonCtrl = TextEditingController();
  final _domicilioCtrl = TextEditingController();
  final _cpCtrl = TextEditingController();
  final _municipioCtrl = TextEditingController();
  final _provinciaCtrl = TextEditingController();
  final _epigrafCtrl = TextEditingController();
  // Series de facturación configurables
  final _serieFacCtrl  = TextEditingController(text: 'F');
  final _serieRectCtrl = TextEditingController(text: 'R');
  final _serieProCtrl  = TextEditingController(text: 'P');
  // Seguridad Social
  final _cccCtrl  = TextEditingController();
  final _cnaeSSCtrl = TextEditingController();
  final _tipoAtCtrl = TextEditingController();
  String _regimenIva = 'general';
  bool _estaEnSii = false;
  CriterioIVA _criterioIva = CriterioIVA.devengo;
  FormaJuridica _formaJuridica = FormaJuridica.autonomo;

  @override
  void dispose() {
    _nifCtrl.dispose();
    _razonCtrl.dispose();
    _domicilioCtrl.dispose();
    _cpCtrl.dispose();
    _municipioCtrl.dispose();
    _provinciaCtrl.dispose();
    _epigrafCtrl.dispose();
    _serieFacCtrl.dispose();
    _serieRectCtrl.dispose();
    _serieProCtrl.dispose();
    _cccCtrl.dispose();
    _cnaeSSCtrl.dispose();
    _tipoAtCtrl.dispose();
    super.dispose();
  }

  void _cargarDesdeConfig(EmpresaConfig config, bool cargado, String empresaId) {
    if (_inicializado || !cargado) return;
    _nifCtrl.text = config.nif;
    _razonCtrl.text = config.razonSocial;
    _domicilioCtrl.text = config.domicilioFiscal;
    _cpCtrl.text = config.codigoPostal;
    _municipioCtrl.text = config.municipio;
    _provinciaCtrl.text = config.provincia;
    _epigrafCtrl.text = config.epigrafIAE;
    _serieFacCtrl.text  = config.serieFactura;
    _serieRectCtrl.text = config.serieRectificativa;
    _serieProCtrl.text  = config.serieProforma;
    _cccCtrl.text   = config.cccSeguridadSocial;
    _cnaeSSCtrl.text = config.cnaeSegSocial;
    _tipoAtCtrl.text = config.tipoAtSeguridadSocial?.toStringAsFixed(2) ?? '';
    _regimenIva = config.regimenIVA;
    _estaEnSii = config.estaEnSII;
    _criterioIva = config.criterioIva;
    _formaJuridica = config.formaJuridica;
    _inicializado = true;
    _verificarCertificadoVf(empresaId);
  }

  Future<void> _verificarCertificadoVf(String empresaId) async {
    if (empresaId.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('empresas').doc(empresaId)
        .collection('configuracion').doc('certificado_verifactu').get();
    if (mounted) setState(() => _tieneCertificadoVf = doc.exists);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmpresaConfigProvider>();
    final color = Theme.of(context).colorScheme.primary;
    _cargarDesdeConfig(provider.config, provider.cargado, provider.empresaId);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: const FluixAppBar(titulo: 'Configuración fiscal de la empresa', showLeading: true),
      body: provider.cargando
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildAviso(),
                  const SizedBox(height: 16),
                  _buildCard([
                    _campo(_nifCtrl, 'NIF *', hint: 'B12345678 / 12345678Z',
                        validator: (v) {
                      final error = EmpresaConfig(nif: v ?? '').errorNif;
                      if (error != null) return error;
                      final res = ValidadorNifCif.validar(v ?? '');
                      return res.valido ? null : res.razon;
                    }),
                    const SizedBox(height: 12),
                    _campo(_razonCtrl, 'Razón social *', validator: _obligatorio),
                    const SizedBox(height: 12),
                    _campo(_domicilioCtrl, 'Domicilio fiscal *', validator: _obligatorio),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _campo(_cpCtrl, 'Código postal *', validator: _obligatorio)),
                      const SizedBox(width: 12),
                      Expanded(child: _campo(_municipioCtrl, 'Municipio *', validator: _obligatorio)),
                    ]),
                    const SizedBox(height: 12),
                    _campo(_provinciaCtrl, 'Provincia *', validator: _obligatorio),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<FormaJuridica>(
                      initialValue: _formaJuridica,
                      decoration: _deco('Forma jurídica'),
                      items: FormaJuridica.values
                          .map((f) => DropdownMenuItem(
                                value: f,
                                child: Text(f.etiqueta),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _formaJuridica = v ?? FormaJuridica.autonomo),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _regimenIva,
                      decoration: _deco('Régimen IVA'),
                      items: const [
                        DropdownMenuItem(value: 'general', child: Text('General')),
                        DropdownMenuItem(value: 'simplificado', child: Text('Simplificado')),
                        DropdownMenuItem(value: 'recc', child: Text('RECC (criterio de caja)')),
                      ],
                      onChanged: (v) => setState(() => _regimenIva = v ?? 'general'),
                    ),
                    const SizedBox(height: 12),
                    _campo(_epigrafCtrl, 'Epígrafe IAE'),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _estaEnSii,
                      onChanged: (v) => setState(() => _estaEnSii = v),
                      title: const Text('Empresa obligada a SII'),
                      subtitle: const Text('Actívalo si tu empresa presenta SII a la AEAT'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<CriterioIVA>(
                      initialValue: _criterioIva,
                      decoration: _deco('Criterio de IVA'),
                      items: const [
                        DropdownMenuItem(value: CriterioIVA.devengo, child: Text('Devengo')),
                        DropdownMenuItem(value: CriterioIVA.caja, child: Text('Caja (RECC)')),
                      ],
                      onChanged: (v) => setState(() => _criterioIva = v ?? CriterioIVA.devengo),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'El criterio de caja solo es aplicable si tu empresa está acogida al RECC. Consulta con tu gestor antes de activarlo.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  // ── Certificado Verifactu ──
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SubirCertificadoVerifactuScreen(
                            empresaId: provider.empresaId,
                          ),
                        ),
                      );
                      // Recargar estado al volver
                      _verificarCertificadoVf(provider.empresaId);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: (_tieneCertificadoVf
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B)).withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (_tieneCertificadoVf
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B)).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          _tieneCertificadoVf ? Icons.verified_rounded : Icons.warning_amber_rounded,
                          color: _tieneCertificadoVf ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            'Certificado Verifactu',
                            style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13.5,
                              color: _tieneCertificadoVf ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            ),
                          ),
                          Text(
                            _tieneCertificadoVf
                                ? 'Configurado · Toca para gestionar'
                                : 'Sin certificado · Toca para configurar',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: (_tieneCertificadoVf
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B)).withValues(alpha: 0.8),
                            ),
                          ),
                        ])),
                        Icon(Icons.chevron_right_rounded,
                            color: _tieneCertificadoVf
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                            size: 18),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: provider.guardando ? null : () => _guardar(provider),
                    icon: provider.guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save),
                    label: Text(provider.guardando ? 'Guardando...' : 'Guardar configuración fiscal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Sección series de facturación ──────────────────────────────────────
                  _buildCardSeries(),
                  const SizedBox(height: 16),
                  // ── Sección Seguridad Social ───────────────────────────────────────────
                  _buildCardSS(),
                ],
              ),
            ),
    );
  }

  Future<void> _guardar(EmpresaConfigProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    final nuevo = EmpresaConfig(
      nif: _nifCtrl.text,
      razonSocial: _razonCtrl.text,
      domicilioFiscal: _domicilioCtrl.text,
      codigoPostal: _cpCtrl.text,
      municipio: _municipioCtrl.text,
      provincia: _provinciaCtrl.text,
      regimenIVA: _regimenIva,
      epigrafIAE: _epigrafCtrl.text,
      estaEnSII: _estaEnSii,
      criterioIva: _criterioIva,
      formaJuridica: _formaJuridica,
      serieFactura: _serieFacCtrl.text.trim().toUpperCase().isNotEmpty
          ? _serieFacCtrl.text.trim().toUpperCase() : 'F',
      serieRectificativa: _serieRectCtrl.text.trim().toUpperCase().isNotEmpty
          ? _serieRectCtrl.text.trim().toUpperCase() : 'R',
      serieProforma: _serieProCtrl.text.trim().toUpperCase().isNotEmpty
          ? _serieProCtrl.text.trim().toUpperCase() : 'P',
      cccSeguridadSocial: _cccCtrl.text.trim(),
      cnaeSegSocial: _cnaeSSCtrl.text.trim(),
      tipoAtSeguridadSocial: double.tryParse(_tipoAtCtrl.text.trim()),
    );
    try {
      await provider.guardar(nuevo);
      if (mounted) {
        FluxToast.exito(context, 'Configuración fiscal guardada');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        FluxToast.error(context, '$e');
      }
    }
  }

  Widget _buildAviso() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Estos datos se usarán para generar el Modelo 303, Modelo 347, PDFs fiscales y servicios AEAT. Revisa con tu asesor que sean correctos.',
          style: TextStyle(fontSize: 12, color: Colors.blue),
        ),
      );

  Widget _buildCard(List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
          ],
        ),
        child: Column(children: children),
      );

  Widget _campo(TextEditingController ctrl, String label,
      {String? hint, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
      decoration: _deco(label, hint: hint),
    );
  }

  InputDecoration _deco(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );

  String? _obligatorio(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

  // ── Sección series de facturación ──────────────────────────────────────
  Widget _buildCardSeries() => _buildCard([
    const Text(
      '📋 Prefijos de serie (máx. 5 caracteres)',
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
    ),
    const SizedBox(height: 4),
    const Text(
      'El número de factura se generará como: PREFIJO-AÑO-NNNN\n'
      'Ej: F-2026-0001 · R-2026-0001 · P-2026-0001',
      style: TextStyle(fontSize: 12, color: Colors.grey),
    ),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: _campo(_serieFacCtrl, 'Facturas', hint: 'F',
          validator: _validarSerie)),
      const SizedBox(width: 10),
      Expanded(child: _campo(_serieRectCtrl, 'Rectificativas', hint: 'R',
          validator: _validarSerie)),
      const SizedBox(width: 10),
      Expanded(child: _campo(_serieProCtrl, 'Proformas', hint: 'P',
          validator: _validarSerie)),
    ]),
  ]);

  String? _validarSerie(String? v) {
    if (v == null || v.trim().isEmpty) return 'Obligatorio';
    if (v.trim().length > 5) return 'Máx. 5 car.';
    if (!RegExp(r'^[A-Za-z0-9\-]+$').hasMatch(v.trim())) return 'Solo letras/números';
    return null;
  }

  // ── Sección Seguridad Social ───────────────────────────────────────────────
  Widget _buildCardSS() => _buildCard([
    const Text(
      '🏥 Seguridad Social (nóminas)',
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
    ),
    const SizedBox(height: 4),
    const Text(
      'Estos datos se usan para las nóminas y el PDF del recibo de salario.',
      style: TextStyle(fontSize: 12, color: Colors.grey),
    ),
    const SizedBox(height: 12),
    _campo(_cccCtrl, 'CCC — Código Cuenta Cotización',
        hint: 'Ej: 282345678901', validator: _validarCCC),
    const SizedBox(height: 8),
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'El CCC aparece en el encabezado del recibo de nómina. Tiene 12 dígitos: 2 provincia + 8 empresa + 2 dígitos de control.',
        style: TextStyle(fontSize: 11, color: Colors.blue),
      ),
    ),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: _campo(_cnaeSSCtrl, 'CNAE en TGSS', hint: 'Ej: 869')),
      const SizedBox(width: 10),
      Expanded(child: _campo(_tipoAtCtrl, 'Tipo AT/EP (%)', hint: 'Ej: 1.75')),
    ]),
    const SizedBox(height: 8),
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'El tipo AT/EP se aplica a todas las nóminas de la empresa salvo que el empleado tenga un tipo personalizado. Consúltalo en la tarifa de primas AT/EP (RDL 3/2026 DF1.3).',
        style: TextStyle(fontSize: 11, color: Colors.orange),
      ),
    ),
  ]);

  String? _validarCCC(String? v) {
    if (v == null || v.trim().isEmpty) return null; // Opcional
    final clean = v.trim().replaceAll(RegExp(r'[\s\-/]'), '');
    if (!RegExp(r'^\d{12}$').hasMatch(clean)) return 'El CCC debe tener 12 dígitos numéricos';
    return null;
  }
}

