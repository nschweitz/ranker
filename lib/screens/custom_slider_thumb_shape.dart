import 'package:flutter/material.dart';

class CustomSliderThumbShape extends SliderComponentShape {
  final double thumbRadius;
  final double value;
  final Color color;
  final String aspectName;
  final bool isDragging;

  const CustomSliderThumbShape({
    required this.thumbRadius,
    required this.value,
    required this.color,
    required this.aspectName,
    required this.isDragging,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius + (isDragging ? 25 : 0)); // Extra space when dragging
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    // Draw the thumb circle
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, thumbRadius, paint);

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(center, thumbRadius, borderPaint);

    // Draw the aspect name and value pill
    final pillText = '$aspectName: ${this.value.toStringAsFixed(1)}';
    final textSpan = TextSpan(
      text: pillText,
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Position the pill - inline when not dragging, above when dragging
    final pillVerticalOffset = isDragging ? -thumbRadius - 30 : 0;
    final pillCenter = Offset(center.dx, center.dy + pillVerticalOffset);
    
    // Draw pill background
    final pillWidth = textPainter.width + 16;
    final pillHeight = textPainter.height + 8;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: pillCenter,
        width: pillWidth,
        height: pillHeight,
      ),
      Radius.circular(pillHeight / 2),
    );
    
    final pillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(pillRect, pillPaint);
    
    // Draw pill border
    final pillBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    canvas.drawRRect(pillRect, pillBorderPaint);
    
    // Draw text
    final textOffset = Offset(
      pillCenter.dx - textPainter.width / 2,
      pillCenter.dy - textPainter.height / 2,
    );
    
    textPainter.paint(canvas, textOffset);
  }
}