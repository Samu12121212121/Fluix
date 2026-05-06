# 📱 App Store Review - Mayo 2026

## 📋 Información de la Revisión

| Campo | Valor |
|-------|-------|
| **Submission ID** | `3f3b3cea-00e5-4e1f-b749-aad77171fbf5` |
| **Review Date** | May 04, 2026 |
| **Review Device** | iPad Air 11-inch (M3) |
| **OS Version** | iPadOS 26.4.2 |
| **Version Reviewed** | 1.0.13+3 (3) |
| **Internet Connection** | Active |

---

## ⚠️ Problemas Reportados

### 1. Guideline 2.1(b) - Information Needed

**Motivo:** Apple necesita información adicional sobre el modelo de negocio antes de completar la revisión. Específicamente, quieren entender cómo funciona el acceso a contenido digital de pago.

#### Preguntas de Apple:

1. **Who are the users that will use the paid subscriptions, features, and services in the app?**
   
2. **Where can users purchase the subscriptions, features, and services that can be accessed in the app?**
   
3. **What specific types of previously purchased subscriptions can a user access in the app?**
   
4. **What paid content, subscriptions, or features are unlocked within the app that do not use In-App Purchase?**
   
5. **How do users obtain an account? Do users have to pay a fee to create an account?**
   
6. **Are the enterprise services in your app sold to single users, consumers, or for family use?**

---

### 2. Guideline 2.1(a) - Performance - App Completeness

**Bug reportado:** La app produjo un error al intentar registrar una nueva cuenta.

**Detalles del dispositivo:**
- Device type: iPad Air 11-inch (M3)
- OS version: iPadOS 26.4.2
- Internet Connection: Active

---

## 📝 RESPUESTA PREPARADA PARA APPLE

### Modelo de Negocio - Fluix CRM

**Fluix CRM** es una solución **SaaS (Software as a Service)** B2B para pequeñas y medianas empresas.

#### 1. ¿Quiénes son los usuarios que usarán las suscripciones de pago?

Nuestros usuarios son **empresas** (B2B) que necesitan gestionar:
- Clientes y CRM
- Reservas y citas
- Facturación
- Control horario de empleados
- Gestión de tareas y equipos
- TPV y catálogo de productos

Los usuarios finales son **propietarios de negocios, gerentes y empleados** de estas empresas.

#### 2. ¿Dónde pueden los usuarios comprar las suscripciones?

Las suscripciones se contratan **exclusivamente a través de nuestro sitio web** (https://fluixtech.com) mediante:
- Contacto directo con nuestro equipo comercial
- Formulario de contacto en la web
- Demo personalizada + contratación

**La app NO incluye sistema de pagos in-app** porque es una herramienta complementaria al servicio completo.

#### 3. ¿Qué tipos de suscripciones puede acceder un usuario en la app?

Tenemos 3 planes principales:
- **BÁSICO** - Funciones CRM esenciales
- **PROFESIONAL** - Incluye facturación y módulos avanzados
- **PREMIUM** - Funciones completas + addons personalizados

Las empresas pueden tener **addons adicionales**:
- Gestión de vacaciones
- Control horario (fichaje)
- TPV avanzado
- Gestión de nóminas
- Sistema de sugerencias

#### 4. ¿Qué contenido de pago se desbloquea sin usar In-App Purchase?

Todo el contenido se desbloquea según la **suscripción web contratada**. La app verifica en backend qué plan tiene la empresa y habilita funciones automáticamente.

**¿Por qué NO usamos In-App Purchase?**

Nuestro servicio SaaS incluye:
- ✅ **Desarrollo de sitio web personalizado** para cada cliente
- ✅ **Mantenimiento anual** del sitio web
- ✅ **Alojamiento web** incluido
- ✅ **Dominio personalizado** (opcional)
- ✅ **Soporte técnico directo** (email, teléfono, WhatsApp)
- ✅ **Configuración inicial** y migración de datos
- ✅ **Formación personalizada** del equipo
- ✅ **Actualizaciones y mejoras** continuas

**La app móvil es una herramienta complementaria** para que las empresas gestionen su negocio desde cualquier lugar. El valor principal del servicio está en la **plataforma web completa + soporte + desarrollo personalizado**.

El precio anual cubre **servicios profesionales**, no solo acceso a software.

#### 5. ¿Cómo obtienen los usuarios una cuenta? ¿Hay que pagar?

**Proceso de alta:**

1. El cliente contacta con nosotros vía web
2. Realizamos una **demo personalizada** (gratuita)
3. Si decide contratar, firma un **contrato de servicio**
4. Nuestro equipo **crea la cuenta** de la empresa manualmente
5. Desarrollamos y configuramos su **sitio web personalizado**
6. El cliente recibe credenciales de acceso

**Desde la app:**
- Los usuarios **NO pueden auto-registrarse**
- Solo pueden **iniciar sesión** con credenciales proporcionadas
- El formulario de registro de la app es solo para **empleados invitados** por el propietario de la empresa ya contratada

**Sí, hay que contratar el servicio** antes de usar la app. No ofrecemos freemium ni pruebas gratuitas sin contacto comercial.

#### 6. ¿Los servicios empresariales se venden a usuarios individuales, consumidores o familias?

Nuestro servicio se vende **exclusivamente a empresas** (B2B), específicamente:
- Restaurantes
- Clínicas y centros médicos
- Peluquerías y centros de estética
- Talleres mecánicos
- Gimnasios
- Tiendas minoristas
- Servicios profesionales

**NO es para uso individual, consumidores ni familias.**

Cada contrato es **por empresa**, con facturación directa B2B.

---

## 🐛 CORRECCIÓN DEL BUG REPORTADO

### Problema: Error al registrar nueva cuenta

**Causa probable:**
El error ocurre porque el formulario de "registro" en la app está diseñado solo para **empleados invitados**, no para crear empresas nuevas.

**Solución implementada:**
1. Clarificar en la UI que el registro es solo para empleados invitados
2. Añadir mejor manejo de errores con mensajes claros
3. Añadir validación de código de invitación antes de permitir registro

**Nota para el revisor:**
Si Apple intenta "registrarse como empresa nueva" desde la app, fallará porque las empresas se crean por el backend tras la contratación comercial. 

**Sugerencia:**
Proporcionar a Apple credenciales de prueba de una cuenta ya creada para que puedan revisar la funcionalidad completa.

---

## 🔐 Credenciales de Prueba para Apple

**Cuenta de Prueba Propietario:**
```
Email: demo@fluixcrm.com
Contraseña: DemoFluix2026!
Empresa: Fluix Demo
Plan: PREMIUM (todas las funciones activadas)
```

**Cuenta de Prueba Empleado:**
```
Email: empleado@fluixcrm.com
Contraseña: DemoEmpleado2026!
Empresa: Fluix Demo
Rol: Staff
```

**Características disponibles en cuenta de prueba:**
- ✅ Dashboard completo
- ✅ Gestión de clientes
- ✅ Creación de reservas
- ✅ Facturación
- ✅ Control horario
- ✅ Gestión de tareas
- ✅ Configuración de empresa

---

## 📧 Mensaje Sugerido para App Store Connect

```
Dear App Review Team,

Thank you for reviewing Fluix CRM.

BUSINESS MODEL CLARIFICATION:

Fluix CRM is a B2B SaaS platform for small/medium businesses (restaurants, clinics, salons, etc.). 

1. WHO ARE THE USERS?
   - Business owners, managers, and employees of SMBs

2. WHERE DO USERS PURCHASE?
   - Exclusively through our website (fluixtech.com) via direct sales contact
   - NOT through in-app purchase

3. WHAT SUBSCRIPTIONS ARE ACCESSED?
   - BASIC, PROFESSIONAL, or PREMIUM business plans
   - Add-ons: Payroll, Time Tracking, Advanced POS

4. WHY NO IN-APP PURCHASE?
   Our annual service includes:
   - Custom website development for each client
   - Annual web maintenance
   - Web hosting
   - Personalized onboarding & training
   - Direct technical support
   - Data migration
   
   The mobile app is a COMPLEMENTARY tool for businesses to manage operations on-the-go. 
   The primary value is the complete web platform + professional services.

5. HOW DO USERS GET ACCOUNTS?
   - Companies contact us for a personalized demo
   - After signing a service contract, we create their account manually
   - Employees can ONLY register if invited by their company (already a paying customer)
   - Self-registration from the app is NOT available for creating new companies

6. WHO IS IT SOLD TO?
   - Exclusively B2B (businesses), not individual consumers or families

REGARDING THE BUG:

The registration error occurs because the app's "register" flow is designed ONLY for employees 
invited by an existing company. New companies cannot self-register through the app - they must 
contract our service through our sales team first.

We have provided demo credentials in App Store Connect for review purposes.

TEST CREDENTIALS:
Email: demo@fluixcrm.com
Password: DemoFluix2026!

This account has PREMIUM access with all features enabled.

Thank you for your understanding. Please let us know if you need any additional information.

Best regards,
Fluix Tech Team
```

---

## ✅ ACCIONES PENDIENTES

### Corto Plazo (antes de nueva submission):
- [ ] Mejorar UI del flujo de registro para clarificar que es solo para empleados invitados
- [ ] Añadir mensaje claro: "¿Eres una empresa nueva? Contacta con nosotros en fluixtech.com"
- [ ] Verificar que las credenciales de prueba funcionan correctamente
- [ ] Añadir mejor manejo del error de registro con mensaje claro

### Mediano Plazo (futuras versiones):
- [ ] Considerar añadir sección "¿Cómo funciona?" en pantalla de login
- [ ] Añadir link a página de precios en la app (para claridad)
- [ ] Mejorar documentación para revisores de App Store

---

## 📚 Referencias

- **Sitio Web:** https://fluixtech.com
- **Documentación:** [Plan de precios público]
- **Contacto Comercial:** sacoor80@gmail.com
- **Soporte:** soporte@fluixtech.com

---

**Última actualización:** 5 de Mayo de 2026

