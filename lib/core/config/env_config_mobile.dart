import 'env_config.dart';

EnvPlatform get platformEnv => EnvConfigMobile();

class EnvConfigMobile implements EnvPlatform {
  @override
  String getApiUrl() => const String.fromEnvironment('API_URL', defaultValue: 'https://api.katrix.com.ar');

  @override
  String getMpAccessToken() => const String.fromEnvironment('MP_ACCESS_TOKEN', defaultValue: '');

  @override
  String getMpPublicKey() => const String.fromEnvironment('MP_PUBLIC_KEY', defaultValue: '');
}
