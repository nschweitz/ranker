import 'package:flutter/material.dart';
import '../services/spotify_liked_songs_service.dart';

class RatingScreenHelpers {
  static LikedSong? findClosestSongByRating(
    List<LikedSong> allSongs,
    String currentSongId,
    String parameter,
    double currentValue,
    bool findHigher,
  ) {
    List<LikedSong> validSongs = allSongs.where((song) {
      if (song.id == currentSongId) return false; // Exclude current song
      
      double? songValue;
      switch (parameter) {
        case 'quality':
          songValue = song.qualityRating;
          break;
        case 'valence':
          songValue = song.valenceRating;
          break;
        case 'intensity':
          songValue = song.intensityRating;
          break;
        case 'accessibility':
          songValue = song.accessibilityRating;
          break;
        case 'synthetic':
          songValue = song.syntheticRating;
          break;
      }
      
      if (songValue == null) return false;
      
      return findHigher ? songValue > currentValue : songValue < currentValue;
    }).toList();
    
    if (validSongs.isEmpty) return null;
    
    // Sort and return the closest one
    validSongs.sort((a, b) {
      double aValue = 0, bValue = 0;
      switch (parameter) {
        case 'quality':
          aValue = a.qualityRating!;
          bValue = b.qualityRating!;
          break;
        case 'valence':
          aValue = a.valenceRating!;
          bValue = b.valenceRating!;
          break;
        case 'intensity':
          aValue = a.intensityRating!;
          bValue = b.intensityRating!;
          break;
        case 'accessibility':
          aValue = a.accessibilityRating!;
          bValue = b.accessibilityRating!;
          break;
        case 'synthetic':
          aValue = a.syntheticRating!;
          bValue = b.syntheticRating!;
          break;
      }
      
      if (findHigher) {
        return aValue.compareTo(bValue); // Ascending for next higher
      } else {
        return bValue.compareTo(aValue); // Descending for next lower
      }
    });
    
    return validSongs.first;
  }

  static Widget buildCurrentSongCard(LikedSong song, String? activeParameter, double? currentValue) {
    return Card(
      elevation: 2,
      color: const Color(0xFF000000),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (activeParameter != null && currentValue != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            currentValue.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (activeParameter != null && currentValue != null)
                        const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          song.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song.artists.join(', '),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildReferenceSongCard(
    List<LikedSong> allSongs,
    String currentSongId,
    String? parameter,
    double? currentValue,
    bool findHigher,
  ) {
    // Show empty placeholder when no active slider
    if (parameter == null || currentValue == null) {
      return SizedBox(
        height: 64,
        child: Card(
          elevation: 0,
          color: const Color(0xFF000000),
          child: Container(),
        ),
      );
    }

    final song = findClosestSongByRating(
      allSongs,
      currentSongId,
      parameter,
      currentValue,
      findHigher,
    );
    
    if (song == null) {
      final direction = findHigher ? 'higher' : 'lower';
      return SizedBox(
        height: 64,
        child: Card(
          elevation: 1,
          color: const Color(0xFF000000),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No songs with $direction rating',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Get the song's rating for this parameter
    double songRating = 0;
    switch (parameter) {
      case 'quality':
        songRating = song.qualityRating!;
        break;
      case 'valence':
        songRating = song.valenceRating!;
        break;
      case 'intensity':
        songRating = song.intensityRating!;
        break;
      case 'accessibility':
        songRating = song.accessibilityRating!;
        break;
      case 'synthetic':
        songRating = song.syntheticRating!;
        break;
    }

    return SizedBox(
      height: 64,
      child: Card(
        elevation: 1,
        color: const Color(0xFF000000),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            songRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            song.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artists.join(', '),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}