import 'package:flutter/foundation.dart';
import 'package:planeag_flutter/domain/modelos/pdf_template.dart';
import 'package:planeag_flutter/services/pdf/pdf_block_builder.dart';
import 'package:planeag_flutter/services/pdf/blocks/header_block_builder.dart';
import 'package:planeag_flutter/services/pdf/blocks/table_block_builder.dart';
import 'package:planeag_flutter/services/pdf/blocks/totals_block_builder.dart';
import 'package:planeag_flutter/services/pdf/blocks/client_block_builder.dart';
import 'package:planeag_flutter/services/pdf/blocks/qr_block_builder.dart';
import 'package:planeag_flutter/services/pdf/blocks/text_block_builder.dart';
import 'package:planeag_flutter/services/pdf/blocks/stamp_block_builder.dart';

/// Registry de todos los builders de bloques disponibles
/// Patrón Registry + Factory
class PdfBlockRegistry {
  static final PdfBlockRegistry _instance = PdfBlockRegistry._();
  factory PdfBlockRegistry() => _instance;
  PdfBlockRegistry._();

  final Map<PdfBlockType, PdfBlockBuilder> _builders = {};

  /// Inicializa el registry con todos los builders del sistema
  void initialize() {
    if (_builders.isNotEmpty) return;

    register(HeaderBlockBuilder());
    register(TableBlockBuilder());
    register(TotalsBlockBuilder());
    register(ClientBlockBuilder());
    register(QrBlockBuilder());
    register(TextBlockBuilder());
    register(StampBlockBuilder());

    debugPrint('✅ PdfBlockRegistry inicializado con ${_builders.length} builders');
  }

  /// Registra un builder personalizado
  void register(PdfBlockBuilder builder) {
    _builders[builder.blockType] = builder;
    debugPrint('📦 Registrado builder: ${builder.blockType.name}');
  }

  /// Obtiene el builder para un tipo de bloque
  PdfBlockBuilder? getBuilder(PdfBlockType type) {
    return _builders[type];
  }

  /// Lista todos los tipos de bloque disponibles
  List<PdfBlockType> get availableBlockTypes => _builders.keys.toList();

  /// Verifica si un tipo específico está registrado
  bool isRegistered(PdfBlockType type) => _builders.containsKey(type);

  /// Limpia el registry (útil para testing)
  void clear() {
    _builders.clear();
  }
}