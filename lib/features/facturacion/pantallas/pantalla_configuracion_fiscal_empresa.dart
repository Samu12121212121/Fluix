import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/empresa_config_provider.dart';
import '../../../domain/modelos/empresa.dart';
import '../../../domain/modelos/empresa_config.dart';
import '../../../core/utils/validador_nif_cif.dart';
import '../../fiscal/pantallas/subir_certificado_verifactu_screen.dart';

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

  final _nifCtrl = TextEditingController();
  final _razonCtrl = TextEditingController();
  final _domicilioCtrl = TextEditingController();
  final _cpCtrl = TextEditingController();
  final _municipioCtrl = TextEditingController();
  final _provinciaCtrl = TextEditingController();
  final _epigrafCtrl = TextEditingController();
  String _regimenIva = 'general';
  bool _estaEnSii = false;
  CriterioIVA _criterioIva = CriterioIVA.devengo;

  @override
  void dispose() {
    _nifCtrl.dispose();
    _razonCtrl.dispose();
    _domicilioCtrl.dispose();
    _cpCtrl.dispose();
    _municipioCtrl.dispose();
    _provinciaCtrl.dispose();
    _epigrafCtrl.dispose();
    super.dispose();
  }

  void _cargarDesdeConfig(EmpresaConfig config) {
    if (_inicializado) return;
    _nifCtrl.text = config.nif;
    _razonCtrl.text = config.razonSocial;
    _domicilioCtrl.text = config.domicilioFiscal;
    _cpCtrl.text = config.codigoPostal;
    _municipioCtrl.text = config.municipio;
    _provinciaCtrl.text = config.provincia;
    _epigrafCtrl.text = config.epigrafIAE;
    _regimenIva = config.regimenIVA;
    _estaEnSii = config.estaEnSII;
    _criterioIva = config.criterioIva;
    _inicializado = true;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmpresaConfigProvider>();
    final color = Theme.of(context).colorScheme.primary;
    _cargarDesdeConfig(provider.config);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Configuración fiscal de la empresa'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
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
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubirCertificadoVerifactuScreen(
                          empresaId: provider.empresaId,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.verified_user, size: 18),
                    label: const Text('Certificado Verifactu (firma digital)'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: BorderSide(color: color.withValues(alpha: 0.4)),
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
    );
    try {
      await provider.guardar(nuevo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Configuración fiscal guardada'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
        );
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
}


