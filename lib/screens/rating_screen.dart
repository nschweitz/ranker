import 'package:flutter/material.dart';
import '../services/spotify_liked_songs_service.dart';

class CustomSliderThumbShape extends SliderComponentShape {
  final double thumbRadius;
  final double value;
  final Color color;
  final String aspectName;
  final bool isDragging;

  const CustomSliderThumbShape({
    required this.thumbRadius,
    required this.value,
    required this.color,
    required this.aspectName,
    required this.isDragging,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius + (isDragging ? 25 : 0)); // Extra space when dragging
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    // Draw the thumb circle
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, thumbRadius, paint);

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(center, thumbRadius, borderPaint);

    // Draw the aspect name and value pill
    final pillText = '$aspectName: ${this.value.toStringAsFixed(1)}';
    final textSpan = TextSpan(
      text: pillText,
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Position the pill - inline when not dragging, above when dragging
    final pillVerticalOffset = isDragging ? -thumbRadius - 30 : 0;
    final pillCenter = Offset(center.dx, center.dy + pillVerticalOffset);
    
    // Draw pill background
    final pillWidth = textPainter.width + 16;
    final pillHeight = textPainter.height + 8;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: pillCenter,
        width: pillWidth,
        height: pillHeight,
      ),
      Radius.circular(pillHeight / 2),
    );
    
    final pillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(pillRect, pillPaint);
    
    // Draw pill border
    final pillBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    canvas.drawRRect(pillRect, pillBorderPaint);
    
    // Draw text
    final textOffset = Offset(
      pillCenter.dx - textPainter.width / 2,
      pillCenter.dy - textPainter.height / 2,
    );
    
    textPainter.paint(canvas, textOffset);
  }
}

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