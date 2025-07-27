import 'package:flutter/material.dart';
import '../services/spotify_liked_songs_service.dart';

class SongListItem extends StatelessWidget {
  final LikedSong song;
  final VoidCallback? onTap;
  
  const SongListItem({super.key, required this.song, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Pre-calculate formatted strings to avoid computation during scrolling
    final formattedDate = song.addedAt.toLocal().toString().split(' ')[0];
    final minutes = (song.durationMs / 60000).floor();
    final seconds = ((song.durationMs % 60000) / 1000).floor();
    final formattedDuration = '$minutes:${seconds.toString().padLeft(2, '0')}';
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
              '$artistsText • ${song.album}',
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (song.qualityRating != null || song.valenceRating != null || song.intensityRating != null || song.accessibilityRating != null || song.syntheticRating != null)
              Row(
                children: [
                  if (song.qualityRating != null) 
                    Text('Q:${song.qualityRating!.toStringAsFixed(1)}', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                  if (song.qualityRating != null && (song.valenceRating != null || song.intensityRating != null || song.accessibilityRating != null || song.syntheticRating != null))
                    const Text(' ', style: TextStyle(fontSize: 10)),
                  if (song.valenceRating != null)
                    Text('V:${song.valenceRating!.toStringAsFixed(1)}', style: const TextStyle(fontSize: 10, color: Colors.green)),
                  if (song.valenceRating != null && (song.intensityRating != null || song.accessibilityRating != null || song.syntheticRating != null))
                    const Text(' ', style: TextStyle(fontSize: 10)),
                  if (song.intensityRating != null)
                    Text('I:${song.intensityRating!.toStringAsFixed(1)}', style: const TextStyle(fontSize: 10, color: Colors.red)),
                  if (song.intensityRating != null && (song.accessibilityRating != null || song.syntheticRating != null))
                    const Text(' ', style: TextStyle(fontSize: 10)),
                  if (song.accessibilityRating != null)
                    Text('A:${song.accessibilityRating!.toStringAsFixed(1)}', style: const TextStyle(fontSize: 10, color: Colors.orange)),
                  if (song.accessibilityRating != null && song.syntheticRating != null)
                    const Text(' ', style: TextStyle(fontSize: 10)),
                  if (song.syntheticRating != null)
                    Text('S:${song.syntheticRating!.toStringAsFixed(1)}', style: const TextStyle(fontSize: 10, color: Colors.purple)),
                ],
              ),
          ],
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formattedDuration,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            Text(
              formattedDate,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}