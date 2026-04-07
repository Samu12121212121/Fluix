# 🧹 ARCHIVOS A ELIMINAR MANUALMENTE

Estos archivos son obsoletos y causan errores. Elimínalos manualmente:

1. `lib/features/dashboard/widgets/dialogs_contenido_web.dart`
2. `lib/features/dashboard/widgets/modulo_contenido_web.dart` 
3. `lib/features/dashboard/widgets/modulo_contenido_web_simplificado.dart`

Estos archivos usan el enum `TipoSeccionWeb` que ya no existe y han sido reemplazados por el sistema de widgets modulares.

## Estado después de eliminar:

✅ **Sistema de widgets modulares** funcionando
✅ **Widget Contenido Web** integrado en el dashboard modular
✅ **Sin dependencias obsoletas**
✅ **Sin conflictos de enum**
