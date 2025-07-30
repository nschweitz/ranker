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

class SongMatch {
  final LikedSong song;
  final int score;
  
  SongMatch({required this.song, required this.score});
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
  List<LikedSong> _filteredSongs = [];
  bool _isSyncing = false;
  int? _totalLikedSongs;
  DateTime? _lastSyncTime;
  StreamSubscription<List<LikedSong>>? _likedSongsSubscription;
  
  SortCriteria _currentSortCriteria = SortCriteria.timeAdded;
  SortOrder _currentSortOrder = SortOrder.descending;
  
  String _searchQuery = '';
  bool _isSearching = false;
  
  final ScrollController _scrollController = ScrollController();
  bool _isJumpingToCurrent = false;

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
      _updateFilteredSongs();
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
      _filteredSongs.clear();
      _totalLikedSongs = null;
      _isSyncing = false;
      _lastSyncTime = null;
      _searchQuery = '';
      _isSearching = false;
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
        _updateFilteredSongs();
        _sortSongs();
      }
    });
  }

  Future<void> _jumpToCurrentSong() async {
    setState(() {
      _isJumpingToCurrent = true;
    });

    try {
      final currentlyPlaying = await SpotifyPlaybackService.getCurrentlyPlaying();
      
      if (currentlyPlaying == null || currentlyPlaying['item'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No song is currently playing on Spotify')),
        );
        return;
      }

      final currentTrackId = currentlyPlaying['item']['id'] as String;
      final currentTrackName = currentlyPlaying['item']['name'] as String;
      final currentTrackArtist = (currentlyPlaying['item']['artists'] as List)
          .map((artist) => artist['name'] as String)
          .join(', ');

      final song = _likedSongs.firstWhere(
        (song) => song.id == currentTrackId,
        orElse: () => throw Exception('Song not found'),
      );
      
      // Navigate directly to the rating screen for the currently playing song
      await _showRatingScreen(song);
    } catch (e) {
      String errorMessage = 'Failed to get currently playing song';
      if (e.toString().contains('Song not found')) {
        final currentTrackName = 'Unknown';
        final currentTrackArtist = 'Unknown';
        errorMessage = 'Currently playing song is not in your liked songs';
      } else if (e.toString().contains('Authentication expired')) {
        errorMessage = 'Session expired. Please sign in again.';
        setState(() {
          _isSignedIn = false;
          _accessToken = null;
        });
      } else if (e.toString().contains('No access token')) {
        errorMessage = 'Please sign in to Spotify first.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } finally {
      setState(() {
        _isJumpingToCurrent = false;
      });
    }
  }

  void _sortSongs() {
    final songsToSort = _isSearching ? _filteredSongs : _likedSongs;
    songsToSort.sort((a, b) {
      int comparison = 0;
      
      switch (_currentSortCriteria) {
        case SortCriteria.timeAdded:
          comparison = a.addedAt.compareTo(b.addedAt);
          break;
        case SortCriteria.quality:
          final aRating = a.qualityRating;
          final bRating = b.qualityRating;
          
          // If both have ratings, compare them
          if (aRating != null && bRating != null) {
            comparison = aRating.compareTo(bRating);
          }
          // If only one has a rating, the one with rating comes first
          else if (aRating != null && bRating == null) {
            return _currentSortOrder == SortOrder.ascending ? -1 : -1;
          }
          else if (aRating == null && bRating != null) {
            return _currentSortOrder == SortOrder.ascending ? 1 : 1;
          }
          // If both are null, maintain original order (by addedAt)
          else {
            comparison = a.addedAt.compareTo(b.addedAt);
          }
          break;
        case SortCriteria.valence:
          final aRating = a.valenceRating;
          final bRating = b.valenceRating;
          
          if (aRating != null && bRating != null) {
            comparison = aRating.compareTo(bRating);
          }
          else if (aRating != null && bRating == null) {
            return _currentSortOrder == SortOrder.ascending ? -1 : -1;
          }
          else if (aRating == null && bRating != null) {
            return _currentSortOrder == SortOrder.ascending ? 1 : 1;
          }
          else {
            comparison = a.addedAt.compareTo(b.addedAt);
          }
          break;
        case SortCriteria.intensity:
          final aRating = a.intensityRating;
          final bRating = b.intensityRating;
          
          if (aRating != null && bRating != null) {
            comparison = aRating.compareTo(bRating);
          }
          else if (aRating != null && bRating == null) {
            return _currentSortOrder == SortOrder.ascending ? -1 : -1;
          }
          else if (aRating == null && bRating != null) {
            return _currentSortOrder == SortOrder.ascending ? 1 : 1;
          }
          else {
            comparison = a.addedAt.compareTo(b.addedAt);
          }
          break;
        case SortCriteria.accessibility:
          final aRating = a.accessibilityRating;
          final bRating = b.accessibilityRating;
          
          if (aRating != null && bRating != null) {
            comparison = aRating.compareTo(bRating);
          }
          else if (aRating != null && bRating == null) {
            return _currentSortOrder == SortOrder.ascending ? -1 : -1;
          }
          else if (aRating == null && bRating != null) {
            return _currentSortOrder == SortOrder.ascending ? 1 : 1;
          }
          else {
            comparison = a.addedAt.compareTo(b.addedAt);
          }
          break;
        case SortCriteria.synthetic:
          final aRating = a.syntheticRating;
          final bRating = b.syntheticRating;
          
          if (aRating != null && bRating != null) {
            comparison = aRating.compareTo(bRating);
          }
          else if (aRating != null && bRating == null) {
            return _currentSortOrder == SortOrder.ascending ? -1 : -1;
          }
          else if (aRating == null && bRating != null) {
            return _currentSortOrder == SortOrder.ascending ? 1 : 1;
          }
          else {
            comparison = a.addedAt.compareTo(b.addedAt);
          }
          break;
      }
      
      return _currentSortOrder == SortOrder.ascending ? comparison : -comparison;
    });
  }

  void _updateFilteredSongs() {
    if (_searchQuery.isEmpty) {
      _filteredSongs = _likedSongs;
      _isSearching = false;
    } else {
      _filteredSongs = _searchSongs(_searchQuery);
      _isSearching = true;
    }
  }

  List<LikedSong> _searchSongs(String query) {
    final lowercaseQuery = query.toLowerCase();
    final matches = <SongMatch>[];
    
    for (final song in _likedSongs) {
      final songName = song.name.toLowerCase();
      final albumName = song.album.toLowerCase();
      final artistNames = song.artists.map((a) => a.toLowerCase()).toList();
      final allArtists = artistNames.join(' ');
      
      int score = 0;
      bool hasMatch = false;
      
      // Exact song name match (highest priority)
      if (songName == lowercaseQuery) {
        score += 1000;
        hasMatch = true;
      }
      // Song name starts with query
      else if (songName.startsWith(lowercaseQuery)) {
        score += 500;
        hasMatch = true;
      }
      // Song name contains query
      else if (songName.contains(lowercaseQuery)) {
        score += 300;
        hasMatch = true;
      }
      
      // Exact artist match
      if (artistNames.any((artist) => artist == lowercaseQuery)) {
        score += 800;
        hasMatch = true;
      }
      // Artist starts with query
      else if (artistNames.any((artist) => artist.startsWith(lowercaseQuery))) {
        score += 400;
        hasMatch = true;
      }
      // Artist contains query
      else if (allArtists.contains(lowercaseQuery)) {
        score += 200;
        hasMatch = true;
      }
      
      // Exact album match
      if (albumName == lowercaseQuery) {
        score += 600;
        hasMatch = true;
      }
      // Album starts with query
      else if (albumName.startsWith(lowercaseQuery)) {
        score += 300;
        hasMatch = true;
      }
      // Album contains query
      else if (albumName.contains(lowercaseQuery)) {
        score += 150;
        hasMatch = true;
      }
      
      if (hasMatch) {
        matches.add(SongMatch(song: song, score: score));
      }
    }
    
    // Sort by score (descending) and return songs
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.map((match) => match.song).toList();
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _updateFilteredSongs();
      _sortSongs();
    });
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _updateFilteredSongs();
      _sortSongs();
    });
  }

  void _showSearchDialog() {
    final controller = TextEditingController(text: _searchQuery);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Search Songs'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search by song, artist, or album...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            if (_searchQuery.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _clearSearch();
                },
                child: const Text('Clear'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performSearch(controller.text);
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
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

  int _getRatedSongsCount() {
    return _likedSongs.where((song) => 
      song.qualityRating != null ||
      song.valenceRating != null ||
      song.intensityRating != null ||
      song.accessibilityRating != null ||
      song.syntheticRating != null
    ).length;
  }

  void _showAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_lastSyncTime != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Last sync: ${_lastSyncTime!.toLocal().toString().split(' ')[0]}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              ListTile(
                leading: _isSyncing 
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                title: Text(_isSyncing ? 'Syncing...' : 'Sync Liked Songs'),
                onTap: _isSyncing ? null : () {
                  Navigator.of(context).pop();
                  _syncLikedSongs();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign Out'),
                onTap: () {
                  Navigator.of(context).pop();
                  _signOut();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
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
                        setState(() {
                          _currentSortCriteria = value;
                          _sortSongs();
                        });
                        Navigator.of(context).pop();
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
                        setState(() {
                          _currentSortOrder = value;
                          _sortSongs();
                        });
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  RadioListTile<SortOrder>(
                    title: Text(_currentSortCriteria == SortCriteria.timeAdded ? 'Oldest First' : 'Lowest First'),
                    value: SortOrder.ascending,
                    groupValue: _currentSortOrder,
                    onChanged: (SortOrder? value) {
                      if (value != null) {
                        setState(() {
                          _currentSortOrder = value;
                          _sortSongs();
                        });
                        Navigator.of(context).pop();
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
              child: const Text('Close'),
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
        _updateFilteredSongs();
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
            _updateFilteredSongs();
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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If we have songs, show the full-screen songs list
    if (_likedSongs.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text('${_getRatedSongsCount()} / ${_likedSongs.length}${_isSearching ? ' (filtered)' : ''}'),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.search_off : Icons.search),
              tooltip: _isSearching ? 'Clear search' : 'Search songs',
              onPressed: _isSearching ? _clearSearch : _showSearchDialog,
            ),
            IconButton(
              icon: _isJumpingToCurrent 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              tooltip: 'Jump to currently playing song',
              onPressed: _isJumpingToCurrent ? null : _jumpToCurrentSong,
            ),
            IconButton(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort songs',
              onPressed: _showSortDialog,
            ),
            IconButton(
              icon: const Icon(Icons.account_circle),
              tooltip: 'Account',
              onPressed: _showAccountDialog,
            ),
          ],
        ),
        body: ListView.builder(
          controller: _scrollController,
          itemCount: _isSearching ? _filteredSongs.length : _likedSongs.length,
          itemBuilder: (context, index) {
            final song = _isSearching ? _filteredSongs[index] : _likedSongs[index];
            return SongListItem(
              song: song,
              onTap: () => _showRatingScreen(song),
              onLongPress: () => _playSongInSpotify(song),
            );
          },
        ),
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