import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:logger/logger.dart';
import 'package:plezy/utils/media_server_http_client.dart';
import 'base_shared_preferences_service.dart';

/// Service to check for new versions from the self-hosted update server.
/// Only enabled when ENABLE_UPDATE_CHECK build flag is set.
class UpdateService {
  static final Logger _logger = Logger();
  static const String _updateBaseUrl = 'https://swag.obs1.duckdns.org';
  static const String _manifestUrl = '$_updateBaseUrl/plezy.json';

  static const String _keySkippedVersion = 'update_skipped_version';
  static const String _keyLastCheckTime = 'update_last_check_time';

  // Check cooldown: 6 hours
  static const Duration _checkCooldown = Duration(hours: 6);

  /// Check if update checking is enabled via build flag
  static bool get isUpdateCheckEnabled {
    return const bool.fromEnvironment('ENABLE_UPDATE_CHECK', defaultValue: false);
  }

  /// Native updater is not used — always false.
  static bool get useNativeUpdater => false;

  /// No-op kept for call-site compatibility.
  static Future<void> checkForUpdatesNative({bool inBackground = true}) async {}

  /// Determine the APK download URL for the current device ABI.
  static Future<String> _apkUrl() async {
    try {
      final result = await Process.run('getprop', ['ro.product.cpu.abi']);
      final abi = result.stdout.toString().trim();
      if (abi.contains('x86_64')) return '$_updateBaseUrl/plezy-x86_64.apk';
      if (abi.contains('arm64')) return '$_updateBaseUrl/plezy-arm64.apk';
    } catch (_) {}
    return '$_updateBaseUrl/plezy-armv7.apk';
  }

  static Future<void> skipVersion(String version) async {
    final prefs = await BaseSharedPreferencesService.sharedCache();
    await prefs.setString(_keySkippedVersion, version);
  }

  static Future<String?> getSkippedVersion() async {
    final prefs = await BaseSharedPreferencesService.sharedCache();
    return prefs.getString(_keySkippedVersion);
  }

  static Future<void> clearSkippedVersion() async {
    final prefs = await BaseSharedPreferencesService.sharedCache();
    await prefs.remove(_keySkippedVersion);
  }

  /// Check if cooldown period has passed since last check
  static Future<bool> shouldCheckForUpdates() async {
    final prefs = await BaseSharedPreferencesService.sharedCache();
    final lastCheckString = prefs.getString(_keyLastCheckTime);

    if (lastCheckString == null) return true;

    final lastCheck = DateTime.parse(lastCheckString);
    final now = DateTime.now();
    final timeSinceLastCheck = now.difference(lastCheck);

    return timeSinceLastCheck >= _checkCooldown;
  }

  static Future<void> _updateLastCheckTime() async {
    final prefs = await BaseSharedPreferencesService.sharedCache();
    await prefs.setString(_keyLastCheckTime, DateTime.now().toIso8601String());
  }

  /// Internal method that performs the actual update check.
  /// [respectCooldown] - if true, checks cooldown and updates last check time.
  static Future<Map<String, dynamic>?> _performUpdateCheck({required bool respectCooldown}) async {
    if (!isUpdateCheckEnabled) return null;

    if (respectCooldown && !await shouldCheckForUpdates()) return null;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      // Flutter's split-per-abi versionCode = ABI_FACTOR * 1000 + build_number.
      // Strip the ABI offset to recover the real build number.
      final rawCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      final buildNumber = rawCode > 0 ? (rawCode % 1000).toString() : packageInfo.buildNumber;
      final currentVersion =
          buildNumber.isNotEmpty ? '${packageInfo.version}+$buildNumber' : packageInfo.version;

      final response = await httpClient.get(_manifestUrl);

      if (response.statusCode == 200) {
        final data = response.data;
        final latestVersion = data['version'] as String;

        if (_isNewerVersion(latestVersion, currentVersion)) {
          final skippedVersion = await getSkippedVersion();
          if (skippedVersion == latestVersion) {
            if (respectCooldown) await _updateLastCheckTime();
            return null;
          }

          if (respectCooldown) await _updateLastCheckTime();

          return {
            'hasUpdate': true,
            'currentVersion': currentVersion,
            'latestVersion': latestVersion,
            'releaseUrl': await _apkUrl(),
            'publishedAt': data['published_at'] as String? ?? '',
          };
        }
      }

      if (respectCooldown) await _updateLastCheckTime();
    } catch (e) {
      _logger.e('Failed to check for updates: $e');
    }

    return null;
  }

  /// Check for updates on GitHub (manual check, ignores cooldown)
  /// Returns a map with update info, or null if no update or error
  static Future<Map<String, dynamic>?> checkForUpdates() {
    return _performUpdateCheck(respectCooldown: false);
  }

  /// Check for updates on startup (respects cooldown and skipped versions)
  /// Returns update info if available, null otherwise
  static Future<Map<String, dynamic>?> checkForUpdatesOnStartup() {
    return _performUpdateCheck(respectCooldown: true);
  }

  /// Split "1.2.3+4" into semver parts [1,2,3] and build number 4.
  static ({List<int> parts, int build}) _parseVersion(String version) {
    final plusIdx = version.indexOf('+');
    final semver = plusIdx >= 0 ? version.substring(0, plusIdx) : version;
    final buildStr = plusIdx >= 0 ? version.substring(plusIdx + 1) : '0';
    final parts = semver.split('.').map((p) => int.tryParse(p.split('-').first) ?? 0).toList();
    return (parts: parts, build: int.tryParse(buildStr) ?? 0);
  }

  /// Returns true if [newVersion] is strictly newer than [currentVersion].
  /// Compares semver first; falls back to build number when semver is equal.
  static bool _isNewerVersion(String newVersion, String currentVersion) {
    try {
      final n = _parseVersion(newVersion);
      final c = _parseVersion(currentVersion);

      final maxLen = n.parts.length > c.parts.length ? n.parts.length : c.parts.length;
      for (int i = 0; i < maxLen; i++) {
        final np = i < n.parts.length ? n.parts[i] : 0;
        final cp = i < c.parts.length ? c.parts[i] : 0;
        if (np > cp) return true;
        if (np < cp) return false;
      }

      return n.build > c.build;
    } catch (e) {
      _logger.e('Error comparing versions: $e');
      return false;
    }
  }
}
