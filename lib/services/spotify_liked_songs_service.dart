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
  final int? qualityRating;
  final int? valenceRating;
  final int? intensityRating;

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
    };
  }
}

class SpotifyLikedSongsService {
  static const String baseUrl = 'https://api.spotify.com/v1';
  static const int limit = 50; // Spotify's maximum limit per request
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _likedSongsKey = 'cached_liked_songs';
  static const String _lastSyncKey = 'last_sync_timestamp';

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
          
          // Yield the current batch
          yield batch;
          
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
    final songsJson = songs.map((song) => song.toJson()).toList();
    final jsonString = json.encode(songsJson);
    await _storage.write(key: _likedSongsKey, value: jsonString);
    await _storage.write(key: _lastSyncKey, value: DateTime.now().toIso8601String());
  }

  static Future<List<LikedSong>> getCachedLikedSongs() async {
    final jsonString = await _storage.read(key: _likedSongsKey);
    if (jsonString == null) {
      return [];
    }
    
    try {
      final List<dynamic> songsJson = json.decode(jsonString);
      return songsJson.map((songJson) => LikedSong.fromStorageJson(songJson)).toList();
    } catch (e) {
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
  }

  static Future<DateTime?> getMostRecentSongTime() async {
    final cachedSongs = await getCachedLikedSongs();
    if (cachedSongs.isEmpty) return null;
    
    return cachedSongs
        .map((song) => song.addedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  static Future<void> updateSongRatings(String songId, {int? quality, int? valence, int? intensity}) async {
    final cachedSongs = await getCachedLikedSongs();
    final updatedSongs = cachedSongs.map((song) {
      if (song.id == songId) {
        return LikedSong(
          id: song.id,
          name: song.name,
          artists: song.artists,
          album: song.album,
          addedAt: song.addedAt,
          previewUrl: song.previewUrl,
          durationMs: song.durationMs,
          qualityRating: quality ?? song.qualityRating,
          valenceRating: valence ?? song.valenceRating,
          intensityRating: intensity ?? song.intensityRating,
        );
      }
      return song;
    }).toList();
    
    await saveLikedSongs(updatedSongs);
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
            yield newerSongs;
          } else {
            // First sync - get everything
            newSongs.addAll(batch);
            yield batch;
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