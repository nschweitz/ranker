import 'package:flutter/material.dart';
import '../services/spotify_liked_songs_service.dart';

class GradientLinePainter extends CustomPainter {
  final double? qualityValue;
  final double? valenceValue;
  final double? intensityValue;
  final double? accessibilityValue;
  final double? syntheticValue;

  GradientLinePainter({
    this.qualityValue,
    this.valenceValue,
    this.intensityValue,
    this.accessibilityValue,
    this.syntheticValue,
  });

  Color _getColorForValue(double? value) {
    if (value == null) return Colors.grey;
    if (value == 0.0) return Colors.red;
    // Normalize value from [-9, 9] to [0, 1]
    final normalized = (value + 9) / 18;
    return Color.lerp(Colors.blue, Colors.yellow, normalized) ?? Colors.grey;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final segmentWidth = width / 4; // 4 segments between 5 points

    // Define positions: Q at 0%, V at 25%, I at 50%, A at 75%, S at 100%
    final positions = [0.0, 0.25, 0.5, 0.75, 1.0];
    final values = [qualityValue, valenceValue, intensityValue, accessibilityValue, syntheticValue];
    final colors = values.map(_getColorForValue).toList();

    // Draw gradient segments
    for (int i = 0; i < 4; i++) {
      final startX = width * positions[i];
      final endX = width * positions[i + 1];
      
      // Create gradient between two adjacent colors
      final gradient = LinearGradient(
        colors: [colors[i], colors[i + 1]],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
      
      final rect = Rect.fromLTWH(startX, 0, endX - startX, size.height);
      paint.shader = gradient.createShader(rect);
      
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}

class SongListItem extends StatelessWidget {
  final LikedSong song;
  final VoidCallback? onTap;
  
  const SongListItem({super.key, required this.song, this.onTap});

  Color _getColorForValue(double? value) {
    if (value == null) return Colors.grey;
    if (value == 0.0) return Colors.red;
    // Interpolate between blue (-9) and yellow (9)
    // Normalize value from [-9, 9] to [0, 1]
    final normalized = (value + 9) / 18;
    return Color.lerp(Colors.blue, Colors.yellow, normalized) ?? Colors.grey;
  }

  Widget _buildGradientLine() {
    if (song.qualityRating == null && song.valenceRating == null && 
        song.intensityRating == null && song.accessibilityRating == null && 
        song.syntheticRating == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 1,
      margin: const EdgeInsets.only(top: 4),
      child: CustomPaint(
        painter: GradientLinePainter(
          qualityValue: song.qualityRating,
          valenceValue: song.valenceRating,
          intensityValue: song.intensityRating,
          accessibilityValue: song.accessibilityRating,
          syntheticValue: song.syntheticRating,
        ),
        child: Container(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final artistsText = song.artists.join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: ListTile(
        dense: true,
        onTap: onTap,
        title: Text(
          song.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              artistsText,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            _buildGradientLine(),
          ],
        ),
      ),
    );
  }
}
