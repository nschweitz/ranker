import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'services/spotify_auth_service.dart';
import 'services/spotify_liked_songs_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ranker - Spotify Integration',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const MyHomePage(title: 'Ranker'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _SongListItem extends StatelessWidget {
  final LikedSong song;
  final VoidCallback? onTap;
  
  const _SongListItem({required this.song, this.onTap});

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
        leading: const Icon(
          Icons.music_note,
          color: Color(0xFF1DB954),
          size: 20,
        ),
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
            if (song.qualityRating != null || song.valenceRating != null || song.intensityRating != null)
              Row(
                children: [
                  if (song.qualityRating != null) 
                    Text('Q:${song.qualityRating}', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                  if (song.qualityRating != null && (song.valenceRating != null || song.intensityRating != null))
                    const Text(' ', style: TextStyle(fontSize: 10)),
                  if (song.valenceRating != null)
                    Text('V:${song.valenceRating}', style: const TextStyle(fontSize: 10, color: Colors.green)),
                  if (song.valenceRating != null && song.intensityRating != null)
                    const Text(' ', style: TextStyle(fontSize: 10)),
                  if (song.intensityRating != null)
                    Text('I:${song.intensityRating}', style: const TextStyle(fontSize: 10, color: Colors.red)),
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

class _RatingDialog extends StatefulWidget {
  final LikedSong song;
  
  const _RatingDialog({required this.song});

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  late double _qualityRating;
  late double _valenceRating;
  late double _intensityRating;

  @override
  void initState() {
    super.initState();
    _qualityRating = (widget.song.qualityRating ?? 0).toDouble();
    _valenceRating = (widget.song.valenceRating ?? 0).toDouble();
    _intensityRating = (widget.song.intensityRating ?? 0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.song.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            widget.song.artists.join(', '),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRatingSlider(
              'Quality',
              _qualityRating,
              Colors.blue,
              (value) => setState(() => _qualityRating = value),
            ),
            const SizedBox(height: 20),
            _buildRatingSlider(
              'Valence',
              _valenceRating,
              Colors.green,
              (value) => setState(() => _valenceRating = value),
            ),
            const SizedBox(height: 20),
            _buildRatingSlider(
              'Intensity',
              _intensityRating,
              Colors.red,
              (value) => setState(() => _intensityRating = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
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
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1DB954),
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildRatingSlider(String label, double value, Color color, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: color),
            ),
            Text(
              value.round().toString(),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('-10', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Expanded(
              child: Slider(
                value: value,
                min: -10,
                max: 10,
                divisions: 20,
                activeColor: color,
                inactiveColor: color.withValues(alpha: 0.3),
                onChanged: onChanged,
              ),
            ),
            const Text('10', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isSignedIn = false;
  bool _isLoading = false;
  String? _accessToken;
  StreamSubscription? _linkSubscription;
  late AppLinks _appLinks;
  
  List<LikedSong> _likedSongs = [];
  bool _isSyncing = false;
  int? _totalLikedSongs;
  DateTime? _lastSyncTime;
  StreamSubscription<List<LikedSong>>? _likedSongsSubscription;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _checkSignInStatus();
    _handleIncomingLinks();
    _loadCachedData();
  }

  void _handleIncomingLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      if (uri.toString().startsWith('http://localhost:8080')) {
        _handleCallback(uri);
      }
    }, onError: (Object err) {
      print('Deep link error: $err');
    });
    
    // Handle initial link if app was launched from a deep link
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null && uri.toString().startsWith('http://localhost:8080')) {
        _handleCallback(uri);
      }
    });
  }

  Future<void> _handleCallback(Uri uri) async {
    try {
      await SpotifyAuthService.handleCallback(uri);
      await _checkSignInStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully signed in to Spotify!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication failed: $e')),
      );
    }
  }

  Future<void> _loadCachedData() async {
    final cachedSongs = await SpotifyLikedSongsService.getCachedLikedSongs();
    final lastSync = await SpotifyLikedSongsService.getLastSyncTime();
    
    setState(() {
      _likedSongs = cachedSongs;
      _lastSyncTime = lastSync;
    });
  }

  Future<void> _checkSignInStatus() async {
    final isSignedIn = await SpotifyAuthService.isSignedIn();
    if (isSignedIn) {
      final token = await SpotifyAuthService.getAccessToken();
      setState(() {
        _isSignedIn = true;
        _accessToken = token;
      });
    }
  }

  Future<void> _signInToSpotify() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await SpotifyAuthService.signIn();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    _likedSongsSubscription?.cancel();
    await SpotifyAuthService.signOut();
    await SpotifyLikedSongsService.clearCache();
    setState(() {
      _isSignedIn = false;
      _accessToken = null;
      _likedSongs.clear();
      _totalLikedSongs = null;
      _isSyncing = false;
      _lastSyncTime = null;
    });
  }

  Future<void> _showRatingDialog(LikedSong song) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _RatingDialog(song: song),
    );
    
    if (result == true) {
      await _loadCachedData();
    }
  }

  Future<void> _syncLikedSongs() async {
    if (_isSyncing) return;
    
    setState(() {
      _isSyncing = true;
    });

    try {
      // Load cached songs first to display them immediately
      final cachedSongs = await SpotifyLikedSongsService.getCachedLikedSongs();
      setState(() {
        _likedSongs.clear();
        _likedSongs.addAll(cachedSongs);
      });

      final total = await SpotifyLikedSongsService.getTotalLikedSongsCount();
      setState(() {
        _totalLikedSongs = total;
      });

      _likedSongsSubscription = SpotifyLikedSongsService.syncLikedSongs().listen(
        (batch) {
          setState(() {
            // Insert new songs at the beginning since they're newer
            _likedSongs.insertAll(0, batch);
          });
        },
        onError: (error) {
          if (error.toString().contains('Authentication expired')) {
            setState(() {
              _isSignedIn = false;
              _accessToken = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Session expired. Please sign in again.')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error syncing liked songs: $error')),
            );
          }
          setState(() {
            _isSyncing = false;
          });
        },
        onDone: () async {
          final lastSync = await SpotifyLikedSongsService.getLastSyncTime();
          setState(() {
            _isSyncing = false;
            _lastSyncTime = lastSync;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Synced ${_likedSongs.length} liked songs!')),
          );
        },
      );
    } catch (e) {
      if (e.toString().contains('Authentication expired')) {
        setState(() {
          _isSignedIn = false;
          _accessToken = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please sign in again.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _likedSongsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If we have songs, show the full-screen songs list
    if (_likedSongs.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text('${_likedSongs.length} Liked Songs'),
          actions: [
            if (_lastSyncTime != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Center(
                  child: Text(
                    'Last sync: ${_lastSyncTime!.toLocal().toString().split(' ')[0]}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
        body: ListView.builder(
          itemCount: _likedSongs.length,
          itemBuilder: (context, index) {
            final song = _likedSongs[index];
            return _SongListItem(
              song: song,
              onTap: () => _showRatingDialog(song),
            );
          },
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSyncing && _totalLikedSongs != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_likedSongs.length}/$_totalLikedSongs',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            if (_isSyncing && _totalLikedSongs != null)
              const SizedBox(height: 8),
            FloatingActionButton(
              onPressed: _isSyncing ? null : _syncLikedSongs,
              backgroundColor: _isSyncing ? Colors.grey : const Color(0xFF1DB954),
              child: _isSyncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.sync, color: Colors.white),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );
    }

    // Default view when no songs are loaded
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 20),
              Icon(
                Icons.music_note,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Spotify Integration',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 40),
              if (_isSignedIn) ...[
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 50,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Successfully signed in to Spotify!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isSyncing ? null : _syncLikedSongs,
                      icon: _isSyncing 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(_isSyncing ? 'Syncing...' : 'Sync Liked Songs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _signOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
                if (_totalLikedSongs != null && _isSyncing) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Progress: ${_likedSongs.length}/$_totalLikedSongs songs synced',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: _totalLikedSongs! > 0 ? _likedSongs.length / _totalLikedSongs! : 0,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1DB954)),
                  ),
                ],
              ] else ...[
                const Text(
                  'Sign in to Spotify to get started',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: _signInToSpotify,
                        icon: const Icon(Icons.login),
                        label: const Text('Sign in with Spotify'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB954),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                        ),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
