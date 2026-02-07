import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

/// Script to approve the first admin user
/// Run with: dart approve_first_admin.dart
void main() async {
  print('Approving first admin user...');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    final firestore = FirebaseFirestore.instance;
    
    // Find user by email
    final email = 'martinmbugua300@gmail.com';
    print('Looking for user: $email');
    
    final usersQuery = await firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    
    if (usersQuery.docs.isEmpty) {
      print('❌ User not found with email: $email');
      print('Please register first in the app, then run this script.');
      return;
    }
    
    final userDoc = usersQuery.docs.first;
    print('✓ Found user: ${userDoc.id}');
    
    // Update user to be approved admin
    await firestore.collection('users').doc(userDoc.id).update({
      'isApproved': true,
      'role': 'admin',
      'approvedAt': Timestamp.now(),
      'approvedBy': 'system',
    });
    
    print('✓ User approved as admin successfully!');
    print('You can now log in with:');
    print('  Email: $email');
    print('  Password: [your password]');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
