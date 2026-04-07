import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/empresa_config.dart';

class EmpresaConfigService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<EmpresaConfig> obtenerConfig(String empresaId) async {
    final empresaRef = _db.collection('empresas').doc(empresaId);
    final fiscalRef = empresaRef.collection('configuracion').doc('fiscal');

    final results = await Future.wait([empresaRef.get(), fiscalRef.get()]);
    final empresaDoc = results[0];
    final fiscalDoc = results[1];

    return EmpresaConfig.fromSources(
      empresaDoc: empresaDoc.data(),
      fiscalDoc: fiscalDoc.data(),
    );
  }

  Future<void> guardarConfig(String empresaId, EmpresaConfig config) async {
    final errores = config.validar();
    if (errores.isNotEmpty) {
      throw Exception(errores.first);
    }

    final empresaRef = _db.collection('empresas').doc(empresaId);
    final fiscalRef = empresaRef.collection('configuracion').doc('fiscal');

    await empresaRef.set(config.toEmpresaDoc(), SetOptions(merge: true));
    await fiscalRef.set(config.toFiscalDoc(), SetOptions(merge: true));
  }
}

