// Firestore Security Rules Test Suite
// Run with: firebase emulators:exec --only firestore "node test-security-rules.js"

const firebase = require('@firebase/testing');
const fs = require('fs');

const PROJECT_ID = 'tuk-cu-messaging-test';
const RULES_FILE = './firestore.rules';

// Test data
const mockUsers = {
  admin: { uid: 'admin-user', role: 'admin', isApproved: true, email: 'admin@tuk.ac.ke' },
  leader: { uid: 'leader-user', role: 'leader', isApproved: true, email: 'leader@tuk.ac.ke' },
  member: { uid: 'member-user', role: 'member', isApproved: true, email: 'member@tuk.ac.ke' },
  unapproved: { uid: 'unapproved-user', role: 'leader', isApproved: false, email: 'pending@tuk.ac.ke' },
  unauthorized: null
};

const mockAttendee = {
  name: 'John Doe',
  phoneNumber: '+254712345678',
  location: 'Nairobi',
  category: 'student',
  serviceId: 1,
  registeredAt: firebase.firestore.Timestamp.now(),
  createdBy: 'leader-user',
  createdAt: firebase.firestore.Timestamp.now(),
  version: 1
};

const mockMessageLog = {
  attendeeId: 'attendee-123',
  message: 'Welcome to TUK CU!',
  sendStatus: 'delivered',
  sentAt: firebase.firestore.Timestamp.now(),
  serviceId: 1,
  sentBy: 'leader-user',
  createdAt: firebase.firestore.Timestamp.now(),
  version: 1
};

// Helper functions
function getFirestore(auth) {
  return firebase.initializeTestApp({
    projectId: PROJECT_ID,
    auth: auth
  }).firestore();
}

function getAdminFirestore() {
  return firebase.initializeAdminApp({
    projectId: PROJECT_ID
  }).firestore();
}

async function setupTestData() {
  const admin = getAdminFirestore();
  
  // Create test users
  for (const [key, user] of Object.entries(mockUsers)) {
    if (user) {
      await admin.collection('users').doc(user.uid).set({
        uid: user.uid,
        email: user.email,
        name: `Test ${key}`,
        role: user.role,
        isApproved: user.isApproved,
        createdAt: firebase.firestore.Timestamp.now()
      });
    }
  }
  
  console.log('✅ Test data setup complete');
}

async function runTests() {
  console.log('🔥 Starting Firestore Security Rules Tests');
  console.log('==========================================');
  
  let passed = 0;
  let failed = 0;
  
  // Test helper function
  async function test(description, testFn) {
    try {
      await testFn();
      console.log(`✅ ${description}`);
      passed++;
    } catch (error) {
      console.log(`❌ ${description}`);
      console.log(`   Error: ${error.message}`);
      failed++;
    }
  }
  
  // Authentication Tests
  console.log('\n📋 Authentication Tests');
  console.log('------------------------');
  
  await test('Unauthenticated users cannot read users collection', async () => {
    const db = getFirestore(null);
    const doc = db.collection('users').doc('admin-user');
    await firebase.assertFails(doc.get());
  });
  
  await test('Authenticated users can read their own profile', async () => {
    const db = getFirestore(mockUsers.leader);
    const doc = db.collection('users').doc('leader-user');
    await firebase.assertSucceeds(doc.get());
  });
  
  await test('Non-admin users cannot read other profiles', async 