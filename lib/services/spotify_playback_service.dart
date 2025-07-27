import 'dart:convert';
import 'package:http/http.dart' as http;
import 'spotify_auth_service.dart';

class SpotifyPlaybackService {
  static const String baseUrl = 'https://api.spotify.com/v1';

  static Future<void> playSong(String trackId) async {
    final accessToken = await SpotifyAuthService.getAccessToken();
    if (accessToken == null) {
      throw Exception('No access token available. Please sign in first.');
    }

    try {
      // Start playback with the specific track
      final response = await http.put(
        Uri.parse('$baseUrl/me/player/play'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'uris': ['spotify:track:$trackId'],
        }),
      );

      if (response.statusCode == 204) {
        // Success - playback started
        return;
      } else if (response.statusCode == 404) {
        throw Exception('No active Spotify device found. Please open Spotify and start playing music first.');
      } else if (response.statusCode == 403) {
        final responseBody = response.body;
        if (responseBody.contains('PREMIUM_REQUIRED')) {
          throw Exception('Spotify Premium required for playback control.');
        } else {
          throw Exception('Insufficient permissions. Please sign out and sign in again to grant playback permissions.');
        }
      } else if (response.statusCode == 401) {
        await SpotifyAuthService.signOut();
        throw Exception('Authentication expired. Please sign in again.');
      } else {
        throw Exception('Failed to start playback: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (e.toString().contains('No active Spotify device found')) {
        rethrow;
      } else if (e.toString().contains('Spotify Premium required')) {
        rethrow;
      } else if (e.toString().contains('Insufficient permissions')) {
        rethrow;
      } else if (e.toString().contains('Authentication expired')) {
        rethrow;
      }
      throw Exception('Error starting playback: $e');
    }
  }

  static Future<Map<String, dynamic>?> getCurrentlyPlaying() async {
    final accessToken = await SpotifyAuthService.getAccessToken();
    if (accessToken == null) {
      throw Exception('No access token available. Please sign in first.');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/me/player/currently-playing'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 204) {
        // No content - nothing is currently playing
        return null;
      } else if (response.statusCode == 401) {
        await SpotifyAuthService.signOut();
        throw Exception('Authentication expired. Please sign in again.');
      } else {
        throw Exception('Failed to get currently playing track: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('Authentication expired')) {
        rethrow;
      }
      throw Exception('Error getting currently playing track: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAvailableDevices() async {
    final accessToken = await SpotifyAuthService.getAccessToken();
    if (accessToken == null) {
      throw Exception('No access token available. Please sign in first.');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/me/player/devices'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['devices']);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication expired. Please sign in again.');
      } else {
        throw Exception('Failed to get devices: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting devices: $e');
    }
  }
}