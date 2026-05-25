# Sistema de Fidelización Completo - FluxTech

**Fecha:** 2026-05-20  
**Estado:** ✅ Base implementada | ⚠️ Requiere extensión para euros

---

## 📋 Resumen

El sistema de fidelización permite a los negocios fidelizar clientes mediante dos modalidades:

1. **Por VISITAS/SELLOS** (✅ YA IMPLEMENTADO)
   - Ejemplo: "5 visitas → 15% descuento"
   
2. **Por IMPORTE GASTADO** (❌ POR IMPLEMENTAR)
   - Ejemplo: "50€ gastados → 15% descuento"

---

## 🎯 Flujo Completo

### **Para el CLIENTE (App Explorar B2C):**

```
1. Cliente va al negocio y hace una compra
2. Empleado escanea QR del cliente O Cliente escanea QR del negocio
3. Sistema suma:
   • +1 visita SI es por visitas
   • +X euros SI es por importe gastado
4. Cuando alcanza el objetivo → Recompensa desbloqueada 🎉
5. Cliente genera QR de canje temporal (válido 10 min)
6. Empleado escanea QR de canje → Aplica descuento
```

### **Para el NEGOCIO (App Empresario):**

```
1. Crear programa de fidelización:
   - Tipo: Visitas o Euros
   - Objetivo: 5 visitas O 50€
   - Recompensa: 15% descuento (o lo que quiera)
2. Sistema genera automáticamente 2 QRs:
   - QR VERDE: Para que cliente sume puntos
   - QR AZUL: Para que empleado canjee recompensas
3. Imprimir QRs y poner en mostrador
```

---

## 🗂️ Estructura de Datos

### **Colección:** `negocios_publicos/{negocioId}/programa_fidelizacion/{programaId}`

```javascript
{
  "negocio_id": "negocio123",
  "nombre": "Programa VIP",
  "descripcion": "Acumula puntos y obtén descuentos",
  "tipo": "sellos",  // "sellos" o "euros"
  "activo": true,
  
  // Si tipo === "sellos"
  "sellos_para_recompensa": 5,
  
  // Si tipo === "euros"
  "euros_para_recompensa": 50.00,
  
  "recompensas": [
    {
      "id": "uuid",
      "titulo": "15% de descuento",
      "descripcion": "En tu próxima compra",
      "tipo": "descuento",  // "descuento", "gratis", "vale"
      "valor": 15  // % o € según tipo
    }
  ],
  
  "caducidad_meses": 12,  // opcional
  "creado_at": Timestamp,
  "actualizado_at": Timestamp
}
```

### **Colección:** `usuarios/{uid}/tarjetas_sellos/{negocioId}`

```javascript
{
  "negocio_id": "negocio123",
  "negocio_nombre": "Peluquería María",
  "negocio_foto": "https://...",
  
  "programa_id": "programa456",
  "tipo_programa": "sellos",  // o "euros"
  
  // Si tipo === "sellos"
  "sellos_actuales": 3,  // De 0 a sellos_para_recompensa
  "sellos_totales_historico": 18,  // Total lifetime
  
  // Si tipo === "euros"
  "euros_acumulados": 35.50,  // De 0 a euros_para_recompensa
  "euros_totales_historico": 250.00,  // Total lifetime
  
  "objetivo": 5,  // o 50.00 si es euros
  "progreso_porcentaje": 60,  // 3/5 = 60%
  
  "recompensas_desbloqueadas": [
    {
      "recompensa_id": "uuid",
      "titulo": "15% descuento",
      "estado": "disponible",  // "disponible", "canjeada", "expirada"
      "desbloqueada_at": Timestamp,
      "canjeada_at": Timestamp,  // si está canjeada
      "qr_canje_id": "qr_uuid"  // si está canjeada
    }
  ],
  
  "ultimo_checkin": Timestamp,
  "creado_at": Timestamp,
  "actualizado_at": Timestamp
}
```

### **Colección:** `negocios_publicos/{negocioId}/checkins/{checkinId}`

```javascript
{
  "negocio_id": "negocio123",
  "cliente_id": "user123",
  "cliente_nombre": "Juan Pérez",
  "cliente_foto": "https://...",
  
  "tipo": "sellos",  // o "euros"
  
  // Si tipo === "sellos"
  "sellos_antes": 2,
  "sellos_despues": 3,
  
  // Si tipo === "euros"
  "euros_antes": 20.50,
  "euros_despues": 35.50,
  "euros_compra": 15.00,
  
  "recompensa_desbloqueada": false,
  "recompensa_id": "uuid",  // si se desbloqueó
  "recompensa_titulo": "15% descuento",
  
  "origen": "qr_negocio",  // "qr_negocio", "qr_cliente", "manual"
  
  "creado_at": Timestamp
}
```

### ⚡ **NUEVO:** QRs Estáticos por Empresa

```javascript
// negocios_publicos/{negocioId}
{  "qr_checkin_id": "checkin_negocio123",  // QR VERDE para sumar puntos
  "qr_canje_id": "canje_negocio123",     // QR AZUL para canjear recompensas
  ...
}
```

---

## 🔧 Implementación Necesaria

### **1. Extender modelo `ProgramaFidelizacionModel`**

```dart
class ProgramaFidelizacionModel {
  final String id;
  final String negocioId;
  final String nombre;
  final String descripcion;
  
  // NUEVO: Tipo de programa
  final TipoProgramaFidelizacion tipo;  // sellos o euros
  
  // Para tipo "sellos"
  final int? sellosParaRecompensa;
  
  // Para tipo "euros"
  final double? eurosParaRecompensa;
  
  final List<RecompensaPrograma> recompensas;
  final bool activo;
  final int? caducidadMeses;
  
  // ...
}

enum TipoProgramaFidelizacion {
  sellos,   // Por visitas
  euros,    // Por importe gastado
}
```

### **2. Extender `FidelizacionService`**

#### **A. Check-in con importe (euros)**

```dart
static Future<(...)> hacerCheckinConImporte({
  required String negocioId,
  required String programaId,
  required double importeCompra,  // ← NUEVO parámetro
}) async {
  // ... similar a hacerCheckin() pero suma euros en lugar de sellos
  
  final eurosAntes = tarjeta?.eurosAcumulados ?? 0;
  final eurosDespues = eurosAntes + importeCompra;
  
  // Verificar si alcanzó el objetivo
  if (eurosDespues >= programa.eurosParaRecompensa) {
    // Desbloquear recompensa
    // Resetear contador a 0
  }
  
  // Guardar en tarjeta y registrar checkin
}
```

#### **B. Generar QRs estáticos por negocio**

```dart
static Future<void> generarQrsEstaticos(String negocioId) async {
  final qrCheckinId = 'checkin_$negocioId';
  final qrCanjeId = 'canje_$negocioId';
  
  await _db.collection('negocios_publicos').doc(negocioId).update({
    'qr_checkin_id': qrCheckinId,
    'qr_canje_id': qrCanjeId,
    'qrs_generados_at': FieldValue.serverTimestamp(),
  });
}
```

#### **C. Escanear QR de negocio (check-in)**

```dart
static Future<(...)> escanearQrCheckin({
  required String qrData,  // "checkin_negocio123"
  required double? importe,  // null si es por sellos, X€ si es por euros
}) async {
  final negocioId = qrData.replaceFirst('checkin_', '');
  final programa = await obtenerPrograma(negocioId);
  
  if (programa!.tipo == TipoProgramaFidelizacion.sellos) {
    return await hacerCheckin(negocioId: negocioId, programaId: programa.id);
  } else {
    if (importe == null) {
      return (exito: false, mensaje: 'Debes indicar el importe de la compra');
    }
    return await hacerCheckinConImporte(
      negocioId: negocioId,
      programaId: programa.id,
      importeCompra: importe,
    );
  }
}
```

---

## 📱 Pantallas Necesarias

### **1. Pantalla: Mis Tarjetas de Fidelización (Cliente B2C)**

**Ubicación:** `lib/features/reservas_cliente/pantallas/mis_tarjetas_screen.dart`

**Diseño:**
```
┌─────────────────────────────────────────────┐
│  📇 Mis Tarjetas de Fidelización           │
├─────────────────────────────────────────────┤
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │ 📷 [Logo]    Peluquería María         │ │
│  │                                       │ │
│  │ ████████░░░░░░░░  3 de 5 visitas      │ │ ← BARRA de progreso
│  │                                       │ │
│  │ 🎁 15% descuento disponible           │ │
│  │ [Usar ahora]                          │ │
│  └───────────────────────────────────────┘ │
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │ 📷 [Logo]    Bar El Rincón            │ │
│  │                                       │ │
│  │ ████████████░░░░  35€ de 50€          │ │
│  │                                       │ │
│  │ 💐 Próxima: Tapa gratis               │ │
│  └───────────────────────────────────────┘ │
│                                             │
└─────────────────────────────────────────────┘
```

**Código:**
```dart
class MisTarjetasScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _loginRequired();
    
    return Scaffold(
      appBar: AppBar(title: Text('Mis Tarjetas')),
      body: StreamBuilder<List<TarjetaSelloModel>>(
        stream: FidelizacionService.escucharTodasLasTarjetas(user.uid),
        builder: (ctx, snap) {
          if (!snap.hasData) return CircularProgressIndicator();
          
          final tarjetas = snap.data!;
          if (tarjetas.isEmpty) return _sinTarjetas();
          
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: tarjetas.length,
            itemBuilder: (ctx, i) => _TarjetaFidelizacionWidget(
              tarjeta: tarjetas[i],
              onUsarRecompensa: () => _usarRecompensa(ctx, tarjetas[i]),
            ),
          );
        },
      ),
    );
  }
}
```

### **2. Widget: Tarjeta de Fidelización (ajustado a 1/4 de pantalla)**

```dart
class _TarjetaFidelizacionWidget extends StatelessWidget {
  final TarjetaSelloModel tarjeta;
  final VoidCallback? onUsarRecompensa;
  
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    
    return Container(
      height: height * 0.22,  // ← 22% de la altura = ~1/4
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila: Logo + Nombre
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: tarjeta.negocioFoto != null
                      ? Image.network(tarjeta.negocioFoto!, 
                          width: 48, height: 48, fit: BoxFit.cover)
                      : Container(
                          width: 48, height: 48,
                          color: Colors.grey[200],
                          child: Icon(Icons.store, color: Colors.grey[400]),
                        ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tarjeta.negocioNombre,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            Spacer(),
            
            // Barra de progreso
            _BarraProgreso(
              progreso: tarjeta.porcentajeProgreso,
              label: tarjeta.textoProg reso,  // "3 de 5 visitas" o "35€ de 50€"
            ),
            
            SizedBox(height: 8),
            
            // Recompensas disponibles
            if (tarjeta.tieneRecompensasDisponibles) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    Icon(Icons.card_giftcard, size: 16, color: Colors.green),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tarjeta.primeraRecompensaDisponible!.titulo,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onUsarRecompensa,
                      child: Text('Usar', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size(0, 28),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                'Sigue acumulando para tu próxima recompensa 🎁',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

---

## 🎨 Widget: Barra de Progreso

```dart
class _BarraProgreso extends StatelessWidget {
  final double progreso;  // 0.0 a 1.0
  final String label;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            Text(
              '${(progreso * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1976D2),
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progreso,
            minHeight: 10,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
          ),
        ),
      ],
    );
  }
}
```

---

## 🖨️ QRs del Negocio (Para imprimir y poner en mostrador)

### **QR 1: CHECK-IN (Verde)**

```
┌────────────────────────────┐
│                            │
│     ████████████████       │
│     ███  QR  ███  ███      │
│     ████████████████       │
│                            │
│   ✓ SUMAR PUNTOS           │
│   Escanea para acumular    │
│                            │
└────────────────────────────┘

Dato QR: "checkin_negocio123"
```

### **QR 2: CANJE (Azul)**

```
┌────────────────────────────┐
│                            │
│     ████████████████       │
│     ███  QR  ███  ███      │
│     ████████████████       │
│                            │
│   🎁 CANJEAR RECOMPENSA    │
│   Escanea para usar        │
│                            │
└────────────────────────────┘

Dato QR: "canje_negocio123"
```

---

## 🔄 Flujos de Uso

### **Flujo A: Cliente escanea QR del negocio (CHECK-IN)**

```
1. Cliente abre app → "Escanear QR"
2. Escanea QR VERDE del mostrador
3. SI es programa por euros:
   → App pregunta: "¿Cuánto gastaste? __€"
4. Sistema suma puntos
5. App muestra: "¡+1 visita! Te faltan 2" o "¡+15€! Te faltan 35€"
6. SI completó objetivo → Recompensa desbloqueada 🎉
```

### **Flujo B: Empleado escanea QR del cliente (CANJE)**

```
1. Cliente tiene recompensa disponible
2. Cliente pulsa "Usar ahora" en la tarjeta
3. App genera QR temporal (válido 10 min)
4. Empleado escanea QR TEMPORAL con su app
5. Sistema valida y marca como canjeada
6. Empleado aplica descuento manualmente en TPV
```

### **Flujo C: Check-in desde TPV (Automatizado)**

```
1. Cliente dice su teléfono/nombre en caja
2. Empleado busca cliente en TPV
3. TPV muestra: "Cliente tiene programa VIP"
4. Empleado pulsa "Sumar punto"
5. Sistema suma automáticamente basándose en:
   • +1 visita SI es por visitas
   • +[importe del ticket] € SI es por euros
6. Ticket impreso incluye: "¡+1 visita! Te faltan 2"
```

---

## ✅ Checklist de Implementación

- [ ] Extender `ProgramaFidelizacionModel` con tipo "euros"
- [ ] Extender `TarjetaSelloModel` con campos de euros
- [ ] Implementar `hacerCheckinConImporte()` en service
- [ ] Implementar `generarQrsEstaticos()` en service
- [ ] Implementar `escanearQrCheckin()` en service
- [ ] Crear pantalla `MisTarjetasScreen` (cliente B2C)
- [ ] Crear widget `_TarjetaFidelizacionWidget` (ajustado a 1/4)
- [ ] Crear pantalla de configuración programa (empresario)
- [ ] Generar PDFs de QRs para imprimir (empresario)
- [ ] Integrar check-in desde TPV al cobrar
- [ ] Probar flujo completo con ambos tipos

---

## 🐛 Consideraciones Importantes

### **1. ¿Cómo registrar el importe en euros desde TPV?**

**Opción A (AUTOMÁTICA - RECOMENDADA):**
Al cobrar en TPV, si el cliente tiene tarjeta de fidelización:
```dart
// En tpv_xxx_cobro.dart después de cobrar
if (clienteId != null) {
  final tarjeta = await FidelizacionService.obtenerTarjeta(clienteId, negocioId);
  if (tarjeta != null && tarjeta.tipPrograma == TipoProgramaFidelizacion.euros) {
    await FidelizacionService.hacerCheckinConImporte(
      negocioId: negocioId,
      programaId: tarjeta.programaId,
      importeCompra: totalCobrado,  // ← Total del ticket
    );
  }
}
```

**Opción B (MANUAL):**
Cliente escanea QR e introduce manualmente el importe.

**RECOMENDACIÓN:** Opción A es mejor porque:
- ✅ No hay fraude (el importe es real del TPV)
- ✅ Automático, sin fricción para el cliente
- ✅ Datos precisos para estadísticas

### **2. Prevención de fraude**

- ⏱️ **Límite de tiempo**: Un check-in cada X horas (ya implementado)
- 📍 **Geolocalización**: Solo permite check-in si está cerca del negocio (opcional)
- 🔐 **QR temporal**: Los QRs de canje expiran en 10 min (ya implementado)

### **3. Vinculación con Reservas**

Si el cliente tiene reserva:
```dart
// Al finalizar reserva
await FidelizacionService.hacerCheckin(
  negocioId: reserva.negocioId,
  programaId: programa.id,
);
```

---

## 📈 Estadísticas para el Negocio

Dashboard empresario muestra:
- **Total clientes**: Cuántos clientes tienen tarjeta
- **Check-ins este mes**: Actividad
- **Clientes recurrentes**: Que vienen ≥2 veces
- **Recompensas canjeadas este mes**: ROI del programa

---

**Implementado por:** GitHub Copilot  
**Versión:** 1.0 - Base | 2.0 - Con euros (pendiente)  
**Última actualización:** 2026-05-20

