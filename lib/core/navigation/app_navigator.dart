import 'package:flutter/material.dart';

/// Navigator key global para navegación imperativa desde cualquier punto
/// de la app sin necesidad de BuildContext ni callbacks intermedios.
///
/// Uso: AppNavigator.irALogin() para cerrar sesión y limpiar el stack.
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static void irALogin() {
    key.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
  }
}
