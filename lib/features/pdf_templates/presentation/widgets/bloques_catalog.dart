import '../../domain/models/bloque_disponible.dart';
export '../../domain/models/bloque_disponible.dart';

const List<BloqueDisponible> kBloquesDisponibles = [
  BloqueDisponible(tipo:'header',         nombre:'Cabecera Empresa',  icono:'🏢', categoria:'Empresa',     propsDefault:{'mostrar_logo':true,'color_fondo':'#1565C0','color_texto':'#FFFFFF','padding':18.0,'border_radius':12.0}),
  BloqueDisponible(tipo:'footer',         nombre:'Pie de Página',     icono:'🔽', categoria:'Empresa',     propsDefault:{'contenido':'Generado con PlaneaG','tamano_fuente':7.0,'color_texto':'#BDBDBD'}),
  BloqueDisponible(tipo:'cliente',        nombre:'Datos del Cliente', icono:'👤', categoria:'Cliente',     propsDefault:{'titulo':'FACTURAR A:','mostrar_nif':true,'mostrar_direccion':true,'mostrar_email':true,'color_fondo':'#F5F9FF','border_radius':8.0}),
  BloqueDisponible(tipo:'info_documento', nombre:'Info Documento',    icono:'🧾', categoria:'Facturación', propsDefault:{'mostrar_numero':true,'mostrar_fecha_emision':true,'mostrar_fecha_vencimiento':true}),
  BloqueDisponible(tipo:'tabla_lineas',   nombre:'Tabla de Líneas',  icono:'📊', categoria:'Facturación', propsDefault:{'mostrar_cantidad':true,'mostrar_precio_unitario':true,'mostrar_iva':true,'color_cabecera':'#0D47A1','color_fila_par':'#FFFFFF','color_fila_impar':'#FAFBFC'}),
  BloqueDisponible(tipo:'totales',        nombre:'Totales',           icono:'💰', categoria:'Facturación', propsDefault:{'mostrar_base':true,'mostrar_iva':true,'mostrar_irpf':true,'mostrar_total':true}),
  BloqueDisponible(tipo:'forma_pago',     nombre:'Forma de Pago',    icono:'💳', categoria:'Facturación', propsDefault:{'mostrar_metodo':true,'mostrar_iban':true,'color_fondo':'#F5F9FF'}),
  BloqueDisponible(tipo:'qr_verifactu',   nombre:'QR Verifactu',     icono:'📱', categoria:'Facturación', propsDefault:{'tamano':57.0,'mostrar_etiqueta':true}),
  BloqueDisponible(tipo:'info_empleado',  nombre:'Info Empleado',    icono:'👷', categoria:'Fichajes',    propsDefault:{'mostrar_nombre':true,'mostrar_puesto':true,'mostrar_periodo':true}),
  BloqueDisponible(tipo:'tabla_fichajes', nombre:'Tabla Fichajes',   icono:'⏱️', categoria:'Fichajes',    propsDefault:{'mostrar_fecha':true,'mostrar_entrada':true,'mostrar_salida':true,'color_cabecera':'#0D47A1'}),
  BloqueDisponible(tipo:'resumen_horas',  nombre:'Resumen Horas',    icono:'📈', categoria:'Fichajes',    propsDefault:{'mostrar_total_horas':true,'mostrar_horas_extra':true,'mostrar_dias_trabajados':true}),
  BloqueDisponible(tipo:'indice',          nombre:'Índice / Sumario',  icono:'📋', categoria:'Genérico',    propsDefault:{'titulo':'ÍNDICE','mostrar_paginas':true,'tamano_fuente':9.0,'color_texto':'#000000','color_titulo':'#1565C0'}),
  BloqueDisponible(tipo:'notas',          nombre:'Notas',             icono:'📝', categoria:'Genérico',    propsDefault:{'placeholder':'Notas...','tamano_fuente':9.0,'color_texto':'#757575'}),
  BloqueDisponible(tipo:'texto_libre',    nombre:'Texto Libre',      icono:'✏️', categoria:'Genérico',    propsDefault:{'contenido':'Texto personalizado','tamano_fuente':10.0,'color_texto':'#000000','negrita':false,'cursiva':false}),
  BloqueDisponible(tipo:'separador',      nombre:'Separador',         icono:'➖', categoria:'Genérico',    propsDefault:{'color':'#E0E0E0','grosor':1.0,'margen_vertical':8.0}),
  BloqueDisponible(tipo:'espaciador',     nombre:'Espaciador',        icono:'⬜', categoria:'Genérico',    propsDefault:{'altura':16.0}),
];
