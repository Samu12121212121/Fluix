# Política de Privacidad — Fluix CRM

**Última actualización:** 6 de abril de 2026  
**Versión:** 2.0  
**URL de publicación:** [fluixtech.com/privacidad](https://fluixtech.com/privacidad)

---

La presente Política de Privacidad tiene por objeto informarle de forma transparente, clara y completa sobre el tratamiento de sus datos personales cuando utiliza la aplicación **Fluix CRM** (en adelante, «la Aplicación» o «la App»), el sitio web [fluixtech.com](https://fluixtech.com) y todos los servicios asociados (en adelante, conjuntamente, «los Servicios»), de conformidad con el **Reglamento (UE) 2016/679** (RGPD), la **Ley Orgánica 3/2018, de 5 de diciembre, de Protección de Datos Personales y garantía de los derechos digitales** (LOPDGDD), y demás normativa aplicable.

Le rogamos lea atentamente esta política antes de utilizar nuestros Servicios. Al registrarse o utilizar la Aplicación, usted confirma que ha leído y comprendido las condiciones aquí descritas.

---

## 1. Responsable del Tratamiento

| Campo | Detalle                  |
|-------|--------------------------|
| **Razón social** | Fluixtech S.L.           |
| **CIF** | B26997528                |
| **Domicilio social** | Guadalajara, España      |
| **Correo electrónico** | privacidad@fluixtech.com |
| **Sitio web** | https://fluixtech.com    |
| **DPO** | dpo@fluixtech.com        |

---

## 2. Ámbito de Aplicación y Roles

Fluix CRM es una plataforma B2B que presta servicios de gestión empresarial a pequeñas y medianas empresas (pymes) españolas. En el marco del tratamiento de datos personales, se distinguen los siguientes roles:

| Rol | Descripción | Ejemplo |
|-----|-------------|---------|
| **Responsable del Tratamiento** | Fluixtech S.L., en lo relativo a los datos necesarios para la prestación del servicio de la plataforma (cuenta del cliente, facturación, soporte). | Datos de registro de la empresa cliente |
| **Encargado del Tratamiento** | Fluixtech S.L., cuando trata datos de empleados o clientes finales por cuenta de la empresa cliente. Se formaliza mediante el correspondiente *Contrato de Encargado del Tratamiento* (art. 28 RGPD). | Nóminas de empleados, datos de clientes del negocio |
| **Responsable (empresa cliente)** | La empresa que utiliza Fluix CRM es responsable del tratamiento de los datos personales de sus empleados y clientes finales que introduce en la plataforma. | Restaurante que ficha a sus empleados con la App |

---

## 3. Datos Personales que Recogemos

### 3.1. Datos de la empresa cliente (usuario de Fluix CRM)

| Categoría | Datos concretos | Obligatorio |
|-----------|----------------|-------------|
| Identificación mercantil | Nombre o razón social, NIF/CIF, dirección fiscal, teléfono de empresa | Sí |
| Acceso y autenticación | Correo electrónico, contraseña (almacenada cifrada mediante Firebase Authentication) | Sí |
| Identidad visual | Logotipo, imágenes del negocio, fotos de productos/servicios | No |
| Información comercial | Carta/menú, catálogo de servicios, listado de productos, precios | No |
| Información operativa | Horarios de apertura, URL del sitio web, redes sociales | No |
| Datos de facturación | Datos bancarios para cobros/pagos vía Stripe, historial de suscripción | Sí (para funciones de pago) |
| Certificados digitales | Certificado FNMT para firma electrónica y comunicación con la AEAT (almacenado cifrado) | No (solo si usa Verifactu/modelos fiscales) |

### 3.2. Datos de los empleados de la empresa cliente

> ⚠️ **Categorías especiales de datos:** Algunos de estos datos (datos de salud relativos a bajas laborales/IT, embargos judiciales) constituyen categorías especiales de datos o datos especialmente protegidos. Su tratamiento se realiza exclusivamente por cuenta y bajo la responsabilidad de la empresa cliente, al amparo de las bases legales indicadas en la Sección 4.

| Categoría | Datos concretos |
|-----------|----------------|
| Identificación personal | Nombre completo, NIF/NIE, fecha de nacimiento, estado civil, nacionalidad |
| Documentación | DNI/NIE escaneado, contratos de trabajo firmados, documentos laborales |
| Seguridad Social | Número de afiliación a la Seguridad Social (NAF), grupo de cotización, base de cotización |
| Datos económicos | Salario bruto/neto, complementos salariales, IBAN/BIC para domiciliación de nómina, retenciones IRPF |
| Datos laborales | Tipo de contrato, categoría profesional, antigüedad, convenio colectivo aplicable, jornada laboral |
| Control horario | Registros de fichajes (entrada/salida), **datos de geolocalización GPS** asociados al fichaje (si la empresa lo activa) |
| Datos de salud (cat. especial) | Períodos de incapacidad temporal (IT), tipo de baja (contingencia común/profesional), fechas de alta/baja médica |
| Datos judiciales | Embargos de salario (orden judicial, porcentaje de retención, juzgado emisor) |
| Vacaciones y ausencias | Días de vacaciones, permisos, ausencias justificadas/injustificadas |
| Nómina y fiscal | Datos completos para el cálculo de nóminas conforme a la legislación laboral española vigente (incluidos datos para modelos AEAT: 111, 190, etc.) |

### 3.3. Datos de los clientes finales del negocio

| Categoría | Datos concretos |
|-----------|----------------|
| Identificación | Nombre, correo electrónico, número de teléfono |
| Actividad comercial | Historial de reservas, historial de pedidos, preferencias |
| Opiniones | Valoraciones, reseñas publicadas (incluidas las sincronizadas desde Google Business Profile) |

### 3.4. Datos técnicos y de uso

| Categoría | Datos concretos |
|-----------|----------------|
| Dispositivo | Modelo del dispositivo, sistema operativo, versión de la App, idioma, identificador de instalación |
| Conexión | Dirección IP, tipo de red (WiFi/datos móviles) |
| Uso de la App | Pantallas visitadas, funcionalidades utilizadas, marcas de tiempo, registros de errores (*crash logs*) |
| Notificaciones | Token de FCM (Firebase Cloud Messaging) para notificaciones push |

---

## 4. Finalidades y Bases Legales del Tratamiento

| Finalidad | Datos implicados | Base legal (RGPD) |
|-----------|------------------|-------------------|
| **Registro y gestión de la cuenta** — Crear y mantener la cuenta del usuario en la plataforma. | Email, contraseña, datos mercantiles | **Art. 6.1.b)** – Ejecución de contrato |
| **Prestación del servicio de gestión empresarial** — CRM, facturación, inventario, TPV, gestión de reservas y pedidos. | Datos de la empresa, productos, clientes finales | **Art. 6.1.b)** – Ejecución de contrato |
| **Gestión de nóminas y recursos humanos** — Cálculo de nóminas, contratos, fichajes, vacaciones, bajas. | Datos de empleados (NAF, salario, IBAN, IT) | **Art. 6.1.b)** – Ejecución de contrato / **Art. 6.1.c)** – Obligación legal |
| **Tratamiento de datos de salud (bajas IT)** — Registro de incapacidades temporales para cálculo de nómina. | Datos de salud del empleado | **Art. 9.2.b)** – Obligaciones Derecho laboral y Seguridad Social |
| **Gestión de embargos** — Aplicación de retenciones judiciales sobre nóminas. | Datos de embargos | **Art. 6.1.c)** – Obligación legal (resoluciones judiciales) |
| **Cumplimiento de obligaciones fiscales** — Facturas, modelos AEAT (303, 111, 190, 347…), Verifactu, SII. | Datos fiscales, facturación | **Art. 6.1.c)** – Obligación legal (normativa tributaria) |
| **Firma digital y comunicación con AEAT** — Certificados FNMT para firma electrónica y envío telemático. | Certificado digital, datos fiscales | **Art. 6.1.c)** – Obligación legal / **Art. 6.1.b)** – Ejecución de contrato |
| **Control horario y geolocalización** — Registro de jornada (art. 34.9 ET). GPS solo en el momento del fichaje. | Fichajes, coordenadas GPS | **Art. 6.1.c)** – Obligación legal / **Art. 6.1.f)** – Interés legítimo |
| **Procesamiento de pagos** — Cobro de suscripciones vía Stripe. | Datos de tarjeta/cuenta (procesados por Stripe) | **Art. 6.1.b)** – Ejecución de contrato |
| **Notificaciones push** — Alertas sobre fichajes, nóminas, facturas, reservas. | Token FCM | **Art. 6.1.b)** – Ejecución de contrato / **Art. 6.1.a)** – Consentimiento |
| **Envío de correos electrónicos** — Nóminas, facturas, recordatorios vía SMTP. | Email, contenido del documento | **Art. 6.1.b)** – Ejecución de contrato |
| **Gestión de reseñas (Google Business Profile)** — Sincronización y respuesta a reseñas. | Nombre del autor, texto, valoración | **Art. 6.1.f)** – Interés legítimo |
| **Gestión de la web del negocio** — Publicación de contenidos (menú, horarios, servicios). | Datos comerciales | **Art. 6.1.b)** – Ejecución de contrato |
| **Mejora del servicio y análisis** — Análisis de uso de la App. | Datos técnicos y de uso anonimizados | **Art. 6.1.f)** – Interés legítimo |
| **Seguridad** — Detección y prevención de accesos no autorizados, fraude y abuso. | IP, logs de acceso, autenticación | **Art. 6.1.f)** – Interés legítimo |

---

## 5. Destinatarios de los Datos y Encargados del Tratamiento

### 5.1. Proveedores de servicios tecnológicos (Encargados del Tratamiento)

| Proveedor | Servicio | Datos tratados | Ubicación | Garantías |
|-----------|---------|---------------|-----------|-----------|
| **Google LLC** (Firebase) | Auth, Firestore, Cloud Storage, FCM, Hosting | Todos los datos almacenados en la App | EE.UU. / UE | EU-U.S. Data Privacy Framework, CCT, SOC 2/3, ISO 27001 |
| **Stripe, Inc.** | Procesamiento de pagos | Datos de pago (tarjeta, IBAN) — *Fluixtech no almacena datos completos de tarjeta* | EE.UU. / Irlanda | EU-U.S. Data Privacy Framework, PCI DSS Nivel 1, CCT |
| **Google LLC** (GBP API) | Gestión de reseñas y ficha de Google | Datos de la ficha, reseñas públicas | EE.UU. / UE | EU-U.S. Data Privacy Framework, CCT |
| **Proveedor SMTP** | Envío de emails transaccionales | Email del destinatario, contenido | UE | Contrato de Encargado del Tratamiento, cifrado TLS |

### 5.2. Comunicaciones a terceros por obligación legal

- **AEAT:** Modelos tributarios, Verifactu/SII.
- **TGSS:** Cotización y afiliación.
- **Juzgados y Tribunales:** Requerimientos judiciales (embargos).
- **Inspección de Trabajo:** Según normativa laboral.
- **AEPD:** Incidentes de seguridad o ejercicio de derechos.

### 5.3. No venta de datos

**Fluixtech no vende, alquila ni comercializa datos personales a terceros bajo ningún concepto.**

---

## 6. Transferencias Internacionales de Datos

Algunos proveedores tienen sede en EE.UU. Las transferencias se amparan en:

1. **Marco de Privacidad de Datos UE-EE.UU.** (*EU-U.S. Data Privacy Framework*): Decisión de adecuación de la CE de 10/07/2023. Google LLC y Stripe, Inc. están certificados.
2. **Cláusulas Contractuales Tipo (CCT):** Decisión de Ejecución (UE) 2021/914.
3. **Medidas técnicas complementarias:** Cifrado TLS 1.2+, AES-256 en reposo, RBAC, auditorías.

Puede solicitar copia de las garantías en dpo@fluixtech.com.

---

## 7. Plazos de Conservación de los Datos

| Tipo de datos | Plazo | Fundamento legal |
|--------------|-------|-----------------|
| Datos de la cuenta de usuario | Relación contractual + 5 años | Art. 1964 CC |
| Facturas y datos fiscales | Mínimo **4 años** + período de inspección | Art. 66 LGT |
| Datos de Verifactu / registros AEAT | **4 años** desde presentación | Art. 66 LGT |
| Nóminas y documentación laboral | **4 años** (laboral/SS) + **5 años** (civil) | Art. 21 LGSS, art. 59 ET, art. 1964 CC |
| Registros de jornada (fichajes) | **4 años** | Art. 34.9 ET |
| Datos de geolocalización | **4 años** (asociados al fichaje) | Art. 34.9 ET |
| Datos de bajas laborales (IT) | **5 años** tras alta médica | Art. 21 LGSS |
| Embargos judiciales | Vigencia de la orden + **5 años** | Resolución judicial |
| Datos de clientes del negocio | Relación comercial + **3 años** | Art. 72 LOPDGDD |
| Datos de pagos (Stripe) | **5 años** tras última transacción | Ley 10/2010 PBC |
| Logs técnicos y de seguridad | **12 meses** | Art. 5 Ley 25/2007 |
| Certificados digitales (FNMT) | Mientras sean necesarios; se eliminan al dar de baja | Art. 6.1.b) RGPD |

Transcurridos los plazos, los datos serán eliminados o anonimizados de forma irreversible.

---

## 8. Medidas de Seguridad

### Medidas técnicas

- **Cifrado en tránsito:** TLS 1.2+ (HTTPS).
- **Cifrado en reposo:** AES-256 (Firebase/Firestore).
- **Cifrado de contraseñas:** Hash seguro (bcrypt/scrypt) vía Firebase Auth.
- **Cifrado de datos sensibles:** Capa adicional para certificados y datos bancarios.
- **RBAC:** Control de acceso basado en roles.
- **Reglas de seguridad Firestore:** Aislamiento por empresa (*tenant isolation*).
- **Autenticación multifactor:** Disponible opcionalmente.
- **Tokenización de pagos:** Stripe (PCI DSS Nivel 1). No almacenamos tarjetas.
- **Backups automáticos diarios** con cifrado.

### Medidas organizativas

- Principio de mínimo privilegio.
- Formación periódica en protección de datos.
- Procedimiento de gestión de incidentes (notificación AEPD en 72h, art. 33 RGPD).
- Evaluaciones de Impacto (EIPD) para tratamientos de alto riesgo.
- Auditorías periódicas de seguridad.

---

## 9. Derechos de los Interesados

De conformidad con los artículos 15 a 22 del RGPD y los artículos 12 a 18 de la LOPDGDD:

| Derecho | Descripción | Art. RGPD |
|---------|-------------|-----------|
| **Acceso** | Obtener confirmación de si se tratan sus datos y acceder a ellos. | Art. 15 |
| **Rectificación** | Corrección de datos inexactos o incompletos. | Art. 16 |
| **Supresión** («derecho al olvido») | Eliminación cuando ya no sean necesarios, revoque el consentimiento o se oponga. | Art. 17 |
| **Limitación del tratamiento** | Restricción en determinadas circunstancias. | Art. 18 |
| **Portabilidad** | Recibir datos en formato estructurado (JSON/CSV) y transmitirlos a otro responsable. | Art. 20 |
| **Oposición** | Oponerse al tratamiento, especialmente basado en interés legítimo. | Art. 21 |
| **No decisiones automatizadas** | No ser sometido a decisiones exclusivamente automatizadas. *Fluix CRM no realiza profiling.* | Art. 22 |
| **Retirada del consentimiento** | En cualquier momento, sin afectar la licitud del tratamiento previo. | Art. 7.3 |

### 9.1. Cómo ejercer sus derechos

- **📧 Email:** privacidad@fluixtech.com
- **📧 DPO:** dpo@fluixtech.com
- **📮 Correo postal:** Fluixtech S.L. – Departamento de Privacidad, Guadalajara, España

Su solicitud deberá incluir:
1. Nombre y apellidos.
2. Copia de DNI/NIE.
3. Descripción del derecho a ejercer.
4. Dirección de contacto para respuesta.

**Plazo de respuesta:** Máximo 1 mes (prorrogable 2 meses más en casos complejos, art. 12.3 RGPD).

### 9.2. Reclamación ante la autoridad de control

**Agencia Española de Protección de Datos (AEPD)**  
C/ Jorge Juan, 6 – 28001 Madrid  
Web: [www.aepd.es](https://www.aepd.es)  
Teléfono: 901 100 099 / 91 266 35 17

---

## 10. Tratamiento de Datos de Menores

Fluix CRM es B2B y **no está dirigida a menores de 16 años**. No recopilamos conscientemente datos de menores. Si detecta este caso, contacte privacidad@fluixtech.com.

---

## 11. Datos de Geolocalización

- La geolocalización **solo se captura en el momento exacto del fichaje** (entrada/salida), **nunca de forma continua**.
- La activación es decisión de la empresa cliente, que debe informar a sus empleados (art. 90 LOPDGDD).
- El empleado será informado de forma visible en la App cuando se capture su ubicación.
- Conservación: **4 años** (art. 34.9 ET).

---

## 12. Cookies y Tecnologías Similares

| Tipo | Finalidad | Duración | Base legal |
|------|-----------|----------|------------|
| Técnicas/necesarias | Sesión, preferencias, seguridad | Sesión / 12 meses | Exentas (art. 22.2 LSSI) |
| Autenticación (Firebase) | Login y tokens de acceso | Según Firebase Auth | Exentas (necesarias) |
| Analíticas (si se implementan) | Estadísticas de uso | Hasta 24 meses | Art. 6.1.a) – Consentimiento |

Banner de consentimiento conforme a la LSSI-CE para cookies no estrictamente necesarias.

---

## 13. Contrato de Encargado del Tratamiento

Cuando Fluixtech actúa como Encargado, se formaliza contrato conforme al art. 28 RGPD que incluye:

- Descripción del tratamiento (objeto, duración, naturaleza, finalidad).
- Tratamiento solo según instrucciones documentadas del Responsable.
- Confidencialidad del personal.
- Medidas técnicas y organizativas adecuadas.
- Subencargados autorizados: Firebase, Stripe, proveedor SMTP.
- Colaboración en ejercicio de derechos.
- Notificación de brechas sin dilación indebida.
- Devolución/supresión de datos al finalizar el servicio.

---

## 14. Evaluación de Impacto (EIPD)

Fluixtech mantiene una EIPD actualizada (art. 35 RGPD) que cubre:

- Descripción sistemática de los tratamientos.
- Evaluación de necesidad y proporcionalidad.
- Evaluación de riesgos.
- Medidas para afrontar los riesgos.

---

## 15. Registro de Actividades de Tratamiento

Conforme al art. 30 RGPD, disponible para la AEPD en caso de requerimiento.

---

## 16. Notificación de Brechas de Seguridad

1. Notificación a la **AEPD** en máximo **72 horas** (art. 33 RGPD).
2. Comunicación a los **afectados** si hay alto riesgo (art. 34 RGPD).
3. Como Encargado, notificación al Responsable **sin dilación indebida**.

---

## 17. Enlaces a Terceros

- [Google Privacy Policy](https://policies.google.com/privacy)
- [Firebase Privacy](https://firebase.google.com/support/privacy)
- [Stripe Privacy](https://stripe.com/es/privacy)

---

## 18. Modificaciones de esta Política

Las modificaciones se notifican mediante:
- Publicación actualizada en fluixtech.com/privacidad.
- Notificación in-app.
- Email en caso de cambios sustanciales.

---

## 19. Legislación Aplicable

- **Reglamento (UE) 2016/679** (RGPD).
- **Ley Orgánica 3/2018** (LOPDGDD).
- **Ley 34/2002** (LSSI-CE).
- **Real Decreto-ley 5/2018**.

Jurisdicción: Juzgados y Tribunales del domicilio del usuario.

---

## 20. Contacto

| | |
|---|---|
| **Responsable** | Fluixtech S.L. |
| **CIF** | B2699752OCHP |
| **Dirección** | Guadalajara, España |
| **Email general** | info@fluixtech.com |
| **Email privacidad** | privacidad@fluixtech.com |
| **DPO** | dpo@fluixtech.com |
| **Web** | https://fluixtech.com |

---

© 2026 Fluixtech S.L. — Todos los derechos reservados.  
Última actualización: 6 de abril de 2026 — Versión 2.0

