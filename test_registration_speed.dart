import 'dart:async';
import 'lib/services/fast_registration_service.dart';

/// Quick Registration Speed Test
/// Tests if registration completes in under 500ms
Future<void> main() async {
  print('🚀 Testing Registration Speed...');
  print('Target: Registration should complete in under 500ms');
  print('');

  final fastReg = FastRegistrationService();
  await fastReg.initialize();

  // Test 1: Single registration
  print('Test 1: Single Registration');
  final stopwatch1 = Stopwatch()..start();
  
  final result1 = await fastReg.registerAttendeeInstant(
    name: 'Speed Test User',
    phoneNumber: '+254700${DateTime.now().millisecondsSinceEpoch % 1000000}',
    yearOfStudy: '3rd Year',
    location: 'Main Campus',
  );
  
  stopwatch1.stop();
  final duration1 = stopwatch1.elapsedMilliseconds;
  
  print('  Result: ${result1.success ? "SUCCESS" : "FAILED"}');
  print('  Time: ${duration1}ms');
  print('  Status: ${duration1 < 500 ? "✅ FAST ENOUGH" : "❌ TOO SLOW"}');
  print('');

  // Test 2: Rapid registrations (simulating queue)
  print('Test 2: Rapid Registrations (5 users in sequence)');
  final stopwatch2 = Stopwatch()..start();
  
  int successCount = 0;
  for (int i = 0; i < 5; i++) {
    final result = await fastReg.registerAttendeeInstant(
      name: 'Queue User $i',
      phoneNumber: '+254701${DateTime.now().millisecondsSinceEpoch % 1000000 + i}',
      yearOfStudy: '${(i % 4) + 1}st Year',
      location: 'Campus $i',
    );
    if (result.success) successCount++;
  }
  
  stopwatch2.stop();
  final duration2 = stopwatch2.elapsedMilliseconds;
  final avgTime = duration2 / 5;
  
  print('  Registered: $successCount/5 users');
  print('  Total time: ${duration2}ms');
  print('  Average per user: ${avgTime.toStringAsFixed(1)}ms');
  print('  Status: ${avgTime < 500 ? "✅ FAST ENOUGH" : "❌ TOO SLOW"}');
  print('');

  // Test 3: Background sync status
  print('Test 3: Background Sync Status');
  final stats = await fastReg.getStats();
  print('  Total registered: ${stats.totalRegistered}');
  print('  Pending sync: ${stats.pendingSync}');
  print('  Online status: ${stats.isOnline}');
  print('');

  // Summary
  print('📊 SUMMARY');
  print('=' * 30);
  final overallSuccess = result1.success && duration1 < 500 && avgTime < 500;
  print('Registration Speed: ${overallSuccess ? "✅ OPTIMIZED" : "❌ NEEDS IMPROVEMENT"}');
  print('Ready for production queue: ${overallSuccess ? "YES" : "NO"}');
  
  if (!overallSuccess) {
    print('');
    print('💡 RECOMMENDATIONS:');
    if (duration1 >= 500) print('  - Optimize single registration (currently ${duration1}ms)');
    if (avgTime >= 500) print('  - Optimize batch processing (currently ${avgTime.toStringAsFixed(1)}ms avg)');
    print('  - Consider local-first approach with background sync');
    print('  - Minimize database operations during registration');
  }
}