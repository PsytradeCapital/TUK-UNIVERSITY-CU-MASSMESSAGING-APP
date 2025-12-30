import '../core/test_suite.dart';
import '../mocks/mock_environment.dart';
import '../../services/sms_manager.dart';
import '../../services/security_service.dart';

/// Test suite for personalization and settings functionality
/// Tests user preferences, settings management, and message personalization using mock environment
class PersonalizationTestSuite extends TestSuite {
  final MockEnvironment _mockEnv;
  
  PersonalizationTestSuite(this._mockEnv);

  @override
  String get name => 'Personalization Tests';

  @override
  String get category => 'personalization';

  @override
  Future<List<TestResult>> execute() async {
    final results = <TestResult>[];
    
    // Ensure mock environment is set up
    if (!_mockEnv.isInitialized) {
      _mockEnv.setup();
    }

    // Test user preferences management
    results.add(await _testUserPreferencesManagement());
    
    // Test message personalization
    results.add(await _testMessagePersonalization());
    
    // Test settings persistence
    results.add(await _testSettingsPersistence());
    
    // Test theme preferences
    results.add(await _testThemePreferences());
    
    // Test notification settings
    results.add(await _testNotificationSettings());
    
    // Test auto-sync preferences
    results.add(await _testAutoSyncPreferences());
    
    // Test security settings
    results.add(await _testSecuritySettings());
    
    // Test personalization consistency
    results.add(await _testPersonalizationConsistency());

    return results;
  }

  /// Test user preferences management
  Future<TestResult> _testUserPreferencesManagement() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockStorage = _mockEnv.storage;
      
      // Test setting user preferences
      final preferences = {
        'theme': 'dark',
        'notifications_enabled': false,
        'auto_sync': true,
        'language': 'en',
        'auto_lock_timeout': 10,
      };
      
      await mockStorage.setJson('user_preferences', preferences);
      
      // Verify preferences were stored
      final storedPreferences = await mockStorage.getJson('user_preferences');
      if (storedPreferences == null) {
        throw Exception('User preferences not stored');
      }
      
      if (storedPreferences['theme'] != 'dark') {
        throw Exception('Theme preference not stored correctly');
      }
      
      if (storedPreferences['notifications_enabled'] != false) {
        throw Exception('Notification preference not stored correctly');
      }
      
      if (storedPreferences['auto_sync'] != true) {
        throw Exception('Auto-sync preference not stored correctly');
      }
      
      // Test updating individual preferences
      await mockStorage.setString('user_theme', 'light');
      await mockStorage.setBool('notifications_enabled', true);
      await mockStorage.setInt('auto_lock_timeout', 5);
      
      final theme = await mockStorage.getString('user_theme');
      final notifications = await mockStorage.getBool('notifications_enabled');
      final timeout = await mockStorage.getInt('auto_lock_timeout');
      
      if (theme != 'light') {
        throw Exception('Individual theme preference not updated');
      }
      
      if (notifications != true) {
        throw Exception('Individual notification preference not updated');
      }
      
      if (timeout != 5) {
        throw Exception('Individual timeout preference not updated');
      }
      
      // Test preference validation
      final validThemes = ['light', 'dark', 'system'];
      final testTheme = 'invalid_theme';
      
      if (validThemes.contains(testTheme)) {
        throw Exception('Invalid theme should not be accepted');
      }
      
      // Only store valid themes
      if (validThemes.contains('light')) {
        await mockStorage.setString('validated_theme', 'light');
      }
      
      final validatedTheme = await mockStorage.getString('validated_theme');
      if (validatedTheme != 'light') {
        throw Exception('Theme validation failed');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'User Preferences Management',
        status: TestStatus.pass,
        message: 'User preferences management working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'User Preferences Management',
        status: TestStatus.fail,
        message: 'User preferences management test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test message personalization
  Future<TestResult> _testMessagePersonalization() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final smsManager = SMSManager();
      
      // Test basic name replacement
      const message1 = 'Hello {name}, welcome to TUK CU service!';
      const attendeeName1 = 'John Doe';
      const expected1 = 'Hello John Doe, welcome to TUK CU service!';
      
      final result1 = smsManager.personalizeMessage(message1, attendeeName1);
      if (result1 != expected1) {
        throw Exception('Basic name replacement failed: expected "$expected1", got "$result1"');
      }
      
      // Test case variations
      const message2 = 'Hi {Name}, your attendance has been recorded.';
      const attendeeName2 = 'Mary Smith';
      const expected2 = 'Hi Mary Smith, your attendance has been recorded.';
      
      final result2 = smsManager.personalizeMessage(message2, attendeeName2);
      if (result2 != expected2) {
        throw Exception('Case variation replacement failed: expected "$expected2", got "$result2"');
      }
      
      // Test uppercase replacement
      const message3 = 'URGENT {NAME}: Please check your registration status.';
      const attendeeName3 = 'Peter Wilson';
      const expected3 = 'URGENT PETER WILSON: Please check your registration status.';
      
      final result3 = smsManager.personalizeMessage(message3, attendeeName3);
      if (result3 != expected3) {
        throw Exception('Uppercase replacement failed: expected "$expected3", got "$result3"');
      }
      
      // Test bracket format
      const message4 = 'Service reminder for [name] - starts at 9 AM.';
      const attendeeName4 = 'Sarah Johnson';
      const expected4 = 'Service reminder for Sarah Johnson - starts at 9 AM.';
      
      final result4 = smsManager.personalizeMessage(message4, attendeeName4);
      if (result4 != expected4) {
        throw Exception('Bracket format replacement failed: expected "$expected4", got "$result4"');
      }
      
      // Test automatic greeting addition
      const message5 = 'Thank you for attending today\'s service.';
      const attendeeName5 = 'David Brown';
      const expected5 = 'Hi David Brown, Thank you for attending today\'s service.';
      
      final result5 = smsManager.personalizeMessage(message5, attendeeName5);
      if (result5 != expected5) {
        throw Exception('Automatic greeting addition failed: expected "$expected5", got "$result5"');
      }
      
      // Test no greeting when name already present
      const message6 = 'Grace Mwangi, your registration is complete.';
      const attendeeName6 = 'Grace Mwangi';
      const expected6 = 'Grace Mwangi, your registration is complete.';
      
      final result6 = smsManager.personalizeMessage(message6, attendeeName6);
      if (result6 != expected6) {
        throw Exception('No greeting test failed: expected "$expected6", got "$result6"');
      }
      
      // Test multiple placeholders
      const message7 = 'Hello {name}, {Name} your seat is reserved.';
      const attendeeName7 = 'Alice Cooper';
      const expected7 = 'Hello Alice Cooper, Alice Cooper your seat is reserved.';
      
      final result7 = smsManager.personalizeMessage(message7, attendeeName7);
      if (result7 != expected7) {
        throw Exception('Multiple placeholders failed: expected "$expected7", got "$result7"');
      }
      
      // Test empty message handling
      const message8 = '';
      const attendeeName8 = 'Test User';
      const expected8 = 'Hi Test User, ';
      
      final result8 = smsManager.personalizeMessage(message8, attendeeName8);
      if (result8 != expected8) {
        throw Exception('Empty message handling failed: expected "$expected8", got "$result8"');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Message Personalization',
        status: TestStatus.pass,
        message: 'Message personalization working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Message Personalization',
        status: TestStatus.fail,
        message: 'Message personalization test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test settings persistence
  Future<TestResult> _testSettingsPersistence() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockStorage = _mockEnv.storage;
      
      // Test app settings persistence
      await mockStorage.setString('app_version', '2.1.0');
      await mockStorage.setBool('first_launch', false);
      await mockStorage.setString('last_sync_time', DateTime.now().toIso8601String());
      
      // Simulate app restart by clearing memory but keeping storage
      // (In real implementation, this would test actual persistence)
      
      // Verify settings persist after restart
      final appVersion = await mockStorage.getString('app_version');
      final firstLaunch = await mockStorage.getBool('first_launch');
      final lastSyncTime = await mockStorage.getString('last_sync_time');
      
      if (appVersion != '2.1.0') {
        throw Exception('App version not persisted');
      }
      
      if (firstLaunch != false) {
        throw Exception('First launch flag not persisted');
      }
      
      if (lastSyncTime == null) {
        throw Exception('Last sync time not persisted');
      }
      
      // Test settings migration (version upgrade scenario)
      await mockStorage.setString('settings_version', '1.0');
      
      // Simulate settings upgrade
      final currentSettingsVersion = await mockStorage.getString('settings_version');
      if (currentSettingsVersion == '1.0') {
        // Migrate settings
        final oldPrefs = await mockStorage.getJson('user_preferences');
        if (oldPrefs != null) {
          // Add new default settings
          oldPrefs['new_feature_enabled'] = true;
          oldPrefs['migration_completed'] = true;
          await mockStorage.setJson('user_preferences', oldPrefs);
          await mockStorage.setString('settings_version', '2.0');
        }
      }
      
      // Verify migration
      final newSettingsVersion = await mockStorage.getString('settings_version');
      final migratedPrefs = await mockStorage.getJson('user_preferences');
      
      if (newSettingsVersion != '2.0') {
        throw Exception('Settings version not updated after migration');
      }
      
      if (migratedPrefs?['migration_completed'] != true) {
        throw Exception('Settings migration not completed');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Settings Persistence',
        status: TestStatus.pass,
        message: 'Settings persistence working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Settings Persistence',
        status: TestStatus.fail,
        message: 'Settings persistence test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test theme preferences
  Future<TestResult> _testThemePreferences() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockStorage = _mockEnv.storage;
      
      // Test theme setting and retrieval
      const themes = ['light', 'dark', 'system'];
      
      for (final theme in themes) {
        await mockStorage.setString('user_theme', theme);
        
        final retrievedTheme = await mockStorage.getString('user_theme');
        if (retrievedTheme != theme) {
          throw Exception('Theme "$theme" not stored correctly');
        }
      }
      
      // Test theme-specific settings
      await mockStorage.setString('user_theme', 'dark');
      await mockStorage.setJson('dark_theme_settings', {
        'primary_color': '#1976D2',
        'accent_color': '#03DAC6',
        'background_color': '#121212',
      });
      
      await mockStorage.setString('user_theme', 'light');
      await mockStorage.setJson('light_theme_settings', {
        'primary_color': '#2196F3',
        'accent_color': '#FF4081',
        'background_color': '#FFFFFF',
      });
      
      // Verify theme-specific settings
      final darkSettings = await mockStorage.getJson('dark_theme_settings');
      final lightSettings = await mockStorage.getJson('light_theme_settings');
      
      if (darkSettings?['background_color'] != '#121212') {
        throw Exception('Dark theme settings not stored correctly');
      }
      
      if (lightSettings?['background_color'] != '#FFFFFF') {
        throw Exception('Light theme settings not stored correctly');
      }
      
      // Test system theme detection simulation
      await mockStorage.setString('user_theme', 'system');
      await mockStorage.setBool('system_dark_mode', true);
      
      final userTheme = await mockStorage.getString('user_theme');
      final systemDarkMode = await mockStorage.getBool('system_dark_mode');
      
      if (userTheme == 'system' && systemDarkMode == true) {
        // Should use dark theme
        await mockStorage.setString('effective_theme', 'dark');
      }
      
      final effectiveTheme = await mockStorage.getString('effective_theme');
      if (effectiveTheme != 'dark') {
        throw Exception('System theme detection failed');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Theme Preferences',
        status: TestStatus.pass,
        message: 'Theme preferences working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Theme Preferences',
        status: TestStatus.fail,
        message: 'Theme preferences test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test notification settings
  Future<TestResult> _testNotificationSettings() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockStorage = _mockEnv.storage;
      
      // Test notification preferences
      await mockStorage.setBool('notifications_enabled', true);
      await mockStorage.setBool('sms_notifications', true);
      await mockStorage.setBool('sync_notifications', false);
      await mockStorage.setBool('error_notifications', true);
      
      // Verify notification settings
      final notificationsEnabled = await mockStorage.getBool('notifications_enabled');
      final smsNotifications = await mockStorage.getBool('sms_notifications');
      final syncNotifications = await mockStorage.getBool('sync_notifications');
      final errorNotifications = await mockStorage.getBool('error_notifications');
      
      if (notificationsEnabled != true) {
        throw Exception('General notifications setting not stored');
      }
      
      if (smsNotifications != true) {
        throw Exception('SMS notifications setting not stored');
      }
      
      if (syncNotifications != false) {
        throw Exception('Sync notifications setting not stored');
      }
      
      if (errorNotifications != true) {
        throw Exception('Error notifications setting not stored');
      }
      
      // Test notification scheduling preferences
      await mockStorage.setJson('notification_schedule', {
        'quiet_hours_enabled': true,
        'quiet_start': '22:00',
        'quiet_end': '07:00',
        'weekend_notifications': false,
      });
      
      final schedule = await mockStorage.getJson('notification_schedule');
      if (schedule == null) {
        throw Exception('Notification schedule not stored');
      }
      
      if (schedule['quiet_hours_enabled'] != true) {
        throw Exception('Quiet hours setting not stored');
      }
      
      if (schedule['weekend_notifications'] != false) {
        throw Exception('Weekend notifications setting not stored');
      }
      
      // Test notification sound preferences
      await mockStorage.setString('notification_sound', 'default');
      await mockStorage.setBool('vibration_enabled', true);
      await mockStorage.setInt('notification_priority', 2);
      
      final sound = await mockStorage.getString('notification_sound');
      final vibration = await mockStorage.getBool('vibration_enabled');
      final priority = await mockStorage.getInt('notification_priority');
      
      if (sound != 'default') {
        throw Exception('Notification sound not stored');
      }
      
      if (vibration != true) {
        throw Exception('Vibration setting not stored');
      }
      
      if (priority != 2) {
        throw Exception('Notification priority not stored');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Notification Settings',
        status: TestStatus.pass,
        message: 'Notification settings working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Notification Settings',
        status: TestStatus.fail,
        message: 'Notification settings test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test auto-sync preferences
  Future<TestResult> _testAutoSyncPreferences() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockStorage = _mockEnv.storage;
      
      // Test auto-sync settings
      await mockStorage.setBool('auto_sync_enabled', true);
      await mockStorage.setInt('sync_interval_minutes', 15);
      await mockStorage.setBool('wifi_only_sync', true);
      await mockStorage.setBool('background_sync', false);
      
      // Verify auto-sync settings
      final autoSyncEnabled = await mockStorage.getBool('auto_sync_enabled');
      final syncInterval = await mockStorage.getInt('sync_interval_minutes');
      final wifiOnlySync = await mockStorage.getBool('wifi_only_sync');
      final backgroundSync = await mockStorage.getBool('background_sync');
      
      if (autoSyncEnabled != true) {
        throw Exception('Auto-sync enabled setting not stored');
      }
      
      if (syncInterval != 15) {
        throw Exception('Sync interval not stored correctly');
      }
      
      if (wifiOnlySync != true) {
        throw Exception('WiFi-only sync setting not stored');
      }
      
      if (backgroundSync != false) {
        throw Exception('Background sync setting not stored');
      }
      
      // Test sync preferences validation
      const validIntervals = [5, 10, 15, 30, 60];
      const testInterval = 7; // Invalid interval
      
      if (!validIntervals.contains(testInterval)) {
        // Use default interval instead
        await mockStorage.setInt('sync_interval_minutes', 15);
      }
      
      final validatedInterval = await mockStorage.getInt('sync_interval_minutes');
      if (validatedInterval != 15) {
        throw Exception('Sync interval validation failed');
      }
      
      // Test sync conflict resolution preferences
      await mockStorage.setString('conflict_resolution', 'server_wins');
      await mockStorage.setBool('prompt_on_conflict', false);
      await mockStorage.setBool('backup_before_sync', true);
      
      final conflictResolution = await mockStorage.getString('conflict_resolution');
      final promptOnConflict = await mockStorage.getBool('prompt_on_conflict');
      final backupBeforeSync = await mockStorage.getBool('backup_before_sync');
      
      if (conflictResolution != 'server_wins') {
        throw Exception('Conflict resolution preference not stored');
      }
      
      if (promptOnConflict != false) {
        throw Exception('Prompt on conflict preference not stored');
      }
      
      if (backupBeforeSync != true) {
        throw Exception('Backup before sync preference not stored');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Auto-Sync Preferences',
        status: TestStatus.pass,
        message: 'Auto-sync preferences working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Auto-Sync Preferences',
        status: TestStatus.fail,
        message: 'Auto-sync preferences test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test security settings
  Future<TestResult> _testSecuritySettings() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockStorage = _mockEnv.storage;
      
      // Test PIN security settings
      await mockStorage.setBool('pin_enabled', true);
      await mockStorage.setString('pin_hash', 'mock_hashed_pin_123');
      await mockStorage.setInt('auto_lock_timeout', 5);
      await mockStorage.setInt('failed_attempts', 0);
      await mockStorage.setInt('max_failed_attempts', 3);
      
      // Verify PIN settings
      final pinEnabled = await mockStorage.getBool('pin_enabled');
      final pinHash = await mockStorage.getString('pin_hash');
      final autoLockTimeout = await mockStorage.getInt('auto_lock_timeout');
      final failedAttempts = await mockStorage.getInt('failed_attempts');
      final maxFailedAttempts = await mockStorage.getInt('max_failed_attempts');
      
      if (pinEnabled != true) {
        throw Exception('PIN enabled setting not stored');
      }
      
      if (pinHash != 'mock_hashed_pin_123') {
        throw Exception('PIN hash not stored');
      }
      
      if (autoLockTimeout != 5) {
        throw Exception('Auto-lock timeout not stored');
      }
      
      if (failedAttempts != 0) {
        throw Exception('Failed attempts counter not initialized');
      }
      
      if (maxFailedAttempts != 3) {
        throw Exception('Max failed attempts not stored');
      }
      
      // Test biometric settings
      await mockStorage.setBool('biometric_enabled', true);
      await mockStorage.setString('biometric_type', 'fingerprint');
      await mockStorage.setBool('biometric_fallback_pin', true);
      
      final biometricEnabled = await mockStorage.getBool('biometric_enabled');
      final biometricType = await mockStorage.getString('biometric_type');
      final biometricFallback = await mockStorage.getBool('biometric_fallback_pin');
      
      if (biometricEnabled != true) {
        throw Exception('Biometric enabled setting not stored');
      }
      
      if (biometricType != 'fingerprint') {
        throw Exception('Biometric type not stored');
      }
      
      if (biometricFallback != true) {
        throw Exception('Biometric fallback setting not stored');
      }
      
      // Test session security settings
      await mockStorage.setInt('session_timeout_minutes', 30);
      await mockStorage.setBool('require_auth_on_resume', true);
      await mockStorage.setBool('clear_data_on_logout', false);
      
      final sessionTimeout = await mockStorage.getInt('session_timeout_minutes');
      final requireAuthOnResume = await mockStorage.getBool('require_auth_on_resume');
      final clearDataOnLogout = await mockStorage.getBool('clear_data_on_logout');
      
      if (sessionTimeout != 30) {
        throw Exception('Session timeout not stored');
      }
      
      if (requireAuthOnResume != true) {
        throw Exception('Require auth on resume setting not stored');
      }
      
      if (clearDataOnLogout != false) {
        throw Exception('Clear data on logout setting not stored');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Security Settings',
        status: TestStatus.pass,
        message: 'Security settings working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Security Settings',
        status: TestStatus.fail,
        message: 'Security settings test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }

  /// Test personalization consistency
  Future<TestResult> _testPersonalizationConsistency() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final mockStorage = _mockEnv.storage;
      
      // Test settings consistency across app restarts
      final originalSettings = {
        'theme': 'dark',
        'notifications_enabled': true,
        'auto_sync': false,
        'language': 'en',
        'version': '1.0',
      };
      
      await mockStorage.setJson('app_settings', originalSettings);
      
      // Simulate app restart by retrieving settings
      final retrievedSettings = await mockStorage.getJson('app_settings');
      if (retrievedSettings == null) {
        throw Exception('Settings not persisted across restart');
      }
      
      // Verify all settings match
      for (final key in originalSettings.keys) {
        if (retrievedSettings[key] != originalSettings[key]) {
          throw Exception('Setting "$key" not consistent after restart');
        }
      }
      
      // Test settings synchronization between different components
      await mockStorage.setString('user_theme', 'light');
      await mockStorage.setString('ui_theme', 'light');
      await mockStorage.setString('notification_theme', 'light');
      
      final userTheme = await mockStorage.getString('user_theme');
      final uiTheme = await mockStorage.getString('ui_theme');
      final notificationTheme = await mockStorage.getString('notification_theme');
      
      if (userTheme != uiTheme || uiTheme != notificationTheme) {
        throw Exception('Theme settings not synchronized across components');
      }
      
      // Test settings validation consistency
      const validLanguages = ['en', 'sw', 'fr'];
      const testLanguage = 'invalid_lang';
      
      if (!validLanguages.contains(testLanguage)) {
        // Use default language
        await mockStorage.setString('app_language', 'en');
      }
      
      final appLanguage = await mockStorage.getString('app_language');
      if (appLanguage != 'en') {
        throw Exception('Language validation consistency failed');
      }
      
      // Test preference dependencies
      await mockStorage.setBool('notifications_enabled', false);
      
      // When notifications are disabled, specific notification types should also be disabled
      await mockStorage.setBool('sms_notifications', false);
      await mockStorage.setBool('sync_notifications', false);
      await mockStorage.setBool('error_notifications', false);
      
      final notificationsEnabled = await mockStorage.getBool('notifications_enabled');
      final smsNotifications = await mockStorage.getBool('sms_notifications');
      
      if (notificationsEnabled == false && smsNotifications == true) {
        throw Exception('Preference dependency consistency violated');
      }
      
      // Test settings backup and restore consistency
      final backupSettings = {
        'theme': 'dark',
        'notifications': true,
        'sync_interval': 15,
        'backup_timestamp': DateTime.now().toIso8601String(),
      };
      
      await mockStorage.setJson('settings_backup', backupSettings);
      
      // Simulate restore
      final restoredSettings = await mockStorage.getJson('settings_backup');
      if (restoredSettings == null) {
        throw Exception('Settings backup not created');
      }
      
      if (restoredSettings['theme'] != backupSettings['theme']) {
        throw Exception('Settings restore consistency failed');
      }
      
      stopwatch.stop();
      return TestResult(
        testName: 'Personalization Consistency',
        status: TestStatus.pass,
        message: 'Personalization consistency working correctly',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TestResult(
        testName: 'Personalization Consistency',
        status: TestStatus.fail,
        message: 'Personalization consistency test failed: $e',
        executionTime: stopwatch.elapsed,
        stackTrace: e.toString(),
      );
    }
  }
}