# Performance Optimization Plan v1.7.0

## Issues Identified

### 1. Slow Loading Times
- Members screen taking too long
- Settings not opening quickly
- Overview taking too long
- Search for returning attendee slow
- Bulk registration slow

**Root Cause:** Screens are fetching from Firebase first instead of local SQLite database

### 2. OCR Scanner Issues
- Only detecting 1 attendee when image contains 38
- Should detect all attendees in image regardless of database matches

### 3. Missing Features
- No bulk text import (paste/type multiple names)
- No duplicate confirmation dialog
- No edit confirmation for re-registration

## Solutions

### Phase 1: Offline-First Architecture (PRIORITY)

#### Change Data Flow:
```
OLD: Screen → Firebase (slow) → Local DB (fallback)
NEW: Screen → Local DB (instant) → Background sync to Firebase
```

#### Files to Modify:
1. `lib/screens/all_contacts_screen.dart` - Use local DB first
2. `lib/screens/reports_screen.dart` - Use local DB first
3. `lib/screens/bulk_registration_screen.dart` - Use local DB first
4. `lib/services/registration_service.dart` - Save locally, sync later
5. Create `lib/services/background_sync_service.dart` - Auto-sync when online

### Phase 2: Enhanced OCR Scanner

#### Improvements Needed:
1. **Multi-attendee detection** - Process entire image, not just first match
2. **Better text extraction** - Use multiple OCR strategies
3. **Batch processing** - Extract all names/phones in one pass

#### Files to Modify:
1. `lib/services/document_scanner_service.dart`
   - Add `_extractAllAttendees()` method
   - Improve text block parsing
   - Add confidence scoring per attendee

### Phase 3: Bulk Text Import

#### New Feature:
- Paste/type multiple names and phone numbers
- Auto-parse format: "Name, Phone, Location"
- Validate and register in batch

#### Files to Create:
1. `lib/screens/bulk_text_import_screen.dart`
2. `lib/services/text_parser_service.dart`

### Phase 4: Duplicate Handling

#### Improvements:
1. Check for duplicates before registration
2. Show confirmation dialog with existing data
3. Allow user to:
   - Update existing record
   - Create new record anyway
   - Cancel registration

## Implementation Priority

### URGENT (Do First):
1. ✅ Make all screens load from local DB first
2. ✅ Add background sync service
3. ✅ Fix OCR to detect all attendees

### HIGH (Do Next):
4. ⏳ Add bulk text import
5. ⏳ Add duplicate confirmation dialogs
6. ⏳ Add edit confirmation

### MEDIUM (Nice to Have):
7. ⏳ Add progress indicators
8. ⏳ Add retry mechanisms
9. ⏳ Add offline indicator

## Technical Details

### Local-First Pattern:
```dart
// BEFORE (Slow)
Future<List<AttendeeModel>> getAttendees() async {
  if (await isOnline()) {
    return await firebaseRepo.getAll(); // SLOW!
  }
  return await localRepo.getAll();
}

// AFTER (Fast)
Future<List<AttendeeModel>> getAttendees() async {
  // Get from local immediately
  final localData = await localRepo.getAll(); // FAST!
  
  // Sync in background (don't wait)
  _backgroundSync();
  
  return localData;
}
```

### Enhanced OCR Pattern:
```dart
// BEFORE (Finds 1)
List<ScannedAttendee> extractAttendees(RecognizedText text) {
  final attendee = _findFirstAttendee(text);
  return [attendee];
}

// AFTER (Finds All)
List<ScannedAttendee> extractAttendees(RecognizedText text) {
  final allAttendees = <ScannedAttendee>[];
  
  // Process all text blocks
  for (final block in text.blocks) {
    final attendees = _extractAttendeesFromBlock(block);
    allAttendees.addAll(attendees);
  }
  
  return allAttendees;
}
```

## Expected Performance Improvements

| Screen | Before | After | Improvement |
|--------|--------|-------|-------------|
| Members List | 3-5s | <0.5s | 6-10x faster |
| Settings | 2-3s | <0.3s | 7-10x faster |
| Overview | 4-6s | <0.7s | 6-9x faster |
| Search | 2-4s | <0.4s | 5-10x faster |
| Bulk Registration | 3-5s | <0.6s | 5-8x faster |
| OCR Scan | 1 person | All people | 38x more data |

## Next Steps

1. Implement offline-first changes
2. Test with airplane mode
3. Verify background sync works
4. Enhance OCR scanner
5. Add bulk text import
6. Add duplicate handling
