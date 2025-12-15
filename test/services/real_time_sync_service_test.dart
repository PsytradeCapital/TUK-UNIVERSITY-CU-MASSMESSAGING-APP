import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/real_time_sync_service.dart';

void main() {
  group('RealTimeSyncService', () {
    late RealTimeSyncService realTimeSyncService;

    setUp(() {
      realTimeSyncService = RealTimeSyncService();
    });

    test('should be a singleton', () {
      final instance1 = RealTimeSyncService();
      final instance2 = RealTimeSyncService();
      
      expect(instance1, equals(instance2));
    });

    test('should initialize without errors', () async {
      expect(() async => await realTimeSyncService.initialize(), returnsNormally);
    });

    test('should start with listening disabled', () {
      expect(realTimeSyncService.isListening, isFalse);
    });

    test('should provide stream controllers', () {
      expect(realTimeSyncService.attendeeUpdatesStream, isNotNull);
      expect(realTimeSyncService.messageLogUpdatesStream, isNotNull);
      expect(realTimeSyncService.syncEventsStream, isNotNull);
    });

    test('should track attendee and message counts', () {
      expect(realTimeSyncService.currentAttendeeCount, isA<int>());
      expect(realTimeSyncService.currentMessageLogCount, isA<int>());
    });

    test('should handle dispose without errors', () {
      expect(() => realTimeSyncService.dispose(), returnsNormally);
    });
  });
}