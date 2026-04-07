enum PerfilSancionLgt {
  productorComercializador,
  usuarioSistema,
}

class Lgt201BisRiesgos {
  static String resumenRiesgo(PerfilSancionLgt perfil) {
    switch (perfil) {
      case PerfilSancionLgt.productorComercializador:
        return 'Art. 201 bis.1 LGT: hasta 150.000 EUR por ejercicio y por tipo de sistema no conforme; 1.000 EUR por sistema sin certificacion obligatoria.';
      case PerfilSancionLgt.usuarioSistema:
        return 'Art. 201 bis.2 LGT: hasta 50.000 EUR por ejercicio por tener/usar sistema no conforme o alterado.';
    }
  }

  static String obligacionBase29_2j() {
    return 'Art. 29.2.j LGT: integridad, conservacion, accesibilidad, legibilidad, trazabilidad e inalterabilidad sin omisiones ni alteraciones sin anotacion.';
  }
}

