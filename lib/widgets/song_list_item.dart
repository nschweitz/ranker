import 'package:flutter/material.dart';
import '../services/spotify_liked_songs_service.dart';
import 'song_glyph.dart';


class SongListItem extends StatelessWidget {
  final LikedSong song;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  
  const SongListItem({super.key, required this.song, this.onTap, this.onLongPress});


  @override
  Widget build(BuildContext context) {
    final artistsText = song.artists.join(', ');
    
    // Check if song has all ratings for the glyph
    final hasAllRatings = song.qualityRating != null && 
                         song.valenceRating != null && 
                         song.intensityRating != null && 
                         song.accessibilityRating != null && 
                         song.syntheticRating != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: ListTile(
        dense: true,
        onTap: onTap,
        onLongPress: onLongPress,
        trailing: hasAllRatings 
          ? SongGlyph(
              quality: song.qualityRating!,
              valence: song.valenceRating!,
              intensity: song.intensityRating!,
              accessibility: song.accessibilityRating!,
              syntheticness: song.syntheticRating!,
              size: 48.0,
            )
          : null,
        title: Text(
          song.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          artistsText,
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
