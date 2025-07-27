import 'package:flutter/material.dart';
import '../services/spotify_liked_songs_service.dart';
import 'custom_slider_thumb_shape.dart';
import 'rating_screen_helpers.dart';

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
  late double _accessibilityRating;
  late double _syntheticRating;
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
      _accessibilityRating = (currentSong.accessibilityRating ?? 0).toDouble();
      _syntheticRating = (currentSong.syntheticRating ?? 0).toDouble();
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
          (song.qualityRating == null || song.valenceRating == null || song.intensityRating == null || song.accessibilityRating == null || song.syntheticRating == null)) {
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
      accessibility: _accessibilityRating,
      synthetic: _syntheticRating,
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
                  const SizedBox(height: 12),
                  _buildRatingSlider(
                    'Valence',
                    _valenceRating,
                    Colors.green,
                    (value) => setState(() => _valenceRating = value),
                    onStart: () => setState(() => _activeSlider = 'valence'),
                    onEnd: () => setState(() => _activeSlider = null),
                  ),
                  const SizedBox(height: 12),
                  _buildRatingSlider(
                    'Intensity',
                    _intensityRating,
                    Colors.red,
                    (value) => setState(() => _intensityRating = value),
                    onStart: () => setState(() => _activeSlider = 'intensity'),
                    onEnd: () => setState(() => _activeSlider = null),
                  ),
                  const SizedBox(height: 12),
                  _buildRatingSlider(
                    'Accessibility',
                    _accessibilityRating,
                    Colors.purple,
                    (value) => setState(() => _accessibilityRating = value),
                    onStart: () => setState(() => _activeSlider = 'accessibility'),
                    onEnd: () => setState(() => _activeSlider = null),
                  ),
                  const SizedBox(height: 12),
                  _buildRatingSlider(
                    'Synthetic',
                    _syntheticRating,
                    Colors.orange,
                    (value) => setState(() => _syntheticRating = value),
                    onStart: () => setState(() => _activeSlider = 'synthetic'),
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
        case 'accessibility':
          currentValue = _accessibilityRating;
          break;
        case 'synthetic':
          currentValue = _syntheticRating;
          break;
      }
    }
    
    return Column(
      children: [
        // Song with next highest rating
        RatingScreenHelpers.buildReferenceSongCard(
          _allSongs,
          widget.song.id,
          parameter,
          currentValue,
          true,
        ),
        const SizedBox(height: 4),
        // Current song being rated
        RatingScreenHelpers.buildCurrentSongCard(widget.song),
        const SizedBox(height: 4),
        // Song with next lowest rating
        RatingScreenHelpers.buildReferenceSongCard(
          _allSongs,
          widget.song.id,
          parameter,
          currentValue,
          false,
        ),
      ],
    );
  }


  Widget _buildRatingSlider(String label, double value, Color color, ValueChanged<double> onChanged, {
    VoidCallback? onStart,
    VoidCallback? onEnd,
  }) {
    // Determine if this slider is being dragged
    final isDragging = _activeSlider == label.toLowerCase();
    
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        thumbShape: CustomSliderThumbShape(
          thumbRadius: 14.0,
          value: value,
          color: color,
          aspectName: label,
          isDragging: isDragging,
        ),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 20.0),
      ),
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
    );
  }
}