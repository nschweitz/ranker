import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'spotify_auth_service.dart';

class LikedSong {
  final String id;
  final String name;
  final List<String> artists;
  final String album;
  final DateTime addedAt;
  final String? previewUrl;
  final int durationMs;
  final double? qualityRating;
  final double? valenceRating;
  final double? intensityRating;
  final double? accessibilityRating;
  final double? syntheticRating;

  LikedSong({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    required this.addedAt,
    this.previewUrl,
    required this.durationMs,
    this.qualityRating,
    this.valenceRating,
    this.intensityRating,
    this.accessibilityRating,
    this.syntheticRating,
  });

  factory LikedSong.fromJson(Map<String, dynamic> json) {
    final track = json['track'];
    return LikedSong(
      id: track['id'],
      name: track['name'],
      artists: (track['artists'] as List)
          .map((artist) => artist['name'] as String)
          .toList(),
      album: track['album']['name'],
      addedAt: DateTime.parse(json['added_at']),
      previewUrl: track['preview_url'],
      durationMs: track['duration_ms'],
    );
  }

  factory LikedSong.fromStorageJson(Map<String, dynamic> json) {
    return LikedSong(
      id: json['id'],
      name: json['name'],
      artists: List<String>.from(json['artists']),
      album: json['album'],
      addedAt: DateTime.parse(json['addedAt']),
      previewUrl: json['previewUrl'],
      durationMs: json['durationMs'],
      qualityRating: json['qualityRating'],
      valenceRating: json['valenceRating'],
      intensityRating: json['intensityRating'],
      accessibilityRating: json['accessibilityRating'],
      syntheticRating: json['syntheticRating'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artists': artists,
      'album': album,
      'addedAt': addedAt.toIso8601String(),
      'previewUrl': previewUrl,
      'durationMs': durationMs,
      'qualityRating': qualityRating,
      'valenceRating': valenceRating,
      'intensityRating': intensityRating,
      'accessibilityRating': accessibilityRating,
      'syntheticRating': syntheticRating,
    };
  }
}

class SpotifyLikedSongsService {
  static const String baseUrl = 'https://api.spotify.com/v1';
  static const int limit = 50; // Spotify's maximum limit per request
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _likedSongsKey = 'cached_liked_songs';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _ratingsKey = 'song_ratings';
  
  // In-memory cache to avoid repeated JSON parsing
  static List<LikedSong>? _cachedSongs;
  static DateTime? _cacheTimestamp;

  static Stream<List<LikedSong>> fetchLikedSongs() async* {
    final accessToken = await SpotifyAuthService.getAccessToken();
    if (accessToken == null) {
      throw Exception('No access token available. Please sign in first.');
    }

    String? nextUrl = '$baseUrl/me/tracks?limit=$limit';
    List<LikedSong> allSongs = [];

    while (nextUrl != null) {
      try {
        final response = await http.get(
          Uri.parse(nextUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final items = data['items'] as List;
          
          final batch = items.map((item) => LikedSong.fromJson(item)).toList();
          allSongs.addAll(batch);
          
          // Yield the current batch with ratings merged
          yield await _mergeSongsWithRatings(batch);
          
          // Check if there are more items
          nextUrl = data['next'];
        } else if (response.statusCode == 401) {
          throw Exception('Authentication failed. Please sign in again.');
        } else {
          throw Exception('Failed to fetch liked songs: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        throw Exception('Error fetching liked songs: $e');
      }
    }
  }

  static Future<int> getTotalLikedSongsCount() async {
    final accessToken = await SpotifyAuthService.getAccessToken();
    if (accessToken == null) {
      throw Exception('No access token available. Please sign in first.');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/me/tracks?limit=1'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['total'] as int;
      } else {
        throw Exception('Failed to get total count: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting total count: $e');
    }
  }

  static Future<void> saveLikedSongs(List<LikedSong> songs) async {
    // Store songs without ratings since ratings are stored separately
    final songsWithoutRatings = songs.map((song) => LikedSong(
      id: song.id,
      name: song.name,
      artists: song.artists,
      album: song.album,
      addedAt: song.addedAt,
      previewUrl: song.previewUrl,
      durationMs: song.durationMs,
      // Explicitly set all ratings to null since they're stored separately
      qualityRating: null,
      valenceRating: null,
      intensityRating: null,
      accessibilityRating: null,
      syntheticRating: null,
    )).toList();
    
    final songsJson = songsWithoutRatings.map((song) => song.toJson()).toList();
    final jsonString = json.encode(songsJson);
    await _storage.write(key: _likedSongsKey, value: jsonString);
    await _storage.write(key: _lastSyncKey, value: DateTime.now().toIso8601String());
    
    // Update in-memory cache (without ratings)
    _cachedSongs = songsWithoutRatings;
    _cacheTimestamp = DateTime.now();
  }

  static Future<List<LikedSong>> getCachedLikedSongs() async {
    // Return in-memory cache if available and recent (within 30 seconds)
    if (_cachedSongs != null && 
        _cacheTimestamp != null && 
        DateTime.now().difference(_cacheTimestamp!).inSeconds < 30) {
      return await _mergeSongsWithRatings(_cachedSongs!);
    }
    
    final jsonString = await _storage.read(key: _likedSongsKey);
    if (jsonString == null) {
      _cachedSongs = [];
      _cacheTimestamp = DateTime.now();
      return [];
    }
    
    try {
      final List<dynamic> songsJson = json.decode(jsonString);
      final songs = songsJson.map((songJson) => LikedSong.fromStorageJson(songJson)).toList();
      _cachedSongs = songs;
      _cacheTimestamp = DateTime.now();
      return await _mergeSongsWithRatings(songs);
    } catch (e) {
      _cachedSongs = [];
      _cacheTimestamp = DateTime.now();
      return [];
    }
  }

  static Future<DateTime?> getLastSyncTime() async {
    final timestampString = await _storage.read(key: _lastSyncKey);
    if (timestampString == null) {
      return null;
    }
    
    try {
      return DateTime.parse(timestampString);
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearCache() async {
    await _storage.delete(key: _likedSongsKey);
    await _storage.delete(key: _lastSyncKey);
    
    // Clear in-memory cache
    _cachedSongs = null;
    _cacheTimestamp = null;
    
    // Note: We intentionally do NOT clear ratings (_ratingsKey) to preserve them across sign-outs
  }

  // Separate ratings storage - persistent across sign-outs
  static Future<Map<String, Map<String, double?>>> _loadRatings() async {
    final ratingsJson = await _storage.read(key: _ratingsKey);
    if (ratingsJson == null) return {};
    
    try {
      final Map<String, dynamic> data = json.decode(ratingsJson);
      return data.map((songId, ratings) => MapEntry(
        songId,
        Map<String, double?>.from(ratings),
      ));
    } catch (e) {
      return {};
    }
  }

  static Future<void> _saveRatings(Map<String, Map<String, double?>> ratings) async {
    final ratingsJson = json.encode(ratings);
    await _storage.write(key: _ratingsKey, value: ratingsJson);
  }

  static Future<void> _saveRatingForSong(String songId, {
    double? quality,
    double? valence,
    double? intensity,
    double? accessibility,
    double? synthetic,
  }) async {
    final ratings = await _loadRatings();
    
    ratings[songId] = {
      'quality': quality,
      'valence': valence,
      'intensity': intensity,
      'accessibility': accessibility,
      'synthetic': synthetic,
    };
    
    await _saveRatings(ratings);
  }

  static Future<List<LikedSong>> _mergeSongsWithRatings(List<LikedSong> songs) async {
    final ratings = await _loadRatings();
    
    return songs.map((song) {
      final songRatings = ratings[song.id];
      if (songRatings == null) return song;
      
      return LikedSong(
        id: song.id,
        name: song.name,
        artists: song.artists,
        album: song.album,
        addedAt: song.addedAt,
        previewUrl: song.previewUrl,
        durationMs: song.durationMs,
        qualityRating: songRatings['quality'] ?? song.qualityRating,
        valenceRating: songRatings['valence'] ?? song.valenceRating,
        intensityRating: songRatings['intensity'] ?? song.intensityRating,
        accessibilityRating: songRatings['accessibility'] ?? song.accessibilityRating,
        syntheticRating: songRatings['synthetic'] ?? song.syntheticRating,
      );
    }).toList();
  }

  static Future<DateTime?> getMostRecentSongTime() async {
    final cachedSongs = await getCachedLikedSongs();
    if (cachedSongs.isEmpty) return null;
    
    return cachedSongs
        .map((song) => song.addedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  static Future<void> updateSongRatings(String songId, {double? quality, double? valence, double? intensity, double? accessibility, double? synthetic}) async {
    // Save ratings to the separate persistent ratings storage
    await _saveRatingForSong(
      songId,
      quality: quality,
      valence: valence,
      intensity: intensity,
      accessibility: accessibility,
      synthetic: synthetic,
    );
    
    // Clear in-memory cache to force reload with new ratings
    _cachedSongs = null;
    _cacheTimestamp = null;
  }

  static Stream<List<LikedSong>> syncLikedSongs() async* {
    final accessToken = await SpotifyAuthService.getAccessToken();
    if (accessToken == null) {
      throw Exception('No access token available. Please sign in first.');
    }

    // Get cached songs and find the most recent timestamp
    final cachedSongs = await getCachedLikedSongs();
    final mostRecentCachedTime = await getMostRecentSongTime();

    String? nextUrl = '$baseUrl/me/tracks?limit=$limit';
    List<LikedSong> newSongs = [];

    while (nextUrl != null) {
      try {
        final response = await http.get(
          Uri.parse(nextUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final items = data['items'] as List;
          
          final batch = items.map((item) => LikedSong.fromJson(item)).toList();
          
          // If we have cached songs, only process songs newer than our most recent cached song
          if (mostRecentCachedTime != null) {
            final newerSongs = batch.where((song) => song.addedAt.isAfter(mostRecentCachedTime)).toList();
            
            // If no songs in this batch are newer, we can stop syncing
            if (newerSongs.isEmpty) {
              break;
            }
            
            newSongs.addAll(newerSongs);
            yield await _mergeSongsWithRatings(newerSongs);
          } else {
            // First sync - get everything
            newSongs.addAll(batch);
            yield await _mergeSongsWithRatings(batch);
          }
          
          nextUrl = data['next'];
        } else if (response.statusCode == 401) {
          await SpotifyAuthService.signOut();
          throw Exception('Authentication expired. Please sign in again.');
        } else {
          throw Exception('Failed to fetch liked songs: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        if (e.toString().contains('Authentication expired')) {
          rethrow;
        }
        throw Exception('Error fetching liked songs: $e');
      }
    }

    // Save the combined list if we got new songs or this is a first sync
    if (newSongs.isNotEmpty || cachedSongs.isEmpty) {
      // Combine new songs (at the beginning) with cached songs
      final allSongs = [...newSongs, ...cachedSongs];
      await saveLikedSongs(allSongs);
    }
  }
}