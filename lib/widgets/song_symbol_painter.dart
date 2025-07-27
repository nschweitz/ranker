import 'package:flutter/material.dart';
import 'dart:math' as math;

class SongSymbolWidget extends StatelessWidget {
  final double valence;    // -9 to 9
  final double intensity;  // -9 to 9
  final double quality;    // -9 to 9
  final double accessibility; // -9 to 9
  final double syntheticness; // -9 to 9
  final double size;

  const SongSymbolWidget({
    super.key,
    required this.valence,
    required this.intensity,
    required this.quality,
    required this.accessibility,
    required this.syntheticness,
    this.size = 64.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: SongSymbolPainter(
        valence: valence,
        intensity: intensity,
        quality: quality,
        accessibility: accessibility,
        syntheticness: syntheticness,
      ),
    );
  }
}

class SongSymbolPainter extends CustomPainter {
  final double valence;
  final double intensity;
  final double quality;
  final double accessibility;
  final double syntheticness;

  SongSymbolPainter({
    required this.valence,
    required this.intensity,
    required this.quality,
    required this.accessibility,
    required this.syntheticness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Normalize values from [-9, 9] to [0, 1]
    final normalizedValence = (valence + 9) / 18;
    final normalizedIntensity = (intensity + 9) / 18;
    final normalizedQuality = (quality + 9) / 18;
    final normalizedAccessibility = (accessibility + 9) / 18;
    final normalizedSyntheticness = (syntheticness + 9) / 18;

    // Calculate properties based on the JavaScript logic
    final valenceHue = _getValenceHue(normalizedValence);
    final rings = _getRingCount(normalizedQuality);
    final starPoints = _getStarPoints(normalizedIntensity);
    final baseRadius = size.width * 0.4375; // 28/64 ratio from original

    // Draw multiple rings both inside and outside the base shape
    for (int ring = 0; ring < rings; ring++) {
      final ringOffset = ring * 2.0;
      
      // Outer rings (expanding outward) 
      final outerRingRadius = baseRadius + ringOffset;
      final outerInnerRadius = outerRingRadius * 0.6;
      
      if (outerRingRadius <= size.width / 2 - 2) { // Keep within bounds
        _drawStarPath(
          canvas,
          center,
          outerRingRadius,
          outerInnerRadius,
          starPoints,
          normalizedSyntheticness,
          valenceHue,
          math.max(0.1, (rings - ring) / rings * 0.8),
          1.0,
        );
      }
      
      // Inner rings (contracting inward)
      final innerRingRadius = baseRadius - ringOffset * 1.5;
      final innerInnerRadius = innerRingRadius * 0.6;
      
      if (innerRingRadius > 2) {
        _drawStarPath(
          canvas,
          center,
          innerRingRadius,
          innerInnerRadius,
          starPoints,
          normalizedSyntheticness,
          valenceHue,
          math.max(0.1, (rings - ring) / rings * 0.6),
          1.0,
        );
      }
    }
    
    // Add accessibility outer ring
    _addAccessibilityRing(canvas, center, valenceHue, baseRadius, rings, starPoints, normalizedAccessibility, size.width / 2);
  }

  double _getValenceHue(double normalizedValence) {
    // Convert back to original [-9, 9] range to check for unrated (0.0)
    final valenceOriginal = normalizedValence * 18 - 9;
    
    if (valenceOriginal == 0.0) {
      // Red for unrated (0.0)
      return 0.0;
    } else if (valenceOriginal < 0) {
      // Blue for negative values (-9 to 0)
      // -9 = pure blue (240°), approaching 0 = less blue
      return 240.0 - (valenceOriginal + 9) / 9 * 40; // 240° to 200°
    } else {
      // Yellow for positive values (0 to 9)
      // 0+ = moving toward yellow, 9 = pure yellow (60°)
      return 200.0 - (valenceOriginal / 9) * 140; // 200° to 60°
    }
  }

  int _getRingCount(double normalizedQuality) {
    // Since quality is never negative for liked songs, adjust the scaling
    // Minimal effect until ~2 (normalized ~0.61), then ramp up dramatically
    final qualityOriginal = normalizedQuality * 18 - 9; // Convert back to [-9, 9] range
    
    if (qualityOriginal < 2.0) {
      // Minimal rings for quality < 2
      return 1 + (qualityOriginal / 2.0 * 2).round(); // 1-3 rings
    } else {
      // Dramatic increase for quality >= 2
      final excessQuality = qualityOriginal - 2.0; // 0-7 range
      return 3 + (excessQuality / 7.0 * 9).round(); // 3-12 rings
    }
  }

  int _getStarPoints(double normalizedIntensity) {
    // Convert back to [-9, 9] range to work with original intensity values
    final intensityOriginal = normalizedIntensity * 18 - 9;
    
    if (intensityOriginal <= 3.0) {
      // Barely increase until intensity 3: 3-5 points for intensity -9 to 3
      final progress = (intensityOriginal + 9) / 12; // 0-1 for intensity -9 to 3
      return 3 + (progress * 2).round(); // 3-5 points
    } else {
      // Exponential scale after intensity 3: 5-15 points for intensity 3 to 9
      final excessIntensity = intensityOriginal - 3.0; // 0-6 range
      final normalizedExcess = excessIntensity / 6.0; // 0-1 range
      final exponentialValue = math.pow(normalizedExcess, 2.0); // Exponential curve
      return 5 + (exponentialValue * 10).round(); // 5-15 points
    }
  }

  void _addAccessibilityRing(Canvas canvas, Offset center, double valenceHue, double baseRadius, int rings, int starPoints, double accessibility, double maxRadius) {
    // Position outer ring closer to prevent cutoff
    final outerRingRadius = math.min(maxRadius - 2, baseRadius + rings * 2 + 2);
    
    // Smooth amplitude fade - spikes fade to 0 as accessibility approaches 1
    // Use a more gradual transition that utilizes more of the visual range
    final spikeHeight = math.pow(1 - accessibility, 1.2).toDouble() * 15;
    
    // Use more points for smoother rings when star points are low
    final ringPoints = math.max(starPoints, 12);
    
    _drawAccessibilitySpikes(
      canvas,
      center,
      outerRingRadius,
      ringPoints,
      spikeHeight,
      valenceHue,
    );
  }

  void _drawAccessibilitySpikes(Canvas canvas, Offset center, double baseRadius, int spikeCount, double spikeHeight, double valenceHue) {
    final path = Path();
    final angleStep = (math.pi * 2) / spikeCount;
    
    for (int i = 0; i <= spikeCount; i++) {
      final angle = i * angleStep;
      final x = center.dx + math.cos(angle) * baseRadius;
      final y = center.dy + math.sin(angle) * baseRadius;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Add spike
        final spikeAngle = angle - angleStep / 2;
        final spikeX = center.dx + math.cos(spikeAngle) * (baseRadius + spikeHeight);
        final spikeY = center.dy + math.sin(spikeAngle) * (baseRadius + spikeHeight);
        
        path.lineTo(spikeX, spikeY);
        path.lineTo(x, y);
      }
    }
    
    path.close();
    final paint = Paint()
      ..color = HSLColor.fromAHSL(0.8, valenceHue, 0.6, 0.7).toColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawPath(path, paint);
  }

  void _drawStarPath(Canvas canvas, Offset center, double outerRadius, double innerRadius, int points, double syntheticness, double valenceHue, double opacity, double strokeWidth) {
    final path = Path();
    final angleStep = (math.pi * 2) / points;
    
    for (int i = 0; i <= points * 2; i++) {
      final angle = i * angleStep / 2;
      final isOuter = i % 2 == 0;
      final radius = isOuter ? outerRadius : innerRadius;
      
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        if (syntheticness < 1.0) {
          // Add curved paths for organic feel
          final prevAngle = (i - 1) * angleStep / 2;
          final prevRadius = ((i - 1) % 2 == 0) ? outerRadius : innerRadius;
          final prevX = center.dx + math.cos(prevAngle) * prevRadius;
          final prevY = center.dy + math.sin(prevAngle) * prevRadius;
          
          final controlDistance = 10 * (1 - syntheticness);
          final controlX1 = prevX + math.cos(prevAngle + math.pi / 2) * controlDistance;
          final controlY1 = prevY + math.sin(prevAngle + math.pi / 2) * controlDistance;
          final controlX2 = x + math.cos(angle - math.pi / 2) * controlDistance;
          final controlY2 = y + math.sin(angle - math.pi / 2) * controlDistance;
          
          path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    }
    
    path.close();
    
    final paint = Paint()
      ..color = HSLColor.fromAHSL(opacity, valenceHue, 0.8, 0.6).toColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SongSymbolPainter oldDelegate) {
    return oldDelegate.valence != valence ||
        oldDelegate.intensity != intensity ||
        oldDelegate.quality != quality ||
        oldDelegate.accessibility != accessibility ||
        oldDelegate.syntheticness != syntheticness;
  }
}