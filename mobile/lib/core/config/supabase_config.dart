import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env_config.dart';

/// Secure Storage Implementation for Supabase Session Management
class SecureLocalStorage extends LocalStorage {
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _sessionKey = 'supabase_session_secure_key';

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async {
    try {
      return await _secureStorage.read(key: _sessionKey);
    } catch (e) {
      debugPrint('[SecureStorage] Error reading token: $e');
      return null;
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    final token = await accessToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _secureStorage.write(key: _sessionKey, value: persistSessionString);
    } catch (e) {
      debugPrint('[SecureStorage] Error persisting session: $e');
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _secureStorage.delete(key: _sessionKey);
    } catch (e) {
      debugPrint('[SecureStorage] Error deleting session: $e');
    }
  }
}

/// Supabase client provider and initializer
class SupabaseConfig {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const String _urlStorageKey = 'custom_supabase_url';
  static const String _anonStorageKey = 'custom_supabase_anon_key';

  static String _activeUrl = EnvConfig.supabaseUrl;
  static String _activeAnonKey = EnvConfig.supabaseAnonKey;
  static SupabaseClient? _dynamicClient;

  static String get activeUrl => _activeUrl;
  static String get activeAnonKey => _activeAnonKey;
  static bool get isDemoHost => _activeUrl.contains('demo-uet-societies');

  static SupabaseClient get client {
    if (_dynamicClient != null) return _dynamicClient!;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return _dynamicClient ??= SupabaseClient(
        'https://supabase.co',
        'dummy-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
    }
  }

  static Future<void> initialize() async {
    try {
      final savedUrl = await _storage.read(key: _urlStorageKey);
      final savedKey = await _storage.read(key: _anonStorageKey);
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        _activeUrl = savedUrl.trim();
      }
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        _activeAnonKey = savedKey.trim();
      }
    } catch (e) {
      debugPrint('[SupabaseConfig] Failed to read saved credentials: $e');
    }

    // Only attempt real Supabase initialization if a live, non-demo host was configured
    if (!isDemoHost) {
      try {
        await Supabase.initialize(
          url: _activeUrl,
          anonKey: _activeAnonKey,
          authOptions: FlutterAuthClientOptions(
            localStorage: SecureLocalStorage(),
            autoRefreshToken: true,
          ),
          realtimeClientOptions: const RealtimeClientOptions(
            logLevel: RealtimeLogLevel.info,
          ),
        );
      } catch (e) {
        debugPrint('[SupabaseConfig] Supabase.initialize error: $e');
      }

      // Listen to auth state changes to safely handle session refresh failures
      try {
        client.auth.onAuthStateChange.listen((data) {
          final AuthChangeEvent event = data.event;
          if (event == AuthChangeEvent.tokenRefreshed) {
            debugPrint('[Auth] Token successfully refreshed.');
          } else if (event == AuthChangeEvent.signedOut) {
            debugPrint('[Auth] User signed out or refresh token expired.');
          }
        });
      } catch (_) {}
    }
  }

  static Future<void> saveCustomBackend({
    required String url,
    required String anonKey,
  }) async {
    final cleanUrl = url.trim();
    final cleanKey = anonKey.trim();
    _activeUrl = cleanUrl;
    _activeAnonKey = cleanKey;

    await _storage.write(key: _urlStorageKey, value: cleanUrl);
    await _storage.write(key: _anonStorageKey, value: cleanKey);

    _dynamicClient = SupabaseClient(
      cleanUrl,
      cleanKey,
      authOptions: const AuthClientOptions(
        autoRefreshToken: true,
      ),
    );
  }

  static Future<void> resetToDefault() async {
    await _storage.delete(key: _urlStorageKey);
    await _storage.delete(key: _anonStorageKey);
    _activeUrl = EnvConfig.supabaseUrl;
    _activeAnonKey = EnvConfig.supabaseAnonKey;
    _dynamicClient = null;
  }
}

final supabaseClientProvider = Provider<SupabaseClient>((ref) => SupabaseConfig.client);
