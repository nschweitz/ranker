import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _MyHomePageState extends State<MyHomePage> {
  bool _isSignedIn = false;
  bool _isLoading = false;
  String? _accessToken;
  StreamSubscription? _linkSubscription;
  late AppLinks _appLinks;
  
  List<LikedSong> _likedSongs = [];
  bool _isLoadingLikedSongs = false;
  int? _totalLikedSongs;
  StreamSubscription<List<LikedSong>>? _likedSongsSubscription;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _checkSignInStatus();
    _handleIncomingLinks();
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
    setState(() {
      _isSignedIn = false;
      _accessToken = null;
      _likedSongs.clear();
      _totalLikedSongs = null;
      _isLoadingLikedSongs = false;
    });
  }

  Future<void> _fetchLikedSongs() async {
    if (_isLoadingLikedSongs) return;
    
    setState(() {
      _isLoadingLikedSongs = true;
      _likedSongs.clear();
    });

    try {
      // Get total count first
      final total = await SpotifyLikedSongsService.getTotalLikedSongsCount();
      setState(() {
        _totalLikedSongs = total;
      });

      // Start streaming liked songs
      _likedSongsSubscription = SpotifyLikedSongsService.fetchLikedSongs().listen(
        (batch) {
          setState(() {
            _likedSongs.addAll(batch);
          });
        },
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching liked songs: $error')),
          );
          setState(() {
            _isLoadingLikedSongs = false;
          });
        },
        onDone: () {
          setState(() {
            _isLoadingLikedSongs = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loaded ${_likedSongs.length} liked songs!')),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() {
        _isLoadingLikedSongs = false;
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
                const SizedBox(height: 10),
                if (_accessToken != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Access Token:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${_accessToken!.substring(0, 20)}...',
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoadingLikedSongs ? null : _fetchLikedSongs,
                      icon: _isLoadingLikedSongs 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.favorite),
                      label: Text(_isLoadingLikedSongs ? 'Loading...' : 'Get Liked Songs'),
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
                if (_totalLikedSongs != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Progress: ${_likedSongs.length}/${_totalLikedSongs} songs loaded',
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
              if (_likedSongs.isNotEmpty) ...[
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 20),
                Text(
                  'Your Liked Songs',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _likedSongs.length,
                  itemBuilder: (context, index) {
                    final song = _likedSongs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(
                          Icons.music_note,
                          color: Color(0xFF1DB954),
                        ),
                        title: Text(
                          song.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Artists: ${song.artists.join(', ')}'),
                            Text('Album: ${song.album}'),
                            Text('Added: ${song.addedAt.toLocal().toString().split(' ')[0]}'),
                          ],
                        ),
                        trailing: Text(
                          '${(song.durationMs / 60000).floor()}:${((song.durationMs % 60000) / 1000).floor().toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
