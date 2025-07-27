import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import '../services/spotify_auth_service.dart';
import '../services/spotify_liked_songs_service.dart';
import '../services/spotify_playback_service.dart';
import '../widgets/song_list_item.dart';
import 'rating_screen.dart';

enum SortCriteria {
  timeAdded,
  quality,
  valence,
  intensity,
  accessibility,
  synthetic,
}

enum SortOrder {
  ascending,
  descending,
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
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
  
  SortCriteria _currentSortCriteria = SortCriteria.timeAdded;
  SortOrder _currentSortOrder = SortOrder.descending;

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
      _likedSongs.clear();
      _likedSongs.addAll(cachedSongs);
      _lastSyncTime = lastSync;
      _sortSongs();
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

  Future<void> _showRatingScreen(LikedSong song) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => RatingScreen(song: song, allSongs: _likedSongs),
      ),
    );
    
    // Only refresh specific song data instead of entire list
    if (result == true) {
      await _refreshSingleSong(song.id);
    }
  }

  Future<void> _playSongInSpotify(LikedSong song) async {
    try {
      await SpotifyPlaybackService.playSong(song.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Now playing: ${song.name} by ${song.artists.join(', ')}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play song: $e')),
      );
    }
  }

  Future<void> _refreshSingleSong(String songId) async {
    final cachedSongs = await SpotifyLikedSongsService.getCachedLikedSongs();
    final updatedSong = cachedSongs.firstWhere(
      (song) => song.id == songId,
      orElse: () => _likedSongs.firstWhere((song) => song.id == songId),
    );
    
    setState(() {
      final index = _likedSongs.indexWhere((song) => song.id == songId);
      if (index != -1) {
        _likedSongs[index] = updatedSong;
        _sortSongs();
      }
    });
  }

  void _sortSongs() {
    _likedSongs.sort((a, b) {
      int comparison = 0;
      
      switch (_currentSortCriteria) {
        case SortCriteria.timeAdded:
          comparison = a.addedAt.compareTo(b.addedAt);
          break;
        case SortCriteria.quality:
          final aRating = a.qualityRating ?? -10.0;
          final bRating = b.qualityRating ?? -10.0;
          comparison = aRating.compareTo(bRating);
          break;
        case SortCriteria.valence:
          final aRating = a.valenceRating ?? -10.0;
          final bRating = b.valenceRating ?? -10.0;
          comparison = aRating.compareTo(bRating);
          break;
        case SortCriteria.intensity:
          final aRating = a.intensityRating ?? -10.0;
          final bRating = b.intensityRating ?? -10.0;
          comparison = aRating.compareTo(bRating);
          break;
        case SortCriteria.accessibility:
          final aRating = a.accessibilityRating ?? -10.0;
          final bRating = b.accessibilityRating ?? -10.0;
          comparison = aRating.compareTo(bRating);
          break;
        case SortCriteria.synthetic:
          final aRating = a.syntheticRating ?? -10.0;
          final bRating = b.syntheticRating ?? -10.0;
          comparison = aRating.compareTo(bRating);
          break;
      }
      
      return _currentSortOrder == SortOrder.ascending ? comparison : -comparison;
    });
  }

  String _getSortCriteriaDisplayName(SortCriteria criteria) {
    switch (criteria) {
      case SortCriteria.timeAdded:
        return 'Time Added';
      case SortCriteria.quality:
        return 'Quality';
      case SortCriteria.valence:
        return 'Valence';
      case SortCriteria.intensity:
        return 'Intensity';
      case SortCriteria.accessibility:
        return 'Accessibility';
      case SortCriteria.synthetic:
        return 'Synthetic';
    }
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sort Songs'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Sort by:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...SortCriteria.values.map((criteria) => RadioListTile<SortCriteria>(
                    title: Text(_getSortCriteriaDisplayName(criteria)),
                    value: criteria,
                    groupValue: _currentSortCriteria,
                    onChanged: (SortCriteria? value) {
                      if (value != null) {
                        setDialogState(() {
                          _currentSortCriteria = value;
                        });
                      }
                    },
                  )),
                  const SizedBox(height: 20),
                  const Text('Order:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  RadioListTile<SortOrder>(
                    title: Text(_currentSortCriteria == SortCriteria.timeAdded ? 'Newest First' : 'Highest First'),
                    value: SortOrder.descending,
                    groupValue: _currentSortOrder,
                    onChanged: (SortOrder? value) {
                      if (value != null) {
                        setDialogState(() {
                          _currentSortOrder = value;
                        });
                      }
                    },
                  ),
                  RadioListTile<SortOrder>(
                    title: Text(_currentSortCriteria == SortCriteria.timeAdded ? 'Oldest First' : 'Lowest First'),
                    value: SortOrder.ascending,
                    groupValue: _currentSortOrder,
                    onChanged: (SortOrder? value) {
                      if (value != null) {
                        setDialogState(() {
                          _currentSortOrder = value;
                        });
                      }
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _sortSongs();
                });
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
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
        _sortSongs();
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
            _sortSongs();
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
            IconButton(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort songs',
              onPressed: _showSortDialog,
            ),
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
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'signout') {
                  _signOut();
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'signout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text('Sign Out'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: ListView.builder(
          itemCount: _likedSongs.length,
          itemBuilder: (context, index) {
            final song = _likedSongs[index];
            return SongListItem(
              song: song,
              onTap: () => _showRatingScreen(song),
              onLongPress: () => _playSongInSpotify(song),
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