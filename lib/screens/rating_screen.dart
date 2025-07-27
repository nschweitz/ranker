import 'package:flutter/material.dart';
import '../services/spotify_liked_songs_service.dart';

class RatingScreen extends StatefulWidget {
  final LikedSong song;
  
  const RatingScreen({super.key, required this.song});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  late double _qualityRating;
  late double _valenceRating;
  late double _intensityRating;
  List<LikedSong> _allSongs = [];
  String? _activeSlider; // Track which slider is being dragged

  @override
  void initState() {
    super.initState();
    _loadAllSongs();
    _loadCurrentSongRatings();
  }

  Future<void> _loadCurrentSongRatings() async {
    final songs = await SpotifyLikedSongsService.getCachedLikedSongs();
    final currentSong = songs.firstWhere(
      (song) => song.id == widget.song.id,
      orElse: () => widget.song,
    );
    
    setState(() {
      _qualityRating = (currentSong.qualityRating ?? 0).toDouble();
      _valenceRating = (currentSong.valenceRating ?? 0).toDouble();
      _intensityRating = (currentSong.intensityRating ?? 0).toDouble();
    });
  }

  Future<void> _loadAllSongs() async {
    final songs = await SpotifyLikedSongsService.getCachedLikedSongs();
    setState(() {
      _allSongs = songs;
    });
  }

  LikedSong? _findNextUnratedSong() {
    for (final song in _allSongs) {
      if (song.id != widget.song.id && 
          (song.qualityRating == null || song.valenceRating == null || song.intensityRating == null)) {
        return song;
      }
    }
    return null;
  }

  Future<void> _saveRatings() async {
    await SpotifyLikedSongsService.updateSongRatings(
      widget.song.id,
      quality: _qualityRating,
      valence: _valenceRating,
      intensity: _intensityRating,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Rate Song'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _saveRatings();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        actions: [
          TextButton(
            onPressed: () async {
              await _saveRatings();
              
              if (mounted) {
                final nextSong = _findNextUnratedSong();
                if (nextSong != null) {
                  // Replace current screen with next song's rating screen
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => RatingScreen(song: nextSong),
                    ),
                  );
                } else {
                  // No more unrated songs, go back to home
                  Navigator.of(context).pop(true);
                }
              }
            },
            child: const Text(
              'NEXT',
              style: TextStyle(
                color: Color(0xFF1DB954),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                _buildSurroundingReferencePoints(),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Column(
                children: [
                  _buildRatingSlider(
                    'Quality',
                    _qualityRating,
                    Colors.blue,
                    (value) => setState(() => _qualityRating = value),
                    onStart: () => setState(() => _activeSlider = 'quality'),
                    onEnd: () => setState(() => _activeSlider = null),
                  ),
                  const SizedBox(height: 20),
                  _buildRatingSlider(
                    'Valence',
                    _valenceRating,
                    Colors.green,
                    (value) => setState(() => _valenceRating = value),
                    onStart: () => setState(() => _activeSlider = 'valence'),
                    onEnd: () => setState(() => _activeSlider = null),
                  ),
                  const SizedBox(height: 20),
                  _buildRatingSlider(
                    'Intensity',
                    _intensityRating,
                    Colors.red,
                    (value) => setState(() => _intensityRating = value),
                    onStart: () => setState(() => _activeSlider = 'intensity'),
                    onEnd: () => setState(() => _activeSlider = null),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  LikedSong? _findClosestSongByRating(String parameter, double currentValue, bool findHigher) {
    List<LikedSong> validSongs = _allSongs.where((song) {
      if (song.id == widget.song.id) return false; // Exclude current song
      
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
      }
      
      if (findHigher) {
        return aValue.compareTo(bValue); // Ascending for next higher
      } else {
        return bValue.compareTo(aValue); // Descending for next lower
      }
    });
    
    return validSongs.first;
  }

  Widget _buildSurroundingReferencePoints() {
    final parameter = _activeSlider;
    double? currentValue;
    
    if (parameter != null) {
      switch (parameter) {
        case 'quality':
          currentValue = _qualityRating;
          break;
        case 'valence':
          currentValue = _valenceRating;
          break;
        case 'intensity':
          currentValue = _intensityRating;
          break;
      }
    }
    
    return Column(
      children: [
        // Song with next highest rating
        _buildReferenceSongCard(parameter, currentValue, true),
        const SizedBox(height: 4),
        // Current song being rated
        _buildCurrentSongCard(),
        const SizedBox(height: 4),
        // Song with next lowest rating
        _buildReferenceSongCard(parameter, currentValue, false),
      ],
    );
  }

  Widget _buildCurrentSongCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(
              Icons.music_note,
              color: Color(0xFF1DB954),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.song.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.song.artists.join(', '),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.song.album,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
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

  Widget _buildReferenceSongCard(String? parameter, double? currentValue, bool findHigher) {
    // Show empty placeholder when no active slider
    if (parameter == null || currentValue == null) {
      return SizedBox(
        height: 64,
        child: Card(
          elevation: 0,
          color: Colors.transparent,
          child: Container(),
        ),
      );
    }

    final song = _findClosestSongByRating(parameter, currentValue, findHigher);
    
    if (song == null) {
      final direction = findHigher ? 'higher' : 'lower';
      return SizedBox(
        height: 64,
        child: Card(
          elevation: 1,
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(
                  Icons.music_note_outlined,
                  color: Colors.grey[400],
                  size: 32,
                ),
                const SizedBox(width: 12),
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
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
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
    }

    return SizedBox(
      height: 64,
      child: Card(
        elevation: 1,
        color: Colors.blue[50],
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(
                Icons.music_note_outlined,
                color: Colors.blue[600],
                size: 32,
              ),
              const SizedBox(width: 12),
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
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            songRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
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



  Widget _buildRatingSlider(String label, double value, Color color, ValueChanged<double> onChanged, {
    VoidCallback? onStart,
    VoidCallback? onEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              '-9',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(
              child: Slider(
                value: value,
                min: -9.0,
                max: 9.0,
                activeColor: color,
                inactiveColor: color.withValues(alpha: 0.3),
                onChanged: onChanged,
                onChangeStart: (value) => onStart?.call(),
                onChangeEnd: (value) => onEnd?.call(),
              ),
            ),
            Text(
              '9',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}