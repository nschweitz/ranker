# Ranker - Spotify Integration

A Flutter app with Spotify authentication integration.

## Features

- Spotify OAuth 2.0 authentication with PKCE
- Secure token storage using Flutter Secure Storage
- Token refresh handling
- Clean UI with sign-in/sign-out functionality

## Setup Instructions

### 1. Spotify App Configuration

1. Go to the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Create a new app or use an existing one
3. Add the following redirect URI to your app settings:
   ```
   com.example.ranker://callback
   ```
4. Copy your Client ID

### 2. Update Configuration

1. Open `lib/services/spotify_auth_service.dart`
2. Replace `YOUR_SPOTIFY_CLIENT_ID` with your actual Spotify Client ID:
   ```dart
   static const String clientId = 'your_actual_client_id_here';
   ```

### 3. Run the App

```bash
flutter pub get
flutter run
```

## How It Works

1. **Authentication Flow**: The app uses Spotify's OAuth 2.0 with PKCE (Proof Key for Code Exchange) for secure authentication
2. **Token Management**: Access tokens are stored securely using Flutter Secure Storage and automatically refreshed when expired
3. **Deep Linking**: The app handles OAuth callbacks through custom URL schemes

## Dependencies

- `http`: For making API requests to Spotify
- `url_launcher`: For launching the Spotify authorization URL
- `flutter_secure_storage`: For secure token storage

## Usage

1. Tap "Sign in with Spotify" to start the authentication flow
2. You'll be redirected to Spotify's authorization page
3. After granting permissions, you'll be redirected back to the app
4. The access token will be displayed and stored securely
5. Use the token for future Spotify API calls

## Next Steps

The authentication token can now be used to make requests to the Spotify Web API. Common endpoints include:

- Get user profile: `https://api.spotify.com/v1/me`
- Get user's playlists: `https://api.spotify.com/v1/me/playlists`
- Search for tracks: `https://api.spotify.com/v1/search`

Remember to include the access token in the Authorization header:
```
Authorization: Bearer YOUR_ACCESS_TOKEN
```
