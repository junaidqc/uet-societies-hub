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
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureLocalStorage(),
        autoRefreshToken: true,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
    );

    // Listen to auth state changes to safely handle session refresh failures
    client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.tokenRefreshed) {
        debugPrint('[Auth] Token successfully refreshed.');
      } else if (event == AuthChangeEvent.signedOut) {
        debugPrint('[Auth] User signed out or refresh token expired.');
      }
    });
  }
}

final supabaseClientProvider = Provider<SupabaseClient>((ref) => SupabaseConfig.client);
