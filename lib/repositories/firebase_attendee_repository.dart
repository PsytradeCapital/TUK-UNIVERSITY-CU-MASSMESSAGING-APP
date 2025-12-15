import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendee_model.dart';
import '../services/encryption_service.dart';

class FirebaseAttendeeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'attendees';

  // Get collection reference
  CollectionReference get _attendeesCollection => 
      _firestore.collection(_collectionName);

  // Create attendee in Firestore
  Future<String> createAttendee(AttendeeModel attendee) async {
    try {
      // Get base data
      final data = attendee.toFirestore();
      
      // Encrypt sensitive fields using enhanced cloud encryption
      final sensitiveFields = ['name', 'phoneNumber', 'location'];
      final encryptedData = await EncryptionService.encryptFirestoreDocument(data, sensitiveFields);
      
      // Add searchable phone hash for lookups
      final phoneHash = await EncryptionService.createSearchablePhoneHash(attendee.phoneNumber);
      encryptedData['phoneHash'] = phoneHash;
      
      // Create document
      final docRef = await _attendeesCollection.add(encryptedData);
      return docRef.id;
    } catch (e) {
      throw FirebaseAttendeeRepositoryException('Failed to create attendee: $e');
    }
  }

  // Get attendee by Firestore ID
  Future<AttendeeModel?> getAttendeeById(String id) async {
    try {
      final docSnapshot = await _attendeesCollection.doc(id).get();
      
      if (!docSnapshot.exists) {
        return null;
      }
      
      final encryptedData = docSnapshot.data() as Map<String, dynamic>;
      
      // Decrypt sensitive fields using enhanced cloud decryption
      final sensitiveFields = ['name', 'phoneNumber', 'location'];
      final data = await EncryptionService.decryptFirestoreDocument(encryptedData, sensitiveFields);
      
      return AttendeeModel.fromFirestore(data, docSnapshot.id);
    } catch (e) {
      throw FirebaseAttendeeRepositoryException('Failed to get attendee by ID: $e');
    }
  }

  // Get all attendees from Firestore
  Future<List<AttendeeModel>> getAllAttendees() async {
    try {
      final querySnapshot = await _attendeesCollection
          .orderBy('createdAt', descending: true)
          .get();
      
      final List<AttendeeModel> attendees = [];
      final sensitiveFields = ['name', 'phoneNumber', 'location'];
      
      for (final doc in querySnapshot.docs) {
        final encryptedData = doc.data() as Map<String, dynamic>;
        
        // Decrypt sensitive fields using enhanced cloud decryption
        final data = await EncryptionService.decryptFirestoreDocument(encryptedData, sensitiveFields);
        
        attendees.add(AttendeeModel.fromFirestore(data, doc.id));
      }
      
      return attendees;
    } catch (e) {
      throw FirebaseAttendeeRepositoryException('Failed to get all attendees: $e');
    }
  }

  // Update attendee in Firestore
  Future<void> updateAttendee(AttendeeModel attendee) async {
    try {
      if (attendee.firestoreId == null) {
        throw FirebaseAttendeeRepositoryException('Cannot update attendee without Firestore ID');
      }
      
      // Get base data
      final data = attendee.toFirestore();
      
      // Encrypt sensitive fields using enhanced cloud encryption
      final sensitiveFields = ['name', 'phoneNumber', 'location'];
      final encryptedData = await EncryptionService.encryptFirestoreDocument(data, sensitiveFields);
      
      // Update searchable phone hash
      final phoneHash = await EncryptionService.createSearchablePhoneHash(attendee.phoneNumber);
      encryptedData['phoneHash'] = phoneHash;
      
      await _attendeesCollection.doc(attendee.firestoreId).update(encryptedData);
    } catch (e) {
      throw FirebaseAttendeeRepositoryException('Failed to update attendee: $e');
    }
  }

  // Delete attendee from Firestore
  Future<void> deleteAttendee(String id) async {
    try {
      await _attendeesCollection.doc(id).delete();
    } catch (e) {
      throw FirebaseAttendeeRepositoryException('Failed to delete attendee: $e');
    }
  }

  // Search attendees by name (requires decrypting all attendees)
  Future<List<AttendeeModel>> searchAttendees(String query) async {
    try {
      // Since names are encrypted, we need to get all attendees and search in memory
      final allAttendees = await getAllAttendees();
      
      // Filter attendees by name containing the query (case-insensitive)
      final filteredAttendees = allAttendees.where((attendee) {
        return attendee.name.toLowerCase().contains(query.toLowerCase());
      }).toList();
      
      // Sort by name
      filteredAttendees.sort((a, b) => a.name.compareTo(b.name));
      
      return filteredAttendees;
    } catch (e) {
      throw FirebaseAttendeeRepositoryException('Failed to search attendees: $e');
    }
  }

  // Get attendees by phone number
  Future<AttendeeModel?> getAttendeeByPhone(String phoneNumber) async {
    try {
      // Create searchable hash for encrypted phone lookup
      final phoneHash = await EncryptionService.createSearchablePhoneHash(phoneNumber);
      
      final querySnapshot = await _attendeesCollection
          .where('phoneHash', isEqualTo: phoneHash)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return null;
      }
      
      final doc = querySnapshot.docs.first;
      final encryptedData = doc.data() as Map<String, dynamic>;
      
      // Decrypt sensitive fields using enhanced cloud decryption
      final sensitiveFields = ['name', 'phoneNumber', 'location'];
      final data = await EncryptionService.decryptFirestoreDocument(encryptedData, sensitiveFields);
      
      return AttendeeModel.fromFirestore(data, doc.id);
    } catch (e) {
      throw FirebaseAttendeeRepositoryException('Failed to get attendee by phone: $e');
    }
  }

  // Get attendees with filters (year, location, category)
  Future<List<AttendeeModel>> getAttendeesWithFilters({
    List<String>? years,
    List<String>? locations,
    List<AttendeeCategory>? categories,
  }) async {
    try {
      Query query = _attendeesCollection;
      
      // Apply filters
      if (years != null && years.isNotEmpty) {
        query = query.where('yearOfStudy', whereIn: years);
      }
      
      if (locations != null && locations.isNotEmpty) {
        query = query.where('location', whereIn: locations);
      }
      
      if (categories != null && categories.isNotEmpty) {
        final categoryStrings = categories
            .map((c) => AttendeeModel.categoryToString(c))
            .toList();
        query = query.where('category', whereIn: categoryStrings);
      }
      
      final querySnapshot = await query.get();
      final List<AttendeeModel> attendees = [];
      final sensitiveFields = ['name', 'phoneNumber', 'location'];
      
      for (final doc in querySnapshot.docs) {
        final encryptedData = doc.data() as Map<String, dynamic>;
        
        // Decrypt sensitive fields using enhanced cloud decryption
        final data = await EncryptionService.decryptFirestoreDocument(encryptedData, sensitiveFields);
        
        attendees.add(AttendeeModel.fromFirestore(data, doc.id));
      }
      
      return attendees;
    } catch (e) {
      throw FirebaseAttendeeRepositoryException('Failed to get attendees with filters: $e');
    }
  }

  // Listen to attendee changes (real-time updates)
  Stream<List<AttendeeModel>> attendeesStream() {
    try {
      return _attendeesCollection
          .orderBy('createdAt', descending: true)
          .snapshots()
          .asyncMap((querySnapshot) async {
        final List<AttendeeModel> attendees = [];
        final sensitiveFields = ['name', 'phoneNumber', 'location'];
        
        for (final doc in querySnapshot.docs) {
          final encryptedData = doc.data() as Map<String, dynamic>;
          
          // Decrypt sensitive fields using enhanced cloud decryption
          final data = await EncryptionService.decryptFirestoreDocument(encryptedData, sensitiveFields);
          
          attendees.add(AttendeeModel.fromFirestore(data, doc.id));
        }
        
        return attendees;
      });
    } catch (e) {
      throw FirebaseAttendeeRepositoryException('Failed to create attendees stream: $e');
    }
  }

  // Get attendees by year of study
  Future<List<AttendeeModel>> getAttendeesByYear(String yearOfStudy) async {
    try {
      final querySnapshot = await _attendeesCollection
          .where('yearOfStudy', isEqualTo: yearOfStudy)
          .get();
      
      final List<AttendeeModel> attendees = [];
      final sensitiveFields = ['name', 'phoneNumber', 'location'];
      
      for (final doc in querySnapshot.docs) {
        final encryptedData = doc.data() as Map<String, dynamic>;
        
        // Decrypt sensitive fields using enhanced cloud decryption
        final data = await EncryptionService.decryptFirestoreDocument(encryptedData, sensitiveFields);
        
        attendees.add(AttendeeModel.fromFirestore(data, doc.id));
      }
      
      return attendees;
    } catch (e) {
      throw FirebaseAttendeeRepositoryException('Failed to get attendees by year: $e');
    }
  }

  // Get attendees by location
  Future<List<AttendeeModel>> getAttendeesByLocation(String location) async {
    try {
      final querySnapshot = await _attendeesCollection
          .where('location', isEqualTo: location)
          .get();
      
      final List<AttendeeModel> attendees = [];
      final sensitiveFields = ['name', 'phoneNumber', 'location'];
      
      for (final doc in querySnapshot.docs) {
        final encryptedData = doc.data() as Map<String, dynamic>;
        
        // Decrypt sensitive fields using enhanced cloud decryption
        final data = await EncryptionService.decryptFirestoreDocument(encryptedData, sensitiveFields);
        
        attendees.add(AttendeeModel.fromFirestore(data, doc.id));
      }
      
      return attendees;
    } catch (e) {
      throw FirebaseAttendeeRepositoryException('Failed to get attendees by location: $e');
    }
  }

  // Get attendees by category
  Future<List<AttendeeModel>> getAttendeesByCategory(AttendeeCategory category) async {
    try {
      final categoryString = AttendeeModel.categoryToString(category);
      final querySnapshot = await _attendeesCollection
          .where('category', isEqualTo: categoryString)
          .get();
      
      final List<AttendeeModel> attendees = [];
      final sensitiveFields = ['name', 'phoneNumber', 'location'];
      
      for (final doc in querySnapshot.docs) {
        final encryptedData = doc.data() as Map<String, dynamic>;
        
        // Decrypt sensitive fields using enhanced cloud decryption
        final data = await EncryptionService.decryptFirestoreDocument(encryptedData, sensitiveFields);
        
        attendees.add(AttendeeModel.fromFirestore(data, doc.id));
      }
      
      return attendees;
    } catch (e) {
      throw FirebaseAttendeeRepositoryException('Failed to get attendees by category: $e');
    }
  }

  // Get total attendees count
  Future<int> getTotalAttendeesCount() async {
    try {
      final querySnapshot = await _attendeesCollection.get();
      return querySnapshot.docs.length;
    } catch (e) {
      throw FirebaseAttendeeRepositoryException('Failed to get total attendees count: $e');
    }
  }

  // Get unique locations
  Future<List<String>> getUniqueLocations() async {
    try {
      final querySnapshot = await _attendeesCollection.get();
      final locations = <String>{};
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['location'] != null) {
          locations.add(data['location'] as String);
        }
      }
      
      final locationList = locations.toList();
      locationList.sort();
      return locationList;
    } catch (e) {
      throw FirebaseAttendeeRepositoryException('Failed to get unique locations: $e');
    }
  }

  // Batch create attendees (for data migration)
  Future<List<String>> batchCreateAttendees(List<AttendeeModel> attendees) async {
    try {
      final batch = _firestore.batch();
      final List<String> documentIds = [];
      
      for (final attendee in attendees) {
        final docRef = _attendeesCollection.doc();
        documentIds.add(docRef.id);
        
        // Get base data
        final data = attendee.toFirestore();
        
        // Encrypt sensitive fields using enhanced cloud encryption
        final sensitiveFields = ['name', 'phoneNumber', 'location'];
        final encryptedData = await EncryptionService.encryptFirestoreDocument(data, sensitiveFields);
        
        // Add searchable phone hash
        final phoneHash = await EncryptionService.createSearchablePhoneHash(attendee.phoneNumber);
        encryptedData['phoneHash'] = phoneHash;
        
        batch.set(docRef, encryptedData);
      }
      
      await batch.commit();
      return documentIds;
    } catch (e) {
      throw FirebaseAttendeeRepositoryException('Failed to batch create attendees: $e');
    }
  }
}

// Custom exception for Firebase attendee repository operations
class FirebaseAttendeeRepositoryException implements Exception {
  final String message;
  
  FirebaseAttendeeRepositoryException(this.message);
  
  @override
  String toString() => 'FirebaseAttendeeRepositoryException: $message';
}
