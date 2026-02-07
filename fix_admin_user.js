// Script to fix the admin user in Firestore
// Run with: node fix_admin_user.js

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixAdminUser() {
  try {
    console.log('Looking for user: martinmbugua300@gmail.com');
    
    // Find user by email
    const usersSnapshot = await db.collection('users')
      .where('email', '==', 'martinmbugua300@gmail.com')
      .get();
    
    if (usersSnapshot.empty) {
      console.log('❌ User not found in Firestore');
      console.log('Checking Firebase Auth...');
      
      // Check if user exists in Firebase Auth
      try {
        const userRecord = await admin.auth().getUserByEmail('martinmbugua300@gmail.com');
        console.log('✓ User exists in Firebase Auth:', userRecord.uid);
        
        // Create Firestore document for this user
        await db.collection('users').doc(userRecord.uid).set({
          uid: userRecord.uid,
          email: userRecord.email,
          name: userRecord.displayName || 'Martin',
          role: 'admin',
          isApproved: true,
          createdAt: admin.firestore.Timestamp.now(),
          approvedAt: admin.firestore.Timestamp.now(),
          approvedBy: 'system'
        });
        
        console.log('✓ Created Firestore document for user');
      } catch (authError) {
        console.log('❌ User not found in Firebase Auth either');
        console.log('You need to register first in the app');
      }
    } else {
      // User exists in Firestore, update it
      const userDoc = usersSnapshot.docs[0];
      console.log('✓ Found user in Firestore:', userDoc.id);
      
      await db.collection('users').doc(userDoc.id).update({
        isApproved: true,
        role: 'admin',
        approvedAt: admin.firestore.Timestamp.now(),
        approvedBy: 'system'
      });
      
      console.log('✓ Updated user to approved admin');
    }
    
    console.log('\n✓ Done! You can now log in with:');
    console.log('  Email: martinmbugua300@gmail.com');
    console.log('  Password: [your password]');
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
  
  process.exit(0);
}

fixAdminUser();
