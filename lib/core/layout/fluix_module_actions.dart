import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FluixModuleActions — sistema de acciones e historial contextual del AppBar
//
// Los módulos llaman a FluixModuleActionsNotifier para inyectar su breadcrumb
// y sus botones específicos sin acoplarse al dashboard padre.
//
// Uso en un módulo:
//   context.read<FluixModuleActionsNotifier>().update(
//     breadcrumb: [
//       FluixBreadcrumbItem('Inicio', onTap: () => Navigator.popUntil(ctx, (r) => r.isFirst)),
//       FluixBreadcrumbItem('Facturación'),
//       FluixBreadcrumbItem('Modelos'),
//     ],
//     actions: [IconButton(icon: Icon(Icons.add), onPressed: _nuevaFactura)],
//   );
// ─────────────────────────────────────────────────────────────────────────────

class FluixBreadcrumbItem {
  final String label;
  final VoidCallback? onTap;
  const FluixBreadcrumbItem(this.label, {this.onTap});
}

class FluixModuleActionsNotifier extends ChangeNotifier {
  List<FluixBreadcrumbItem> _breadcrumb = const [FluixBreadcrumbItem('Inicio')];
  List<Widget> _actions = const [];

  List<FluixBreadcrumbItem> get breadcrumb => List.unmodifiable(_breadcrumb);
  List<Widget> get actions => List.unmodifiable(_actions);

  void update({List<FluixBreadcrumbItem>? breadcrumb, List<Widget>? actions}) {
    var changed = false;
    if (breadcrumb != null) { _breadcrumb = breadcrumb; changed = true; }
    if (actions != null) { _actions = actions; changed = true; }
    if (changed) notifyListeners();
  }

  void setActions(List<Widget> actions) {
    _actions = actions;
    notifyListeners();
  }

  void reset() {
    _breadcrumb = const [FluixBreadcrumbItem('Inicio')];
    _actions = const [];
    notifyListeners();
  }
}

// Extensión de conveniencia
extension FluixModuleActionsContext on BuildContext {
  FluixModuleActionsNotifier get moduleActions =>
      read<FluixModuleActionsNotifier>();
}
