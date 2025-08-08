import 'dart:ui';

class PDFPageFormat {
  static const double A4_WIDTH = 595.0;
  static const double A4_HEIGHT = 842.0;

  // Display scaling factor to fit screen
  static const double DISPLAY_SCALE = 0.6;

  static Map<String, Size> get formats => {
    'A4': Size(A4_WIDTH * DISPLAY_SCALE, A4_HEIGHT * DISPLAY_SCALE),
  };
  static double get aspectRatioA4 => A4_WIDTH / A4_HEIGHT;
}