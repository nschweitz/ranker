import 'package:flutter/material.dart';
import 'song_symbol_painter.dart';

class SongGlyph extends StatelessWidget {
  final double quality;
  final double valence;
  final double intensity;
  final double accessibility;
  final double syntheticness;
  final double size;

  const SongGlyph({
    super.key,
    required this.quality,
    required this.valence,
    required this.intensity,
    required this.accessibility,
    required this.syntheticness,
    this.size = 64.0,
  });

  @override
  Widget build(BuildContext context) {
    return SongSymbolWidget(
      valence: valence,
      intensity: intensity,
      quality: quality,
      accessibility: accessibility,
      syntheticness: syntheticness,
      size: size,
    );
  }
}

