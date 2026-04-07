// Enums principales del sistema
enum RolUsuario {
  propietario,
  admin,
  staff,
}

enum EstadoSuscripcion {
  activa,
  vencida,
  pendiente,
  suspendida,
}

enum EstadoReserva {
  pendiente,
  confirmada,
  cancelada,
  completada,
}

enum TipoNotificacion {
  reservaNueva,
  cancelacion,
  nuevaResena,
  suscripcionVencimiento,
  recordatorioReserva,
}

enum ModuloEmpresa {
  reservas,
  clientes,
  servicios,
  ofertas,
  valoraciones,
  finanzas,
  empleados,
  estadisticas,
  alertas,
}

// Extensions para obtener nombres en español
extension RolUsuarioExtension on RolUsuario {
  String get nombre {
    switch (this) {
      case RolUsuario.propietario:
        return 'Propietario';
      case RolUsuario.admin:
        return 'Administrador';
      case RolUsuario.staff:
        return 'Personal';
    }
  }

  String get descripcion {
    switch (this) {
      case RolUsuario.propietario:
        return 'Acceso total al sistema';
      case RolUsuario.admin:
        return 'Gestión de clientes, reservas y servicios';
      case RolUsuario.staff:
        return 'Visualización y gestión básica';
    }
  }
}

extension EstadoSuscripcionExtension on EstadoSuscripcion {
  String get nombre {
    switch (this) {
      case EstadoSuscripcion.activa:
        return 'Activa';
      case EstadoSuscripcion.vencida:
        return 'Vencida';
      case EstadoSuscripcion.pendiente:
        return 'Pendiente';
      case EstadoSuscripcion.suspendida:
        return 'Suspendida';
    }
  }
}

extension EstadoReservaExtension on EstadoReserva {
  String get nombre {
    switch (this) {
      case EstadoReserva.pendiente:
        return 'Pendiente';
      case EstadoReserva.confirmada:
        return 'Confirmada';
      case EstadoReserva.cancelada:
        return 'Cancelada';
      case EstadoReserva.completada:
        return 'Completada';
    }
  }
}

extension ModuloEmpresaExtension on ModuloEmpresa {
  String get nombre {
    switch (this) {
      case ModuloEmpresa.reservas:
        return 'Reservas';
      case ModuloEmpresa.clientes:
        return 'Clientes';
      case ModuloEmpresa.servicios:
        return 'Servicios';
      case ModuloEmpresa.ofertas:
        return 'Ofertas';
      case ModuloEmpresa.valoraciones:
        return 'Valoraciones';
      case ModuloEmpresa.finanzas:
        return 'Finanzas';
      case ModuloEmpresa.empleados:
        return 'Empleados';
      case ModuloEmpresa.estadisticas:
        return 'Estadísticas';
      case ModuloEmpresa.alertas:
        return 'Alertas';
    }
  }

  String get icono {
    switch (this) {
      case ModuloEmpresa.reservas:
        return 'calendar_today';
      case ModuloEmpresa.clientes:
        return 'people';
      case ModuloEmpresa.servicios:
        return 'room_service';
      case ModuloEmpresa.ofertas:
        return 'local_offer';
      case ModuloEmpresa.valoraciones:
        return 'star';
      case ModuloEmpresa.finanzas:
        return 'account_balance';
      case ModuloEmpresa.empleados:
        return 'badge';
      case ModuloEmpresa.estadisticas:
        return 'analytics';
      case ModuloEmpresa.alertas:
        return 'notifications';
    }
  }

  String get descripcion {
    switch (this) {
      case ModuloEmpresa.reservas:
        return 'Gestión de citas y reservas';
      case ModuloEmpresa.clientes:
        return 'Base de datos de clientes';
      case ModuloEmpresa.servicios:
        return 'Catálogo de servicios';
      case ModuloEmpresa.ofertas:
        return 'Promociones y descuentos';
      case ModuloEmpresa.valoraciones:
        return 'Reseñas y calificaciones';
      case ModuloEmpresa.finanzas:
        return 'Ingresos y reportes';
      case ModuloEmpresa.empleados:
        return 'Gestión de personal';
      case ModuloEmpresa.estadisticas:
        return 'Métricas y KPIs';
      case ModuloEmpresa.alertas:
        return 'Notificaciones importantes';
    }
  }
}
