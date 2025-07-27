import 'package:flutter/material.dart';
import '../services/spotify_liked_songs_service.dart';
import 'custom_slider_thumb_shape.dart';
import 'rating_screen_helpers.dart';

class RatingScreen extends StatefulWidget {
  final LikedSong song;
  final List<LikedSong>? allSongs;
  
  const RatingScreen({super.key, required this.song, this.allSongs});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  double _qualityRating = 0.0;
  double _valenceRating = 0.0;
  double _intensityRating = 0.0;
  double _accessibilityRating = 0.0;
  double _syntheticRating = 0.0;
  List<LikedSong> _allSongs = [];
  String? _activeSlider; // Track which slider is being dragged

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    // Initialize ratings from the song that was passed in
    _qualityRating = (widget.song.qualityRating ?? 0).toDouble();
    _valenceRating = (widget.song.valenceRating ?? 0).toDouble();
    _intensityRating = (widget.song.intensityRating ?? 0).toDouble();
    _accessibilityRating = (widget.song.accessibilityRating ?? 0).toDouble();
    _syntheticRating = (widget.song.syntheticRating ?? 0).toDouble();
    
    // Use provided songs list or load from cache as fallback
    if (widget.allSongs != null) {
      _allSongs = widget.allSongs!;
    } else {
      _loadAllSongs();
    }
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
    
    // Update the local _allSongs list to reflect the changes
    setState(() {
      final index = _allSongs.indexWhere((song) => song.id == widget.song.id);
      if (index != -1) {
        _allSongs[index] = LikedSong(
          id: widget.song.id,
          name: widget.song.name,
          artists: widget.song.artists,
          album: widget.song.album,
          addedAt: widget.song.addedAt,
          previewUrl: widget.song.previewUrl,
          durationMs: widget.song.durationMs,
          qualityRating: _qualityRating,
          valenceRating: _valenceRating,
          intensityRating: _intensityRating,
          accessibilityRating: _accessibilityRating,
          syntheticRating: _syntheticRating,
        );
      }
    });
    
    // Clear the reference song cache since ratings have changed
    RatingScreenHelpers.clearCache();
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
                Navigator.of(context).pop(true);
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
                      builder: (context) => RatingScreen(song: nextSong, allSongs: _allSongs),
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
                    Colors.blue, // This parameter is still needed for the method signature
                    (value) => setState(() => _qualityRating = value),
                    onStart: () => setState(() => _activeSlider = 'quality'),
                    onEnd: () => setState(() => _activeSlider = null),
                  ),
                  const SizedBox(height: 12),
                  _buildRatingSlider(
                    'Valence',
                    _valenceRating,
                    Colors.green, // This parameter is still needed for the method signature
                    (value) => setState(() => _valenceRating = value),
                    onStart: () => setState(() => _activeSlider = 'valence'),
                    onEnd: () => setState(() => _activeSlider = null),
                  ),
                  const SizedBox(height: 12),
                  _buildRatingSlider(
                    'Intensity',
                    _intensityRating,
                    Colors.red, // This parameter is still needed for the method signature
                    (value) => setState(() => _intensityRating = value),
                    onStart: () => setState(() => _activeSlider = 'intensity'),
                    onEnd: () => setState(() => _activeSlider = null),
                  ),
                  const SizedBox(height: 12),
                  _buildRatingSlider(
                    'Accessibility',
                    _accessibilityRating,
                    Colors.purple, // This parameter is still needed for the method signature
                    (value) => setState(() => _accessibilityRating = value),
                    onStart: () => setState(() => _activeSlider = 'accessibility'),
                    onEnd: () => setState(() => _activeSlider = null),
                  ),
                  const SizedBox(height: 12),
                  _buildRatingSlider(
                    'Synthetic',
                    _syntheticRating,
                    Colors.orange, // This parameter is still needed for the method signature
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
        RatingScreenHelpers.buildCurrentSongCard(widget.song, parameter, currentValue),
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


  Color _getColorForValue(double? value) {
    if (value == null || value == 0.0) return Colors.red;
    // Normalize value from [-9, 9] to [0, 1]
    final normalized = (value + 9) / 18;
    return Color.lerp(Colors.blue, Colors.yellow, normalized) ?? Colors.grey;
  }

  Widget _buildRatingSlider(String label, double value, Color color, ValueChanged<double> onChanged, {
    VoidCallback? onStart,
    VoidCallback? onEnd,
  }) {
    // Determine if this slider is being dragged
    final isDragging = _activeSlider == label.toLowerCase();
    final sliderColor = _getColorForValue(value);
    
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        thumbShape: CustomSliderThumbShape(
          thumbRadius: isDragging ? 14.0 : 8.0,
          value: value,
          color: sliderColor,
          aspectName: label,
          isDragging: isDragging,
        ),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 20.0),
        trackHeight: 1.0, // Make track 1 unit tall like gradient line
      ),
      child: Slider(
        value: value,
        min: -9.0,
        max: 9.0,
        activeColor: sliderColor,
        inactiveColor: sliderColor.withValues(alpha: 0.3),
        onChanged: onChanged,
        onChangeStart: (value) => onStart?.call(),
        onChangeEnd: (value) => onEnd?.call(),
      ),
    );
  }
}