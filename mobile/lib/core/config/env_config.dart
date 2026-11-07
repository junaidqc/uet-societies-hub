/// Environment configuration constants.
/// In production, compile with:
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://efbccttyfinvmypadctj.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVmYmNjdHR5Zmludm15cGFkY3RqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQwMzY5MTksImV4cCI6MjEwOTYxMjkxOX0.Eh11Nsilns68cOCZVc1kgX6PtUXIzOuqjpFWjprbdSw',
  );

  static const String appName = 'UET Societies Hub';
  static const String uetEmailDomain = '@uet.edu.pk';
}
