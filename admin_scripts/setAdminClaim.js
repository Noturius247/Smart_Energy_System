const admin = require('firebase-admin');

// IMPORTANT: Replace with the path to your service account key file.
// You can download this from Firebase Console -> Project settings -> Service accounts.
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const uid = process.argv[2]; // UID passed as a command-line argument
const isAdmin = process.argv[3] === 'true'; // 'true' or 'false'

if (!uid) {
  console.error('Usage: node setAdminClaim.js <uid> [isAdmin (true/false)]');
  process.exit(1);
}

async function setCustomUserClaim(targetUid, adminStatus) {
  try {
    await admin.auth().setCustomUserClaims(targetUid, { admin: adminStatus });

    // Verify the claim was set
    const user = await admin.auth().getUser(targetUid);
    console.log(`Custom claims for user ${targetUid}:`, user.customClaims);

    console.log(`Successfully set admin claim for user ${targetUid} to ${adminStatus}.`);
    process.exit(0);
  } catch (error) {
    console.error('Error setting custom user claim:', error);
    process.exit(1);
  }
}

setCustomUserClaim(uid, isAdmin);
