import 'package:flutter/material.dart';

import 'em_tokens.dart';

/// ThemeData global de Exchange Monitor.
///
/// Fija el contrato del sistema para todo lo que Material dibuja por su cuenta
/// —selector de fechas, chips, switches, sheets, snackbars—, que es donde la
/// app se delataba: el date range picker salía en inglés, con bloques
/// rectangulares y un turquesa que no existe en la paleta.
///
/// Ver [EmColors] para la dirección de diseño.
abstract final class EmTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.dark(
      // El "primario" del sistema es una superficie clara, no un color de
      // marca: en esta app seleccionar es aclarar, no teñir.
      primary: EmColors.textPrimary,
      onPrimary: EmColors.bg,
      secondary: EmColors.surfaceTop,
      onSecondary: EmColors.textPrimary,
      surface: EmColors.surface,
      onSurface: EmColors.textPrimary,
      surfaceContainerHighest: EmColors.surfaceHigh,
      error: EmColors.down,
      onError: EmColors.bg,
      outline: EmColors.strokeStrong,
      outlineVariant: EmColors.stroke,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: EmColors.bg,
      canvasColor: EmColors.bg,
      splashFactory: InkSparkle.splashFactory,

      textTheme: TextTheme(
        displayLarge: EmText.display,
        displayMedium: EmText.displaySmall,
        titleLarge: EmText.title,
        titleMedium: EmText.headline,
        bodyLarge: EmText.body,
        bodyMedium: EmText.rowLabel,
        bodySmall: EmText.meta,
        labelLarge: EmText.label,
        labelSmall: EmText.section,
      ),

      iconTheme: const IconThemeData(color: EmColors.textSecondary, size: 21),

      dividerTheme: const DividerThemeData(
        color: EmColors.strokeSoft,
        thickness: 1,
        space: 1,
      ),

      // La barra comparte el fondo del lienzo: pintarla de otro color partía la
      // pantalla en "mundo de la barra" y "mundo del contenido".
      appBarTheme: AppBarTheme(
        backgroundColor: EmColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: EmColors.textPrimary,
        titleTextStyle: EmText.title,
        iconTheme: const IconThemeData(color: EmColors.textSecondary, size: 21),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: EmColors.bg,
        selectedItemColor: EmColors.textPrimary,
        unselectedItemColor: EmColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      cardTheme: CardThemeData(
        color: EmColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EmRadii.card),
          side: const BorderSide(color: EmColors.stroke),
        ),
      ),

      // Seleccionado = un escalón más de superficie y el borde firmado.
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: EmColors.surfaceTop,
        labelStyle: EmText.label,
        secondaryLabelStyle: EmText.label.copyWith(color: EmColors.textPrimary),
        side: const BorderSide(color: EmColors.stroke),
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: EmSpace.sm, vertical: EmSpace.xs),
      ),

      switchTheme: SwitchThemeData(
        // El estado se lee por VALOR (claro/oscuro), no sólo por color: sirve
        // igual con poca luz y con daltonismo.
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? EmColors.bg
              : EmColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? EmColors.textPrimary
              : EmColors.surfaceSunken,
        ),
        // Un switch apagado DEBE verse: sin borde se funde con la card y parece
        // que no hay control.
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : EmColors.strokeStrong,
        ),
        trackOutlineWidth: const WidgetStatePropertyAll(1),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: EmColors.surface,
        modalBackgroundColor: EmColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(EmRadii.sheet)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: EmColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EmRadii.sheet),
          side: const BorderSide(color: EmColors.stroke),
        ),
        titleTextStyle: EmText.title,
        contentTextStyle: EmText.body,
      ),

      // Éste es el que se delataba: sin vestir salía en inglés y con un
      // turquesa ajeno a la app.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: EmColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        headerBackgroundColor: EmColors.bg,
        headerForegroundColor: EmColors.textPrimary,
        headerHeadlineStyle: EmText.title,
        headerHelpStyle: EmText.label,
        weekdayStyle: EmText.meta,
        dayStyle: EmText.rowLabel,
        yearStyle: EmText.rowLabel,
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? EmColors.bg
              : EmColors.textPrimary,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? EmColors.textPrimary
              : Colors.transparent,
        ),
        todayForegroundColor: const WidgetStatePropertyAll(EmColors.textPrimary),
        todayBorder: const BorderSide(color: EmColors.strokeStrong),
        rangeSelectionBackgroundColor: EmColors.surfaceHigh,
        rangePickerBackgroundColor: EmColors.bg,
        rangePickerHeaderBackgroundColor: EmColors.bg,
        rangePickerHeaderForegroundColor: EmColors.textPrimary,
        rangePickerHeaderHeadlineStyle: EmText.title,
        rangePickerHeaderHelpStyle: EmText.label,
        rangePickerElevation: 0,
        rangePickerSurfaceTintColor: Colors.transparent,
        dividerColor: EmColors.stroke,
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: EmColors.textSecondary),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: EmColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EmRadii.sheet)),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: EmColors.surfaceTop,
        contentTextStyle: EmText.body,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EmRadii.control),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EmColors.textPrimary,
          foregroundColor: EmColors.bg,
          disabledBackgroundColor: EmColors.surfaceHigh,
          disabledForegroundColor: EmColors.textMuted,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: EmSpace.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EmRadii.control),
          ),
          textStyle: EmText.rowLabel.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: EmColors.textPrimary,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: EmColors.stroke),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EmRadii.control),
          ),
          textStyle: EmText.rowLabel.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: EmColors.textPrimary,
          textStyle: EmText.label.copyWith(color: EmColors.textPrimary),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EmColors.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: EmSpace.lg,
          vertical: EmSpace.lg,
        ),
        border: _inputBorder(EmColors.stroke),
        enabledBorder: _inputBorder(EmColors.stroke),
        focusedBorder: _inputBorder(EmColors.strokeStrong),
        errorBorder: _inputBorder(EmColors.down),
        focusedErrorBorder: _inputBorder(EmColors.down),
        labelStyle: EmText.label,
        floatingLabelStyle: EmText.label.copyWith(color: EmColors.textSecondary),
        hintStyle: EmText.body.copyWith(color: EmColors.textMuted),
        errorStyle: EmText.meta.copyWith(color: EmColors.down),
        prefixIconColor: EmColors.textTertiary,
        suffixIconColor: EmColors.textTertiary,
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: EmColors.textSecondary,
        textColor: EmColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: EmSpace.screen),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: EmColors.textSecondary,
        linearTrackColor: EmColors.surfaceHigh,
        circularTrackColor: Colors.transparent,
      ),

      // Sin ripple de color: en esta paleta un splash tintado se lee como error.
      splashColor: EmColors.stroke,
      highlightColor: EmColors.strokeSoft,
    );
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(EmRadii.control),
        borderSide: BorderSide(color: color),
      );
}
