import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system de Exchange Monitor.
///
/// DIRECCIÓN: un estado de cuenta que se lee de reojo. Se abre muchas veces por
/// día, en la calle, por tres segundos, para responder una sola pregunta: cómo
/// viene lo mío. Desde acá se leen decisiones, no se opera. De eso se deriva
/// TODO lo demás:
///
///  - Fondo neutro FRÍO y quieto, sin marca. La app no tiene color propio en
///    pantalla porque el único color que puede aparecer es el del dinero.
///  - El color es del dinero: [up] y [down] se reservan para una sola cosa —
///    si la plata sube o baja. Ningún otro elemento puede usarlos.
///  - Un tercer color y sólo uno: [flow], el capital que entra o sale por tu
///    mano. Un depósito no es una ganancia, y la app deja de mentir cuando los
///    distingue.
///  - Seleccionar es ACLARAR: lo activo sube un escalón de superficie y firma
///    el borde. Nunca un tinte de color — eso deja el hue libre para lo que
///    importa.
///  - UNA sola estrategia de profundidad: escalones de superficie + hairlines.
///    Las sombras existen sólo para lo que de verdad flota (sheets, diálogos).
///
/// CONTRATO: ningún widget inventa colores, radios ni espaciados. Todo sale de
/// acá. Si algo no está, se agrega acá — no se hardcodea en la vista.
abstract final class EmColors {
  // ---------------------------------------------------------------------
  // Superficies. Una sola escala de elevación, neutra fría. Cada escalón son
  // ~4 puntos de luminosidad: se siente, no se ve.
  // ---------------------------------------------------------------------

  /// L0 · lienzo de la app. TODAS las pantallas usan este fondo — sin
  /// excepciones, sin gradientes propios.
  static const bg = Color(0xFF0C0D0F);

  /// L1 · cards, sheets, barras.
  static const surface = Color(0xFF141518);

  /// L2 · inputs, chips, tracks, estados hover.
  static const surfaceHigh = Color(0xFF1C1E22);

  /// L3 · lo seleccionado, menús, popovers, thumbs.
  static const surfaceTop = Color(0xFF24272C);

  /// Superficie HUNDIDA (tracks vacíos, huecos). Más oscura que el lienzo.
  static const surfaceSunken = Color(0xFF08090A);

  // ---------------------------------------------------------------------
  // Hairlines. Un borde no debe verse; debe encontrarse cuando se lo busca.
  // ---------------------------------------------------------------------

  /// Separación interna entre filas de una lista.
  static const strokeSoft = Color(0x0AFFFFFF);

  /// Borde estándar de card, chip, control.
  static const stroke = Color(0x14FFFFFF);

  /// Énfasis: lo seleccionado, borde de foco.
  static const strokeStrong = Color(0x2EFFFFFF);

  // ---------------------------------------------------------------------
  // Color. Tres, y los tres significan algo. Desaturados: sobre un lienzo casi
  // negro un verde puro vibra y ensucia.
  // ---------------------------------------------------------------------

  /// SUBE. Se usa exclusivamente para variación de valor. Nada más.
  static const up = Color(0xFF5CBE92);

  /// BAJA. Se usa exclusivamente para variación de valor. Nada más.
  static const down = Color(0xFFE06B62);

  /// CAPITAL que entra o sale por mano del usuario: depósitos, retiros,
  /// transferencias. No es resultado — por eso no es ni verde ni rojo.
  static const flow = Color(0xFFD9A05B);

  /// Fill al 14% de cada semántico, para el cuadradito de ícono de una fila.
  static Color wash(Color c) => c.withValues(alpha: 0.14);

  // ---------------------------------------------------------------------
  // Texto. Cuatro niveles, un solo tono.
  // ---------------------------------------------------------------------
  static const textPrimary = Color(0xFFF2F3F5);
  static const textSecondary = Color(0xADF2F3F5);
  static const textTertiary = Color(0x73F2F3F5);
  static const textMuted = Color(0x47F2F3F5);

  // ---------------------------------------------------------------------
  // Marcas de terceros. El logo de cada moneda SÍ va en las listas: es lo que
  // permite reconocer una fila de un vistazo, que es de lo que se trata una app
  // que se lee de reojo. Lo que no puede pasar es que ese color se meta en el
  // resto de la fila —el dato, el porcentaje, el fondo—: ahí manda el color del
  // dinero. El logo ocupa su disco y nada más.
  // ---------------------------------------------------------------------
  static const brandBinance = Color(0xFFF0B90B);
  static const brandKraken = Color(0xFF5741D9);
  static const brandNexo = Color(0xFF1A4FD6);
  static const brandBitso = Color(0xFF00C853);

  static Color? brandOf(String exchange) {
    switch (exchange.toLowerCase()) {
      case 'binance':
        return brandBinance;
      case 'kraken':
        return brandKraken;
      case 'nexo':
      case 'nexo-pro':
      case 'nexo-manual':
        return brandNexo;
      case 'bitso':
        return brandBitso;
      default:
        return null;
    }
  }
}

/// Escala de espaciado. Base 4. Todo margen, padding y gap sale de acá — los
/// valores intermedios (3, 5, 7, 22…) son lo que hace que una interfaz se vea
/// "casi alineada".
abstract final class EmSpace {
  /// 4 · separación entre un ícono y su etiqueta.
  static const double xs = 4;

  /// 8 · gap dentro de un componente.
  static const double sm = 8;

  /// 12 · padding interno compacto, gap entre filas.
  static const double md = 12;

  /// 16 · padding de card.
  static const double lg = 16;

  /// 20 · margen lateral de pantalla.
  static const double screen = 20;

  /// 24 · separación entre grupos de contenido.
  static const double xl = 24;

  /// 32 · separación entre secciones.
  static const double xxl = 32;

  /// 48 · respiro mayor (estados vacíos).
  static const double xxxl = 48;
}

/// Radios. Cuatro pasos: cuanto más grande la superficie, más suave el canto.
/// Más cerrados que los de una app de consumo — un instrumento de lectura se
/// lee mejor con cantos firmes.
abstract final class EmRadii {
  /// 8 · chips, cuadraditos de ícono, badges.
  static const double sm = 8;

  /// 12 · controles, botones, tiles.
  static const double control = 12;

  /// 16 · cards.
  static const double card = 16;

  /// 24 · sheets y diálogos.
  static const double sheet = 24;

  static const double pill = 999;
}

/// Sombras. La profundidad la dan los escalones de superficie y los hairlines.
/// Esto existe únicamente para lo que de verdad flota sobre el contenido.
abstract final class EmShadows {
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x59000000), blurRadius: 28, offset: Offset(0, 10)),
  ];
}

/// Tipografía. UNA sola familia para texto y para datos.
///
/// SIN cifras tabulares, y es deliberado: en Schibsted Grotesk el juego
/// tabular lleva la coma y el punto al mismo ancho que un dígito, y "105.160,54"
/// termina leyéndose con los separadores sueltos —"105 . 160 , 54"— tanto a
/// 40 px como en una fila de lista. Se probó y se descartó. Lo que resuelve el
/// baile de un número que cambia en vivo es la alineación a la derecha de la
/// columna, que es como están todas las listas de la app.
///
/// Si algún día se cambia de familia, esto se puede revisar: hay que mirar la
/// puntuación, no sólo los dígitos.
abstract final class EmText {
  static TextStyle _base({
    required double size,
    required FontWeight weight,
    double? tracking,
    double? height,
    Color color = EmColors.textPrimary,
  }) {
    return GoogleFonts.schibstedGrotesk(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: tracking,
      height: height,
      color: color,
    );
  }

  /// 40 · el número protagonista de una pantalla.
  static TextStyle get display =>
      _base(size: 40, weight: FontWeight.w600, tracking: -1.4, height: 1.0);

  /// 34 · número protagonista de una pantalla secundaria.
  static TextStyle get displaySmall =>
      _base(size: 34, weight: FontWeight.w600, tracking: -1.1, height: 1.0);

  /// 20 · título de pantalla y de card grande.
  static TextStyle get title =>
      _base(size: 20, weight: FontWeight.w600, tracking: -0.4, height: 1.2);

  /// 17 · encabezado de bloque, nombre destacado.
  static TextStyle get headline =>
      _base(size: 17, weight: FontWeight.w600, tracking: -0.2, height: 1.25);

  /// 15 · texto corrido.
  static TextStyle get body => _base(size: 15, weight: FontWeight.w400, height: 1.35);

  /// 15 · el DATO de una fila (valor, precio, monto).
  static TextStyle get data =>
      _base(size: 15, weight: FontWeight.w600, tracking: -0.2, height: 1.2);

  /// 14 · etiqueta de una fila de lista.
  static TextStyle get rowLabel =>
      _base(size: 14, weight: FontWeight.w500, height: 1.25);

  /// 13 · etiqueta de control, texto secundario.
  static TextStyle get label =>
      _base(size: 13, weight: FontWeight.w500, height: 1.2, color: EmColors.textSecondary);

  /// 12 · metadato bajo una etiqueta (fecha, exchange, cantidad).
  static TextStyle get meta =>
      _base(size: 12, weight: FontWeight.w400, height: 1.3, color: EmColors.textTertiary);

  /// 11 · encabezado de sección. Usar SIEMPRE con .toUpperCase().
  static TextStyle get section => _base(
        size: 11,
        weight: FontWeight.w600,
        tracking: 1.1,
        height: 1.2,
        color: EmColors.textTertiary,
      );
}
