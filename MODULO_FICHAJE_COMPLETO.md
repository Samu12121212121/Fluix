# ⏱️ Módulo de Fichaje — Documentación Completa

> **Fecha:** Mayo 2026  
> **Estado Legal:** Obligatorio en España desde el **12 de mayo de 2019** (RDL 8/2019).  
> Próximamente más exigente con la nueva normativa europea de registro horario digital.  
> **Relevancia:** Pilar fundamental de PlaneaG para negocios con empleados en nómina.

---

##  Marco legal (España 2026)

| Norma | Obligación |
|---|---|
| RDL 8/2019 | Registro diario de jornada obligatorio para todos los trabajadores |
| Convenios colectivos | Pueden ampliar los requisitos mínimos |
| Directiva UE 2003/88 | Registro del tiempo de trabajo — transpuesta en España |
| Nueva normativa prevista | Registro digital con firma electrónica, trazabilidad, 4 años de conservación |

**Lo que la ley exige:**
- ✅ Hora de entrada y salida diaria
- ✅ Conservar registros **4 años**
- ✅ Accesible para empleados, Inspección de Trabajo y sindicatos
- ✅ No manipulable (integridad del registro)
- ❌ No hay formato obligatorio aún (papel, app, biométrico… todo vale)

**Sanciones por incumplimiento:**
- Infracción grave: 750€ – 7.500€ por empresa
- Reincidencia: hasta 187.515€

---

## ️ Arquitectura del módulo en PlaneaG

```
┌─────────────────────────────────────────────────┐
│  EMPLEADO (app móvil)                           │
│  ┌─────────┐  ┌─────────┐  ┌────────────────┐  │
│  │ Entrada │  │ Salida  │  │ Mis fichajes   │  │
│  │  GPS    │  │  GPS    │  │ (historial)    │  │
│  └────┬────┘  └────┬────┘  └────────────────┘  │
│       │            │                            │
└───────┼────────────┼────────────────────────────┘
        │            │
        ▼            ▼
   Firestore: empresas/{id}/fichajes/{id}
        │
        ▼
┌──────────────────────────────────────────────────┐
│  ADMINISTRADOR/GERENTE (dashboard)               │
│  ┌─────────────┐  ┌──────────────┐  ┌────────┐  │
│  │ Vista hoy   │  │ Vista semana │  │ Export │  │
│  │ todos emp.  │  │ calendario   │  │  CSV   │  │
│  └─────────────┘  └──────────────┘  └────────┘  │
│  ┌─────────────┐  ┌──────────────┐               │
│  │ Editar      │  │ Alertas      │               │
│  │ (con badge) │  │ >9h sin sal. │               │
│  └─────────────┘  └──────────────┘               │
└──────────────────────────────────────────────────┘
```

---

## ️ Estructura Firestore

### Colección: `empresas/{empresaId}/fichajes/{fichajeId}`

```json
{
  "empleado_id": "uid_empleado",
  "empresa_id": "uid_empresa",
  "empleado_nombre": "María García",
  "tipo": "entrada",
  "timestamp": "2026-05-20T09:00:00Z",
  "latitud": 40.4165,
  "longitud": -3.70256,
  "editado_por_admin": false,
  "notas": "Llegada tarde por incidencia metro"
}
```

**Tipos de fichaje:**
| Valor `tipo` | Significado |
|---|---|
| `entrada` | Inicio de jornada |
| `salida` | Fin de jornada |
| `pausa_inicio` | Inicio de pausa (descanso, comida) |
| `pausa_fin` | Fin de pausa |

---

##  Pantallas implementadas

### 1. `PantallaFichaje` — Empleado

**Ruta:** `lib/features/fichaje/pantalla_fichaje/pantalla_fichaje.dart`

**Componentes:**

```
┌───────────────────────────────┐
│  Martes, 20 de mayo           │
│  ┌─────────────────────────┐  │
│  │      09:23              │  │  ← Reloj en tiempo real (Timer)
│  │  Último: Entrada 09:00  │  │  ← Badge degradado azul
│  └─────────────────────────┘  │
│                               │
│  ┌─────────────────────────┐  │
│  │   Fichar Entrada      │  │  ← Verde, deshabilitado si ya hay entrada
│  └─────────────────────────┘  │
│                               │
│  ┌─────────────────────────┐  │
│  │   Fichar Salida       │  │  ← Azul, deshabilitado si no hay entrada
│  └─────────────────────────┘  │
│                               │
│  Fichajes de hoy              │
│  ┌─────────────────────────┐  │
│  │  Entrada  09:00     │  │
│  │ ────────────────────    │  │
│  │  Salida   14:30       │  │
│  └─────────────────────────┘  │
└───────────────────────────────┘
```

**Lógica de estado:**
```dart
// Botón entrada deshabilitado si:
//   - Ya hay una entrada activa hoy (último fichaje = 'entrada')
// Botón salida deshabilitado si:
//   - No hay ningún fichaje hoy
//   - El último fichaje ya es 'salida'
```

**GPS:** Captura ubicación opcional (timeout 5s). Si el permiso está denegado, ficha igualmente sin coordenadas.

---

### 2. Vista Admin — Fichajes de hoy (todos los empleados)

**Funcionalidad:**
- Stream en tiempo real de todos los fichajes del día
- Muestra qué empleados están dentro/fuera
- Badge "Editado" en fichajes modificados por admin

---

##  Servicio: `FichajeService`

**Ruta:** `lib/services/fichaje_service.dart`

### Métodos disponibles

| Método | Descripción |
|---|---|
| `ficharEntrada(...)` | Crea registro entrada. Valida doble entrada |
| `ficharSalida(...)` | Crea registro salida |
| `ultimoFichajeHoy(empresaId, uid)` | Stream del último fichaje hoy (saber si está dentro) |
| `fichajesDelDia(empresaId, uid, fecha)` | Stream de todos los fichajes de un día |
| `fichajesHoyTodos(empresaId)` | Stream de todos los empleados hoy (admin) |
| `calcularHorasDia(fichajes)` | Calcula horas trabajadas en base a pares entrada/salida |
| `editarFichaje(empresaId, id, nuevoTimestamp)` | Admin edita hora, marca `editado_por_admin: true` |
| `eliminarFichaje(empresaId, id)` | Admin elimina fichaje |
| `resumenSemanal(empresaId, uid, semana)` | Devuelve `List<ResumenDiaFichaje>` de lun-dom |
| `exportarCsv(empresaId, desde, hasta)` | Genera CSV como String |
| `fichajesPendientesAlerta(empresaId)` | Entradas sin salida tras 9h (alertas) |

---

##  Mejoras pendientes a implementar

###  Crítico (obligatorio por ley)

#### 1. Conservación 4 años
El índice actual solo consulta hacia atrás 90 días en algunas partes. Revisar que **ningún fichaje se borra automáticamente** y que el admin no pueda borrar sin dejar huella.

```dart
// En lugar de eliminar, marcar como "eliminado":
Future<void> eliminarFichaje(String empresaId, String fichajeId) async {
  await _fichajes(empresaId).doc(fichajeId).update({
    'eliminado': true,
    'eliminado_por': FirebaseAuth.instance.currentUser?.uid,
    'eliminado_en': FieldValue.serverTimestamp(),
  });
}
```

#### 2. Exportación para Inspección de Trabajo

Formato recomendado para el CSV de exportación:

```
Empresa: Peluquería Mónica S.L. | CIF: B12345678
Período: 01/05/2026 - 31/05/2026

Empleado,DNI,Fecha,Día,Hora Entrada,Hora Salida,Horas Totales,Horas Extra,Editado,Notas
María García,12345678A,01/05/2026,Lunes,09:00,17:30,8h 30m,0h 30m,No,
Juan Pérez,87654321B,01/05/2026,Lunes,10:00,19:00,9h 0m,1h 0m,Sí,Ajustado por error
```

#### 3. Firma digital del empleado (próxima normativa)

```dart
// Futuro: al fichar, el empleado firma con su PIN/biométrico
// Esto se puede implementar con local_auth package
import 'package:local_auth/local_auth.dart';

Future<bool> verificarIdentidadBiometrica() async {
  final auth = LocalAuthentication();
  return auth.authenticate(
    localizedReason: 'Confirma tu identidad para fichar',
    options: const AuthenticationOptions(biometricOnly: false),
  );
}
```

---

###  Importante (mejora de UX)

#### 4. Pausas (descanso/comida)

Añadir dos nuevos botones: **Pausa** y **Volver de pausa**. Las pausas descontarían del tiempo total si así lo configura el convenio.

```dart
// Nuevos tipos en TipoFichaje:
enum TipoFichaje { entrada, salida, pausaInicio, pausaFin }

// En calcularHorasDia, descontar las pausas:
double calcularHorasDia(List<RegistroFichaje> fichajes) {
  double minutosTrabajados = 0;
  double minutosPausa = 0;
  RegistroFichaje? entradaActual;
  RegistroFichaje? pausaActual;

  for (final f in fichajes) {
    switch (f.tipo) {
      case TipoFichaje.entrada:
        entradaActual = f;
      case TipoFichaje.pausaInicio:
        pausaActual = f;
      case TipoFichaje.pausaFin:
        if (pausaActual != null) {
          minutosPausa += f.timestamp.difference(pausaActual.timestamp).inMinutes;
          pausaActual = null;
        }
      case TipoFichaje.salida:
        if (entradaActual != null) {
          minutosTrabajados += f.timestamp.difference(entradaActual.timestamp).inMinutes;
          entradaActual = null;
        }
    }
  }
  return (minutosTrabajados - minutosPausa) / 60.0;
}
```

#### 5. Vista calendario del empleado

Mostrar un calendario mensual con colores:
-  Verde: Día completo (entrada + salida)
-  Amarillo: Solo entrada (fichaje pendiente)
- ⚫ Gris: Festivo/fin de semana
-  Rojo: Ausencia sin justificar

#### 6. Notificación si el empleado olvida fichar salida

```typescript
// Cloud Function: cron cada día a las 22:00
export const recordatorioFichajePendiente = functions.pubsub
  .schedule('0 22 * * *')
  .timeZone('Europe/Madrid')
  .onRun(async () => {
    const ahora = admin.firestore.Timestamp.now();
    const inicioHoy = new Date();
    inicioHoy.setHours(0, 0, 0, 0);

    // Buscar entradas sin salida después de las 21:00
    const entradas = await admin.firestore()
      .collectionGroup('fichajes')
      .where('tipo', '==', 'entrada')
      .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(inicioHoy))
      .get();

    for (const entrada of entradas.docs) {
      const empleadoId = entrada.data().empleado_id;
      const empresaId = entrada.data().empresa_id;

      // Verificar si existe salida
      const salidas = await admin.firestore()
        .collection('empresas').doc(empresaId).collection('fichajes')
        .where('empleado_id', '==', empleadoId)
        .where('tipo', '==', 'salida')
        .where('timestamp', '>', entrada.data().timestamp)
        .limit(1).get();

      if (salidas.empty) {
        // Enviar push al empleado
        const usuario = await admin.firestore()
          .collection('usuarios').doc(empleadoId).get();
        const token = usuario.data()?.fcm_token;
        if (token) {
          await admin.messaging().send({
            token,
            notification: {
              title: '⚠️ Fichaje pendiente',
              body: 'No has fichado la salida de hoy. ¿Seguís trabajando?',
            },
          });
        }
      }
    }
  });
```

---

###  Avanzado (diferenciador de mercado)

#### 7. Geovalla (Geofencing)

Solo permitir fichar si el empleado está dentro de un radio configurable del negocio:

```dart
Future<bool> dentroDelNegocio({
  required double latNegocio,
  required double lonNegocio,
  required double latEmpleado,
  required double lonEmpleado,
  double radioMetros = 200,
}) async {
  final distancia = Geolocator.distanceBetween(
    latNegocio, lonNegocio, latEmpleado, lonEmpleado,
  );
  return distancia <= radioMetros;
}
```

**Configuración en Firestore:**
```json
// empresas/{id}
{
  "fichaje_geofencing": true,
  "fichaje_radio_metros": 200,
  "latitud": 40.4165,
  "longitud": -3.7026
}
```

#### 8. QR de fichaje (para negocios sin smartphone propio)

El negocio muestra un QR en la pared. El empleado lo escanea con su teléfono y ficha automáticamente.

```dart
// Generar QR con datos:
// {"accion": "fichar", "empresa_id": "abc", "timestamp_valido_hasta": 1234567890}
// El timestamp_valido_hasta expira en 30 segundos para evitar uso posterior

// Al escanear:
void procesarQrFichaje(String qrData) {
  final data = jsonDecode(qrData);
  final expira = DateTime.fromMillisecondsSinceEpoch(data['timestamp_valido_hasta'] * 1000);
  if (DateTime.now().isAfter(expira)) {
    // QR expirado — mostrar error
    return;
  }
  // Fichar con los datos del QR
}
```

#### 9. Integración con nóminas

Cuando se genera la nómina mensual, rellenar automáticamente las horas trabajadas:

```dart
// En el módulo de nóminas, consultar fichajes del mes:
Future<double> horasTrabajadasMes({
  required String empresaId,
  required String empleadoId,
  required int anio,
  required int mes,
}) async {
  final inicio = DateTime(anio, mes, 1);
  final fin = DateTime(anio, mes + 1, 1);

  final snap = await FirebaseFirestore.instance
    .collection('empresas').doc(empresaId).collection('fichajes')
    .where('empleado_id', isEqualTo: empleadoId)
    .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
    .where('timestamp', isLessThan: Timestamp.fromDate(fin))
    .orderBy('timestamp')
    .get();

  final fichajes = snap.docs
    .map((d) => RegistroFichaje.fromMap(d.data(), d.id))
    .toList();

  return FichajeService().calcularHorasDia(fichajes);
}
```

---

##  Índices Firestore necesarios

Ya están en `firestore.indexes.json`:

```json
// ✅ Ya existe:
{ "collectionGroup": "fichajes", "fields": [
  { "fieldPath": "empleado_id", "order": "ASCENDING" },
  { "fieldPath": "timestamp", "order": "DESCENDING" }
]}

// ✅ Ya existe:
{ "collectionGroup": "fichajes", "fields": [
  { "fieldPath": "empleado_id", "order": "ASCENDING" },
  { "fieldPath": "timestamp", "order": "ASCENDING" }
]}

// ❌ Falta (para alertas y Cloud Functions):
{ "collectionGroup": "fichajes", "fields": [
  { "fieldPath": "empresa_id", "order": "ASCENDING" },
  { "fieldPath": "tipo", "order": "ASCENDING" },
  { "fieldPath": "timestamp", "order": "DESCENDING" }
]}
```

---

## ✅ Checklist de implementación

### Obligatorio (cumplimiento legal)
- [x] Fichar entrada con timestamp
- [x] Fichar salida con timestamp
- [x] GPS opcional en cada fichaje
- [x] Historial del día para el empleado
- [x] Vista admin de todos los empleados
- [x] Edición por admin (con marca `editado_por_admin`)
- [x] Exportación CSV básica
- [ ] **Exportación CSV formato Inspección de Trabajo** (con DNI, empresa, período)
- [ ] **Soft-delete** en lugar de borrado real (obligatorio 4 años)
- [ ] **Firma biométrica/PIN** al fichar (próxima normativa)

### Mejora UX (próximo sprint)
- [ ] Pausas (descanso/comida) con descuento en tiempo
- [ ] Vista calendario mensual del empleado
- [ ] Notificación olvidar fichar salida (Cloud Function cron)
- [ ] Resumen semanal en la pantalla del empleado

### Avanzado (diferenciador)
- [ ] Geofencing — solo fichar cerca del negocio
- [ ] QR de fichaje para negocios sin smartphone
- [ ] Integración automática horas → nómina
- [ ] Informe de horas extra automático
- [ ] Dashboard de presencia en tiempo real (admin ve quién está en el local)

---

##  Archivos del módulo

```
lib/features/fichaje/
  └── pantalla_fichaje/
      └── pantalla_fichaje.dart     ← UI empleado (Entrada/Salida/Historial)

lib/services/
  └── fichaje_service.dart          ← Toda la lógica de negocio

lib/domain/modelos/
  └── fichaje.dart                  ← RegistroFichaje, ResumenDiaFichaje, TipoFichaje

firestore.indexes.json              ← Índices fichajes

functions/src/ (pendiente)
  ├── recordatorioFichajeIncompleto.ts  ← Cron 22:00 push reminder
  └── generarInformeMensual.ts          ← PDF/CSV mensual automático
```

---

##  Reglas Firestore recomendadas

```javascript
// firestore.rules
match /empresas/{empresaId}/fichajes/{fichajeId} {
  // El empleado puede leer y crear SUS fichajes
  allow read: if request.auth != null
    && get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.empresa_id == empresaId;

  allow create: if request.auth != null
    && request.resource.data.empleado_id == request.auth.uid
    && get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.empresa_id == empresaId;

  // Solo admin puede editar/eliminar
  allow update, delete: if request.auth != null
    && get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.rol == 'admin'
    && get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.empresa_id == empresaId;
}
```
