import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SpotifyAuthService {
  static const String clientId = 'b588d0ec58d346899744fb573f271d0c';
  static const String redirectUri = 'http://localhost:8080';
  static const String authUrl = 'https://accounts.spotify.com/authorize';
  static const String tokenUrl = 'https://accounts.spotify.com/api/token';
  
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  static String? _accessToken;
  static String? _refreshToken;
  static DateTime? _tokenExpiry;

  static String _generateCodeVerifier() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(128, (i) => chars[random.nextInt(chars.length)]).join();
  }

  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  static Future<void> signIn() async {
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);
    
    await _storage.write(key: 'code_verifier', value: codeVerifier);
    
    final params = {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': codeChallenge,
      'scope': 'user-read-private user-read-email playlist-read-private playlist-read-collaborative user-library-read',
    };
    
    final uri = Uri.parse(authUrl).replace(queryParameters: params);
    
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Fallback to platform default if external application fails
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (e2) {
        throw Exception('Could not launch Spotify authorization URL: $e2');
      }
    }
  }

  static Future<void> handleCallback(Uri callbackUri) async {
    final code = callbackUri.queryParameters['code'];
    final error = callbackUri.queryParameters['error'];
    
    if (error != null) {
      throw Exception('Authorization error: $error');
    }
    
    if (code == null) {
      throw Exception('No authorization code received');
    }
    
    final codeVerifier = await _storage.read(key: 'code_verifier');
    if (codeVerifier == null) {
      throw Exception('Code verifier not found');
    }
    
    await _exchangeCodeForToken(code, codeVerifier);
  }

  static Future<void> _exchangeCodeForToken(String code, String codeVerifier) async {
    final response = await http.post(
      Uri.parse(tokenUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'client_id': clientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': codeVerifier,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _accessToken = data['access_token'];
      _refreshToken = data['refresh_token'];
      _tokenExpiry = DateTime.now().add(Duration(seconds: data['expires_in']));
      
      await _storage.write(key: 'access_token', value: _accessToken!);
      await _storage.write(key: 'refresh_token', value: _refreshToken!);
      await _storage.write(key: 'token_expiry', value: _tokenExpiry!.toIso8601String());
      
      await _storage.delete(key: 'code_verifier');
    } else {
      throw Exception('Failed to exchange code for token: ${response.body}');
    }
  }

  static Future<String?> getAccessToken() async {
    if (_accessToken == null) {
      _accessToken = await _storage.read(key: 'access_token');
      final expiryString = await _storage.read(key: 'token_expiry');
      if (expiryString != null) {
        _tokenExpiry = DateTime.parse(expiryString);
      }
    }
    
    if (_accessToken != null && _tokenExpiry != null) {
      if (DateTime.now().isBefore(_tokenExpiry!)) {
        return _accessToken;
      } else {
        await _refreshAccessToken();
        return _accessToken;
      }
    }
    
    return null;
  }

  static Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) {
      _refreshToken = await _storage.read(key: 'refresh_token');
    }
    
    if (_refreshToken == null) {
      throw Exception('No refresh token available');
    }

    final response = await http.post(
      Uri.parse(tokenUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': _refreshToken!,
        'client_id': clientId,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _accessToken = data['access_token'];
      _tokenExpiry = DateTime.now().add(Duration(seconds: data['expires_in']));
      
      await _storage.write(key: 'access_token', value: _accessToken!);
      await _storage.write(key: 'token_expiry', value: _tokenExpiry!.toIso8601String());
      
      if (data['refresh_token'] != null) {
        _refreshToken = data['refresh_token'];
        await _storage.write(key: 'refresh_token', value: _refreshToken!);
      }
    } else {
      throw Exception('Failed to refresh token: ${response.body}');
    }
  }

  static Future<bool> isSignedIn() async {
    final token = await getAccessToken();
    return token != null;
  }

  static Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'token_expiry');
  }
}
