# 🌐 GUÍA COMPLETA: INTEGRAR WORDPRESS CON PLANEAGUADA CRM

## 🎯 **¿Qué conseguirás con esta integración?**

### **WordPress → Flutter CRM:**
- ✅ **Nuevas reservas** de formularios web aparecen automáticamente en el CRM
- ✅ **Reseñas/comentarios** del sitio se sincronizan como valoraciones
- ✅ **Estadísticas de visitas** se muestran en el dashboard de estadísticas
- ✅ **Formularios de contacto** se convierten en leads

### **Flutter CRM → WordPress:**
- ✅ **Aceptar/Rechazar reservas** envía email automático al cliente
- ✅ **Responder a reseñas** se publica en WordPress
- ✅ **Nuevos servicios** se sincronizan con la web
- ✅ **Cambios de precios** se actualizan automáticamente

---

## 🛠️ **INSTALACIÓN PASO A PASO**

### **PASO 1: Configurar Plugin de WordPress**

#### **1.1 Subir Plugin:**
1. Descarga el archivo `planeaguada-crm-integration.php`
2. Súbelo a `/wp-content/plugins/planeaguada-crm/`
3. Actívalo desde el panel de WordPress

#### **1.2 Configurar Plugin:**
1. Ve a **Ajustes → PlaneaGuada CRM**
2. Configura:
   ```
   Firebase Project ID: tu-proyecto-firebase
   Empresa ID: [el ID que aparece en el dashboard]
   API Key: [tu clave de Firebase]
   ```

#### **1.3 Verificar Formularios:**
Asegúrate de que tus formularios de contacto usen estos campos:
- `your-name` (Nombre)
- `your-email` (Email)  
- `your-phone` (Teléfono)
- `service` (Servicio)
- `appointment-date` (Fecha de cita)
- `your-message` (Notas)

---

### **PASO 2: Configurar Firebase Cloud Functions**

#### **2.1 Instalar Firebase CLI:**
```bash
npm install -g firebase-tools
firebase login
```

#### **2.2 Crear Funciones:**
Crea el archivo `functions/index.js`:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Función para recibir webhooks de WordPress
exports.receiveWordPressWebhook = functions.https.onRequest(async (req, res) => {
    const data = req.body;
    
    try {
        // Guardar en Firestore
        await admin.firestore()
            .collection('empresas')
            .doc(data.empresa_id)
            .collection(data.collection)
            .add(data.payload);
            
        res.status(200).send('OK');
    } catch (error) {
        console.error('Error:', error);
        res.status(500).send('Error');
    }
});

// Función para notificar cambios a WordPress
exports.notifyWordPress = functions.firestore
    .document('empresas/{empresaId}/reservas/{reservaId}')
    .onUpdate(async (change, context) => {
        const after = change.after.data();
        const before = change.before.data();
        
        // Si cambió el estado y viene de la web
        if (after.estado !== before.estado && after.origen === 'web') {
            // Notificar a WordPress
            const webhook_url = 'https://tu-sitio.com/wp-json/planeaguada/v1/webhook';
            
            await fetch(webhook_url, {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({
                    type: 'reservation_status_changed',
                    reserva_id: context.params.reservaId,
                    nuevo_estado: after.estado,
                    empresa_id: context.params.empresaId
                })
            });
        }
    });
```

#### **2.3 Desplegar Funciones:**
```bash
firebase deploy --only functions
```

---

### **PASO 3: Configurar Flutter App**

#### **3.1 Actualizar Configuración WordPress:**

En el dashboard, ve al módulo de estadísticas y verás un nuevo header azul con el logo de WordPress y un botón de sincronización.

#### **3.2 Configurar URL de WordPress:**

Edita `lib/services/wordpress_service.dart`:
```dart
// Cambiar por tu dominio real
void configurarWordPress(String baseUrl) {
    _dio.options.baseUrl = 'https://tu-sitio-web.com';
}
```

---

## 🧪 **TESTING DE LA INTEGRACIÓN**

### **Test 1: Reserva desde WordPress → Flutter**

1. **En tu web WordPress:**
   - Llena el formulario de contacto/reservas
   - Envía la reserva

2. **En el CRM Flutter:**
   - Ve a la pestaña **"Reservas"**
   - Deberías ver la nueva reserva en **"Pendientes"**
   - Estado: "pendiente", Origen: "web"

### **Test 2: Aceptar Reserva Flutter → WordPress**

1. **En el CRM Flutter:**
   - En "Reservas Pendientes", haz clic **"Aceptar"**
   - Deberías ver mensaje: "Email pendiente de enviar"

2. **En WordPress:**
   - Revisa los logs del plugin
   - El cliente debería recibir email de confirmación

### **Test 3: Reseña WordPress → Flutter**

1. **En WordPress:**
   - Añade un comentario con rating en un post/página
   - Apruébalo

2. **En CRM Flutter:**
   - Ve a pestaña **"Valoraciones"**
   - Deberías ver la nueva reseña
   - Prueba a **"Responder"**

### **Test 4: Estadísticas Sincronizadas**

1. **En CRM Flutter:**
   - Ve a pestaña **"Estadísticas"**
   - Haz clic en el botón **"Sincronizar"** (junto al logo WordPress)
   - Deberías ver las visitas de WordPress en el KPI principal

---

## 🔧 **CONFIGURACIONES AVANZADAS**

### **Personalizar Formularios de WordPress**

Si tu formulario tiene campos diferentes, edita el plugin:

```php
// En handle_contact_form_submission()
$reservation_data = [
    'client_name' => $posted_data['nombre'] ?? '',        // ← Tu campo
    'client_email' => $posted_data['email'] ?? '',        // ← Tu campo
    'service' => $posted_data['servicio'] ?? '',          // ← Tu campo
    // ... resto igual
];
```

### **Integrar Google Analytics**

Para estadísticas más precisas, instala un plugin de Google Analytics y edita:

```php
private function get_monthly_visits($month) {
    // Con plugin Google Analytics
    if (function_exists('ga_get_monthly_visits')) {
        return ga_get_monthly_visits($month);
    }
    
    // Fallback actual...
}
```

### **Personalizar Emails Automáticos**

En el plugin de WordPress, edita `send_reservation_email()`:

```php
private function send_reservation_email($reservation_id, $status) {
    $reservation = $this->get_reservation($reservation_id);
    
    $subject = $status === 'confirmada' 
        ? 'Reserva Confirmada - ' . get_bloginfo('name')
        : 'Reserva Cancelada - ' . get_bloginfo('name');
        
    $message = $status === 'confirmada'
        ? "Hola {$reservation->client_name}, tu reserva ha sido confirmada..."
        : "Lamentamos informarte que tu reserva ha sido cancelada...";
        
    wp_mail($reservation->client_email, $subject, $message);
}
```

---

## 🎯 **MONITOREO Y DEBUGGING**

### **Logs en WordPress:**
```php
// Añadir en el plugin para debug
error_log('PlaneaGuada: Enviando a Firebase - ' . json_encode($data));
```

### **Logs en Flutter:**
```dart
// En wordpress_service.dart
print('🔄 Sincronizando con WordPress...');
print('✅ ${reviews.length} reseñas sincronizadas');
```

### **Verificar Firebase:**
- Ve a Firebase Console → Firestore
- Revisa las colecciones `empresas/{tu-empresa-id}/valoraciones`
- Verifica que lleguen datos con `origen: 'wordpress'`

---

## ✅ **RESULTADO FINAL**

### **Flujo Completo Funcionando:**

1. **Cliente hace reserva en web** → Aparece en CRM automáticamente
2. **Admin acepta en CRM** → Cliente recibe email de confirmación  
3. **Cliente deja reseña en web** → Aparece en CRM para responder
4. **Admin responde en CRM** → Respuesta se publica en WordPress
5. **Estadísticas web** → Se muestran en tiempo real en el dashboard

### **Dashboard Mejorado:**
- **Módulo Estadísticas** muestra datos reales de WordPress
- **Módulo Valoraciones** incluye reseñas de la web
- **Módulo Reservas** procesa reservas del sitio web
- **Sincronización automática** cada 15 minutos

**¡Tu WordPress y Flutter CRM ahora están completamente integrados!** 🎉

---

## 📞 **Soporte**

Si tienes problemas:

1. **Verifica logs** en WordPress (Herramientas → Logs)
2. **Revisa Firebase Console** para errores de funciones
3. **Usa el botón "Sincronizar"** en el CRM para forzar sync
4. **Verifica que los campos del formulario** coincidan con los esperados

La integración está diseñada para funcionar de manera robusta y automática. 🚀
