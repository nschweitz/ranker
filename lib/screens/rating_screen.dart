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
    _qualityRating = (widget.song.qualityRating ?? 0).toDouble();
    _valenceRating = (widget.song.valenceRating ?? 0).toDouble();
    _intensityRating = (widget.song.intensityRating ?? 0).toDouble();
    _loadAllSongs();
  }

  Future<void> _loadAllSongs() async {
    final songs = await SpotifyLikedSongsService.getCachedLikedSongs();
    setState(() {
      _allSongs = songs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Rate Song'),
        actions: [
          TextButton(
            onPressed: () async {
              await SpotifyLikedSongsService.updateSongRatings(
                widget.song.id,
                quality: _qualityRating.round(),
                valence: _valenceRating.round(),
                intensity: _intensityRating.round(),
              );
              if (mounted) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text(
              'SAVE',
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

  List<LikedSong> _findSongsByRating(String parameter, int targetValue) {
    return _allSongs.where((song) {
      if (song.id == widget.song.id) return false; // Exclude current song
      
      int? songValue;
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
      return songValue == targetValue;
    }).toList();
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

    final currentInt = currentValue?.round();
    
    return Column(
      children: [
        // Song with $CURRENT_VALUE + 1
        _buildReferenceSongCard(parameter, currentInt != null ? currentInt + 1 : null),
        const SizedBox(height: 4),
        // Current song being rated
        _buildCurrentSongCard(),
        const SizedBox(height: 4),
        // Song with $CURRENT_VALUE
        _buildReferenceSongCard(parameter, currentInt),
        const SizedBox(height: 4),
        // Song with $CURRENT_VALUE - 1
        _buildReferenceSongCard(parameter, currentInt != null ? currentInt - 1 : null),
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

  Widget _buildReferenceSongCard(String? parameter, int? targetValue) {
    // Show empty placeholder when no active slider or target value
    if (parameter == null || targetValue == null) {
      return SizedBox(
        height: 64,
        child: Card(
          elevation: 0,
          color: Colors.transparent,
          child: Container(),
        ),
      );
    }

    final songs = _findSongsByRating(parameter, targetValue);
    
    if (songs.isEmpty) {
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
                              'No songs with rating $targetValue',
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
                      const SizedBox(height: 4),
                      Text(
                        '',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
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

    final song = songs.first;
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
                            targetValue.toString(),
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

  Widget _buildReferencePoints(String parameter, double currentValue) {
    if (_activeSlider != parameter) return const SizedBox.shrink();
    
    final currentInt = currentValue.round();
    final referenceSongs = {
      'current': _findSongsByRating(parameter, currentInt),
      'plus': _findSongsByRating(parameter, currentInt + 1),
      'minus': _findSongsByRating(parameter, currentInt - 1),
    };

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reference Points',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          ...[
            _buildReferenceRow('Current ($currentInt)', referenceSongs['current']!),
            if (currentInt < 10) _buildReferenceRow('${currentInt + 1}', referenceSongs['plus']!),
            if (currentInt > -10) _buildReferenceRow('${currentInt - 1}', referenceSongs['minus']!),
          ].where((widget) => widget != null).cast<Widget>(),
        ],
      ),
    );
  }

  Widget? _buildReferenceRow(String label, List<LikedSong> songs) {
    if (songs.isEmpty) return null;
    
    final song = songs.first; // Take the first matching song
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${song.name} - ${song.artists.join(', ')}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
                value.round().toString(),
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
              '-10',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(
              child: Slider(
                value: value,
                min: -10,
                max: 10,
                divisions: 20,
                activeColor: color,
                inactiveColor: color.withValues(alpha: 0.3),
                onChanged: onChanged,
                onChangeStart: (value) => onStart?.call(),
                onChangeEnd: (value) => onEnd?.call(),
              ),
            ),
            Text(
              '10',
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