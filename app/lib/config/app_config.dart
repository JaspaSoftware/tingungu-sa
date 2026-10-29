class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tingungu-api.azurewebsites.net/api',
  );

  static const String legacyBackendUrl = String.fromEnvironment(
    'LEGACY_BACKEND_URL',
    defaultValue: 'https://backend.tingungu.co.za',
  );

  static const String communityApiBaseUrl = String.fromEnvironment(
    'COMMUNITY_API_BASE_URL',
  );

  static const String youtubeApiKey = String.fromEnvironment(
    'YOUTUBE_API_KEY',
  );

  static const String youtubePlaylistId = String.fromEnvironment(
    'YOUTUBE_PLAYLIST_ID',
  );
}
