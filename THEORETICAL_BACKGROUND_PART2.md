# COMPREHENSIVE THEORETICAL BACKGROUND - SMART ENERGY SYSTEM (PART 2)

## 8. SECURITY FEATURES AND AUTHENTICATION MECHANISMS

### 8.1 Authentication System

#### Firebase Authentication Flow

**Authentication Methods Supported:**
1. Email/Password authentication
2. Google Sign-In (OAuth 2.0)
3. Custom token authentication (admin)

**Authentication Architecture:**
```
┌──────────────────┐
│ User enters      │
│ credentials      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Firebase Auth    │
│ validates        │
│ credentials      │
└────────┬─────────┘
         │ Success
         ▼
┌──────────────────┐
│ Token generated  │
│ with custom      │
│ claims (admin)   │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ AuthWrapper      │
│ checks auth      │
│ state            │
└────────┬─────────┘
         │ Authenticated
         ▼
┌──────────────────┐
│ Token claims     │
│ determine        │
│ user role        │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Route to         │
│ appropriate      │
│ home screen      │
└──────────────────┘
```

**Code Implementation:**

```dart
// login.dart
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  // Email/Password Sign In
  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Check if user is admin
      final idTokenResult = await userCredential.user!.getIdTokenResult();
      final isAdmin = idTokenResult.claims?['admin'] == true;

      if (isAdmin) {
        Navigator.pushReplacementNamed(context, '/admin_home');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        default:
          message = 'Authentication failed: ${e.message}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Google Sign In
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // User cancelled
        setState(() => _isLoading = false);
        return;
      }

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);

      // Create user profile if first sign-in
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _createUserProfile(userCredential.user!);
      }

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google Sign-In failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Create user profile in Firestore
  Future<void> _createUserProfile(User user) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email': user.email,
      'fullName': user.displayName ?? '',
      'photoURL': user.photoURL ?? '',
      'pricePerKWH': 11.0,  // Default rate
      'dueDate': Timestamp.fromDate(DateTime.now().add(Duration(days: 30))),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Icon(Icons.bolt, size: 80, color: Colors.blue),
                  SizedBox(height: 24),
                  Text(
                    'Smart Energy System',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  SizedBox(height: 48),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 24),

                  // Sign In button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signInWithEmail,
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text('Sign In'),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Google Sign In button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      icon: Image.asset(
                        'assets/google_logo.png',
                        height: 24,
                      ),
                      label: Text('Sign in with Google'),
                      onPressed: _isLoading ? null : _signInWithGoogle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// AuthWrapper
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Not authenticated
        if (snapshot.data == null) {
          return LoginScreen();
        }

        // Authenticated
        return HomeScreen();
      },
    );
  }
}
```

**Token Management:**
```dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get ID token
  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  // Refresh token
  Future<String?> refreshToken() async {
    return await _auth.currentUser?.getIdToken(true);
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }

  // Re-authenticate (for sensitive operations)
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);
  }
}
```

### 8.2 Authorization and Access Control

#### Role-Based Access Control (RBAC)

**Role Definitions:**
```dart
enum UserRole {
  admin,
  user,
}

class RoleChecker {
  static const List<String> adminEmails = [
    'espthesisbmn@gmail.com',
    'smartenergymeter11@gmail.com',
  ];

  // Check if user is admin by email
  static bool isAdminByEmail(String? email) {
    return email != null && adminEmails.contains(email.toLowerCase());
  }

  // Check if user is admin by custom claim
  static Future<bool> isAdminByClaim(User user) async {
    final idTokenResult = await user.getIdTokenResult();
    return idTokenResult.claims?['admin'] == true;
  }

  // Get user role
  static Future<UserRole> getUserRole(User user) async {
    if (await isAdminByClaim(user) || isAdminByEmail(user.email)) {
      return UserRole.admin;
    }
    return UserRole.user;
  }
}
```

**Setting Custom Claims (Cloud Function):**
```javascript
// Cloud Function to set admin claim
exports.setAdminClaim = functions.https.onCall(async (data, context) => {
  // Only admins can set admin claims
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can set admin claims.'
    );
  }

  const { uid } = data;

  // Set custom claim
  await admin.auth().setCustomUserClaims(uid, { admin: true });

  return { message: `Admin claim set for user ${uid}` };
});

// Automatically set admin claim on user creation for specific emails
exports.setAdminOnCreate = functions.auth.user().onCreate(async (user) => {
  const adminEmails = [
    'espthesisbmn@gmail.com',
    'smartenergymeter11@gmail.com',
  ];

  if (adminEmails.includes(user.email.toLowerCase())) {
    await admin.auth().setCustomUserClaims(user.uid, { admin: true });
  }
});
```

**Admin Privileges:**

1. **View All Users:**
```dart
// theadmin.dart
class AdminPanel extends StatelessWidget {
  Future<List<UserData>> _getAllUsers() async {
    final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .get();

    return snapshot.docs.map((doc) {
      return UserData.fromFirestore(doc);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserData>>(
      future: _getAllUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final user = snapshot.data![index];
            return UserListTile(user: user);
          },
        );
      },
    );
  }
}
```

2. **Assign/Unassign Hubs:**
```dart
Future<void> assignHubToUser(String hubSerial, String userId) async {
  // Check if current user is admin
  final currentUser = FirebaseAuth.instance.currentUser!;
  final isAdmin = await RoleChecker.isAdminByClaim(currentUser);

  if (!isAdmin) {
    throw Exception('Only admins can assign hubs');
  }

  // Update hub ownership
  await FirebaseDatabase.instance
    .ref('users/espthesisbmn/hubs/$hubSerial')
    .update({
      'ownerId': userId,
      'assigned': true,
    });
}

Future<void> unassignHub(String hubSerial) async {
  final currentUser = FirebaseAuth.instance.currentUser!;
  final isAdmin = await RoleChecker.isAdminByClaim(currentUser);

  if (!isAdmin) {
    throw Exception('Only admins can unassign hubs');
  }

  await FirebaseDatabase.instance
    .ref('users/espthesisbmn/hubs/$hubSerial')
    .update({
      'ownerId': null,
      'assigned': false,
    });
}
```

3. **Global Settings Management:**
```dart
class AdminSettings {
  Future<void> updateGlobalSettings(Map<String, dynamic> settings) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final isAdmin = await RoleChecker.isAdminByClaim(currentUser);

    if (!isAdmin) {
      throw Exception('Only admins can update global settings');
    }

    await FirebaseFirestore.instance
      .collection('config')
      .doc('global')
      .update(settings);
  }

  Future<void> updateDefaultPrice(double newPrice) async {
    await updateGlobalSettings({'defaultPricePerKWH': newPrice});
  }
}
```

**Role-Based UI Rendering:**
```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return FutureBuilder<UserRole>(
      future: RoleChecker.getUserRole(user),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();

        final role = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text('Smart Energy System'),
            actions: [
              // Admin-only actions
              if (role == UserRole.admin)
                IconButton(
                  icon: Icon(Icons.admin_panel_settings),
                  onPressed: () => Navigator.pushNamed(context, '/admin'),
                ),
              // Regular actions
              IconButton(
                icon: Icon(Icons.notifications),
                onPressed: () => Navigator.pushNamed(context, '/notifications'),
              ),
            ],
          ),
          drawer: NavigationDrawer(role: role),
          body: role == UserRole.admin
            ? AdminHomeScreen()
            : UserHomeScreen(),
        );
      },
    );
  }
}
```

### 8.3 Firestore Security Rules

**Complete Firestore Security Rules:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }

    function isAdmin() {
      return isAuthenticated() && (
        request.auth.token.admin == true ||
        request.auth.token.email in [
          'espthesisbmn@gmail.com',
          'smartenergymeter11@gmail.com'
        ]
      );
    }

    // Users collection
    match /users/{userId} {
      // User can read/write their own data, admin can read/write all
      allow read: if isOwner(userId) || isAdmin();
      allow write: if isOwner(userId) || isAdmin();

      // Subcollections
      match /{subcollection=**} {
        allow read: if isOwner(userId) || isAdmin();
        allow write: if isOwner(userId) || isAdmin();
      }

      // Device subcollection
      match /devices/{deviceId} {
        allow read: if isOwner(userId) || isAdmin();

        // Only allow creating devices with correct ownerId
        allow create: if isAuthenticated() && (
          request.resource.data.keys().hasAll(['name', 'serialNumber']) &&
          (isOwner(userId) || isAdmin())
        );

        // Only owner or admin can update/delete
        allow update, delete: if isOwner(userId) || isAdmin();
      }

      // Price history (read-only for users, write for system)
      match /priceHistory/{historyId} {
        allow read: if isOwner(userId) || isAdmin();
        allow write: if isOwner(userId) || isAdmin();
      }
    }

    // Global configuration (admin only)
    match /config/{configId} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }

    // Analytics data (if stored in Firestore)
    match /analytics/{userId}/{document=**} {
      allow read: if isOwner(userId) || isAdmin();
      allow write: if isOwner(userId) || isAdmin();
    }

    // Deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**Field Validation Rules:**
```javascript
// In users/{userId} match
allow create: if isAuthenticated() && (
  // Required fields
  request.resource.data.keys().hasAll(['email', 'createdAt']) &&

  // Email validation
  request.resource.data.email is string &&
  request.resource.data.email.matches('[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}') &&

  // Price validation
  (!request.resource.data.keys().hasAny(['pricePerKWH']) ||
   (request.resource.data.pricePerKWH is number &&
    request.resource.data.pricePerKWH > 0 &&
    request.resource.data.pricePerKWH < 1000)) &&

  // Due date validation
  (!request.resource.data.keys().hasAny(['dueDate']) ||
   request.resource.data.dueDate is timestamp)
);
```

### 8.4 Realtime Database Security Rules

**Complete RTDB Security Rules:**
```json
{
  "rules": {
    "users": {
      "espthesisbmn": {
        "hubs": {
          // Index by ownerId for efficient queries
          ".indexOn": ["ownerId", "assigned"],

          "$serial_number": {
            // Read: Must be authenticated and either owner or admin
            ".read": "auth != null && (
              data.child('ownerId').val() == auth.uid ||
              auth.token.email == 'espthesisbmn@gmail.com' ||
              auth.token.email == 'smartenergymeter11@gmail.com' ||
              auth.token.admin == true
            )",

            // Write: Complex rules for different scenarios
            ".write": "auth != null && (
              // Case 1: Hub is unassigned - anyone can claim it
              (!data.exists() || data.child('assigned').val() != true) ||

              // Case 2: User is the owner
              data.child('ownerId').val() == auth.uid ||

              // Case 3: User is admin
              auth.token.email == 'espthesisbmn@gmail.com' ||
              auth.token.email == 'smartenergymeter11@gmail.com' ||
              auth.token.admin == true
            )",

            // Hub fields validation
            "ownerId": {
              ".validate": "newData.isString()"
            },
            "assigned": {
              ".validate": "newData.isBoolean()"
            },
            "nickname": {
              ".validate": "newData.isString() && newData.val().length <= 50"
            },

            // SSR state - only owner or admin can change
            "ssr_state": {
              ".write": "auth != null && (
                root.child('users').child('espthesisbmn').child('hubs')
                  .child($serial_number).child('ownerId').val() == auth.uid ||
                auth.token.admin == true
              )",
              ".validate": "newData.isBoolean()"
            },

            // Plugs data
            "plugs": {
              "$plug_id": {
                ".write": "auth != null && (
                  root.child('users').child('espthesisbmn').child('hubs')
                    .child($serial_number).child('ownerId').val() == auth.uid ||
                  auth.token.admin == true
                )",

                // Field validation
                "name": {
                  ".validate": "newData.isString() && newData.val().length <= 30"
                },
                "power": {
                  ".validate": "newData.isNumber() && newData.val() >= 0 && newData.val() <= 10000"
                },
                "voltage": {
                  ".validate": "newData.isNumber() && newData.val() >= 0 && newData.val() <= 300"
                },
                "current": {
                  ".validate": "newData.isNumber() && newData.val() >= 0 && newData.val() <= 100"
                },
                "energy": {
                  ".validate": "newData.isNumber() && newData.val() >= 0"
                },
                "ssr_state": {
                  ".validate": "newData.isBoolean()"
                }
              }
            },

            // Aggregations - read by owner/admin, write by system/hardware
            "aggregations": {
              ".read": "auth != null && (
                root.child('users').child('espthesisbmn').child('hubs')
                  .child($serial_number).child('ownerId').val() == auth.uid ||
                auth.token.admin == true
              )",

              // Per-second data - write by hardware
              "per_second": {
                "data": {
                  "$timestamp": {
                    ".write": "auth != null",
                    ".validate": "newData.hasChildren(['total_power', 'total_voltage', 'total_current', 'total_energy'])"
                  }
                }
              },

              // Aggregated data - write by Cloud Functions or hardware
              "hourly_aggregation": {
                "$hour_key": {
                  ".write": "auth != null"
                }
              },
              "daily_aggregation": {
                "$day_key": {
                  ".write": "auth != null"
                }
              },
              "weekly_aggregation": {
                "$week_key": {
                  ".write": "auth != null"
                }
              },
              "monthly_aggregation": {
                "$month_key": {
                  ".write": "auth != null"
                }
              }
            }
          }
        }
      }
    }
  }
}
```

**Security Rule Testing:**
```dart
// Test ownership validation
test('User can only read their own hubs', () async {
  final user1 = MockUser(uid: 'user1');
  final user2 = MockUser(uid: 'user2');

  // User 1 assigns hub
  await FirebaseDatabase.instance
    .ref('users/espthesisbmn/hubs/HUB123')
    .set({'ownerId': 'user1', 'assigned': true});

  // User 2 tries to read - should fail
  expect(
    () => FirebaseDatabase.instance
      .ref('users/espthesisbmn/hubs/HUB123')
      .get(),
    throwsA(isA<FirebaseException>()),
  );
});
```

### 8.5 Data Privacy

#### User Data Isolation

**Hub Ownership Filtering:**
```dart
class RealtimeDbService {
  final String _userId;

  // Only subscribe to user's own hubs
  Future<void> subscribeToUserHubs() async {
    final hubsQuery = FirebaseDatabase.instance
      .ref('users/espthesisbmn/hubs')
      .orderByChild('ownerId')
      .equalTo(_userId);  // Only user's hubs

    hubsQuery.onChildAdded.listen((event) {
      _handleHubAdded(event.snapshot);
    });
  }

  // Verify ownership before operations
  Future<void> toggleSSR(String serialNumber, bool state) async {
    // Verify ownership
    final snapshot = await FirebaseDatabase.instance
      .ref('users/espthesisbmn/hubs/$serialNumber')
      .get();

    if (snapshot.exists) {
      final ownerId = snapshot.child('ownerId').value as String?;
      if (ownerId != _userId) {
        throw Exception('Unauthorized: You do not own this hub');
      }

      // Proceed with SSR toggle
      await FirebaseDatabase.instance
        .ref('users/espthesisbmn/hubs/$serialNumber/ssr_state')
        .set(state);
    }
  }
}
```

**Private User Documents:**
```dart
class UserProfileService {
  final String _userId;

  // Only access own profile
  Future<UserProfile> getProfile() async {
    final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(_userId)  // Only own document
      .get();

    if (!doc.exists) {
      throw Exception('Profile not found');
    }

    return UserProfile.fromFirestore(doc);
  }

  // Update own profile
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    await FirebaseFirestore.instance
      .collection('users')
      .doc(_userId)  // Only own document
      .update(updates);
  }
}
```

**Isolated Notification Streams:**
```dart
class NotificationService {
  final String _userId;

  // User-specific notification collection
  Stream<List<NotificationItem>> getNotificationStream() {
    return FirebaseFirestore.instance
      .collection('users')
      .doc(_userId)
      .collection('notifications')
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          return NotificationItem.fromFirestore(doc);
        }).toList();
      });
  }
}
```

#### Secure Data Transmission

**HTTPS Enforcement:**
- All Firebase connections use HTTPS by default
- No plaintext data transmission
- TLS 1.2+ encryption

**Secure WebSocket:**
- Firebase Realtime Database uses secure WebSocket (WSS)
- Automatic reconnection with token refresh
- Encrypted real-time streams

**Token-Based API Requests:**
```dart
class SecureApiService {
  Future<Map<String, String>> _getAuthHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final token = await user.getIdToken();

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Response> makeSecureRequest(String endpoint) async {
    final headers = await _getAuthHeaders();

    return await http.get(
      Uri.parse('$apiBaseUrl/$endpoint'),
      headers: headers,
    );
  }
}
```

#### Data Encryption

**Firestore Encryption:**
- Data encrypted at rest (AES-256)
- Automatic encryption/decryption
- No manual implementation needed

**Sensitive Data Hashing:**
```dart
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SecurityUtils {
  // Hash sensitive data before storage
  static String hashData(String data) {
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  // Verify hashed data
  static bool verifyHash(String data, String hash) {
    return hashData(data) == hash;
  }
}
```

### 8.6 Security Best Practices Implemented

1. **Input Validation:**
```dart
class InputValidator {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Invalid email format';
    }
    return null;
  }

  static String? validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'Price is required';
    }
    final price = double.tryParse(value);
    if (price == null || price <= 0 || price > 1000) {
      return 'Price must be between 0 and 1000';
    }
    return null;
  }

  static String? validateSerialNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Serial number is required';
    }
    if (value.length < 8) {
      return 'Serial number must be at least 8 characters';
    }
    // Only alphanumeric
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
      return 'Serial number must be alphanumeric';
    }
    return null;
  }
}
```

2. **Rate Limiting (Cloud Functions):**
```javascript
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
});

app.use('/api/', limiter);
```

3. **XSS Prevention:**
```dart
import 'package:html/parser.dart' as html_parser;

class XSSPrevention {
  static String sanitizeInput(String input) {
    // Parse and strip HTML tags
    final document = html_parser.parse(input);
    return document.body?.text ?? '';
  }

  static String escapeHtml(String input) {
    return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#x27;');
  }
}
```

4. **SQL Injection Prevention:**
- Firebase automatically prevents injection
- Parameterized queries
- No raw SQL execution

5. **Session Management:**
```dart
class SessionManager {
  static const Duration sessionTimeout = Duration(hours: 24);

  // Check if session is still valid
  static Future<bool> isSessionValid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      // Force token refresh to check validity
      await user.getIdToken(true);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Automatic session refresh
  static void startSessionMonitoring() {
    Timer.periodic(Duration(minutes: 30), (timer) async {
      if (!await isSessionValid()) {
        await FirebaseAuth.instance.signOut();
        // Navigate to login
      }
    });
  }
}
```

---

## 9. DOMAIN-SPECIFIC ENERGY SYSTEM CONCEPTS

### 9.1 Electrical Measurements

#### Power (Watts - W)

**Definition:**
Power is the instantaneous rate of energy consumption or transfer.

**Formula:**
```
P = V × I
P = Power (Watts)
V = Voltage (Volts)
I = Current (Amperes)
```

**Measurement in System:**
- Calculated from voltage and current readings
- Updated every second
- Typical household range: 100W - 3000W per device
- Total system capacity: Dependent on hub design (usually 3000W - 5000W)

**Code Implementation:**
```dart
class PowerCalculator {
  // Calculate power from voltage and current
  static double calculatePower(double voltage, double current) {
    return voltage * current;
  }

  // Calculate total power from multiple plugs
  static double calculateTotalPower(List<PlugData> plugs) {
    return plugs.fold(0.0, (sum, plug) => sum + plug.power);
  }

  // Power factor correction (if needed)
  static double calculateRealPower(
    double apparentPower,
    double powerFactor,
  ) {
    return apparentPower * powerFactor;
  }
}
```

**Display Format:**
```dart
String formatPower(double watts) {
  if (watts >= 1000) {
    return '${(watts / 1000).toStringAsFixed(2)} kW';
  }
  return '${watts.toStringAsFixed(2)} W';
}
```

#### Voltage (Volts - V)

**Definition:**
Voltage is the electrical pressure or potential difference that drives current through a circuit.

**Standard Range (Philippines):**
- Nominal: 220V
- Acceptable range: 210V - 230V
- Warning threshold: < 200V or > 240V

**Measurement:**
- Voltage divider circuit (resistor network)
- ADC (Analog-to-Digital Converter) reading
- Calibration factor applied

**Monitoring:**
```dart
class VoltageMonitor {
  static const double nominalVoltage = 220.0;
  static const double minSafeVoltage = 200.0;
  static const double maxSafeVoltage = 240.0;

  static VoltageStatus checkVoltageStatus(double voltage) {
    if (voltage < minSafeVoltage) {
      return VoltageStatus.low;
    } else if (voltage > maxSafeVoltage) {
      return VoltageStatus.high;
    } else if ((voltage - nominalVoltage).abs() > 10) {
      return VoltageStatus.fluctuating;
    } else {
      return VoltageStatus.stable;
    }
  }

  static Color getVoltageColor(double voltage) {
    final status = checkVoltageStatus(voltage);
    switch (status) {
      case VoltageStatus.stable:
        return Colors.green;
      case VoltageStatus.fluctuating:
        return Colors.orange;
      case VoltageStatus.low:
      case VoltageStatus.high:
        return Colors.red;
    }
  }
}

enum VoltageStatus {
  stable,
  fluctuating,
  low,
  high,
}
```

#### Current (Amperes - A)

**Definition:**
Current is the flow rate of electric charge through a conductor.

**Measurement:**
- Hall-effect current sensor (e.g., ACS712)
- Non-invasive measurement
- AC current (RMS value)

**Typical Ranges:**
- Small appliances: 0.5A - 2A
- Medium appliances: 2A - 5A
- Large appliances: 5A - 15A
- System limit: Usually 20A - 30A

**Safety Monitoring:**
```dart
class CurrentMonitor {
  static const double maxSafeCurrent = 20.0;
  static const double warningThreshold = 18.0;

  static CurrentStatus checkCurrentStatus(double current) {
    if (current > maxSafeCurrent) {
      return CurrentStatus.overload;
    } else if (current > warningThreshold) {
      return CurrentStatus.warning;
    } else {
      return CurrentStatus.normal;
    }
  }

  static void monitorCurrent(double current, Function(String) onAlert) {
    final status = checkCurrentStatus(current);

    switch (status) {
      case CurrentStatus.overload:
        onAlert('CRITICAL: Current overload! ${current.toStringAsFixed(2)}A');
        // Trigger SSR shutdown
        break;
      case CurrentStatus.warning:
        onAlert('WARNING: High current ${current.toStringAsFixed(2)}A');
        break;
      case CurrentStatus.normal:
        // No action
        break;
    }
  }
}

enum CurrentStatus {
  normal,
  warning,
  overload,
}
```

#### Energy (Kilowatt-hours - kWh)

**Definition:**
Energy is the total amount of electrical power consumed over time.

**Formula:**
```
E = P × t / 1000
E = Energy (kWh)
P = Power (Watts)
t = Time (hours)
```

**Measurement:**
- Cumulative meter reading
- Incremental calculation every second
- Persistent storage in Firebase

**Calculation:**
```dart
class EnergyCalculator {
  // Calculate energy consumed in a time period
  static double calculateEnergy({
    required double powerWatts,
    required Duration duration,
  }) {
    final hours = duration.inSeconds / 3600.0;
    return (powerWatts * hours) / 1000.0;  // Convert to kWh
  }

  // Incremental energy accumulation (called every second)
  static double accumulateEnergy({
    required double currentEnergyKWH,
    required double currentPowerWatts,
    required Duration interval,  // Usually 1 second
  }) {
    final energyIncrement = calculateEnergy(
      powerWatts: currentPowerWatts,
      duration: interval,
    );

    return currentEnergyKWH + energyIncrement;
  }

  // Calculate daily usage
  static Future<double> calculateDailyUsage(String hubSerial) async {
    final today = DateTime.now();
    final yesterday = today.subtract(Duration(days: 1));

    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final yesterdayKey = DateFormat('yyyy-MM-dd').format(yesterday);

    final todaySnapshot = await FirebaseDatabase.instance
      .ref('users/espthesisbmn/hubs/$hubSerial/aggregations/daily_aggregation/$todayKey')
      .get();

    final yesterdaySnapshot = await FirebaseDatabase.instance
      .ref('users/espthesisbmn/hubs/$hubSerial/aggregations/daily_aggregation/$yesterdayKey')
      .get();

    if (todaySnapshot.exists && yesterdaySnapshot.exists) {
      final todayEnergy = (todaySnapshot.value as Map)['total_energy'] ?? 0;
      final yesterdayEnergy = (yesterdaySnapshot.value as Map)['total_energy'] ?? 0;

      return (todayEnergy - yesterdayEnergy).toDouble();
    }

    return 0.0;
  }
}
```

### 9.2 Solid State Relay (SSR) System

**What is an SSR?**
A Solid State Relay is an electronic switching device that controls high-power AC circuits using low-power DC control signals.

**Advantages over Mechanical Relays:**
- No moving parts (longer lifespan)
- Faster switching
- Silent operation
- Zero voltage crossing (reduces EMI)
- No contact bounce

**System Implementation:**

**Hardware:**
```
ESP32 GPIO → SSR Input (3-32V DC)
SSR Output → AC Load (0-240V AC)
```

**Control Logic:**
```dart
class SSRController {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Turn SSR ON
  Future<void> turnOn(String hubSerial) async {
    await _database
      .ref('users/espthesisbmn/hubs/$hubSerial/ssr_state')
      .set(true);

    // Log event
    await _logSSREvent(hubSerial, true);
  }

  // Turn SSR OFF
  Future<void> turnOff(String hubSerial) async {
    await _database
      .ref('users/espthesisbmn/hubs/$hubSerial/ssr_state')
      .set(false);

    // Log event
    await _logSSREvent(hubSerial, false);
  }

  // Toggle SSR
  Future<void> toggle(String hubSerial) async {
    final snapshot = await _database
      .ref('users/espthesisbmn/hubs/$hubSerial/ssr_state')
      .get();

    final currentState = snapshot.value as bool? ?? false;
    await _database
      .ref('users/espthesisbmn/hubs/$hubSerial/ssr_state')
      .set(!currentState);

    await _logSSREvent(hubSerial, !currentState);
  }

  // Log SSR events for analytics
  Future<void> _logSSREvent(String hubSerial, bool newState) async {
    await FirebaseFirestore.instance
      .collection('ssr_events')
      .add({
        'hubSerial': hubSerial,
        'state': newState,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser!.uid,
      });
  }
}
```

**Safety Features:**
```dart
class SSRSafety {
  // Automatic shutoff on overload
  static Future<void> monitorAndProtect(
    String hubSerial,
    double current,
  ) async {
    const double maxCurrent = 20.0;

    if (current > maxCurrent) {
      // Emergency shutoff
      await SSRController().turnOff(hubSerial);

      // Send alert
      await _sendOverloadAlert(hubSerial, current);
    }
  }

  // Scheduled power management
  static Future<void> scheduleSSR({
    required String hubSerial,
    required DateTime onTime,
    required DateTime offTime,
  }) async {
    // Implement scheduling logic
    // Could use Cloud Scheduler or local timers
  }
}
```

---

*(Continued in THEORETICAL_BACKGROUND_PART3.md for remaining sections...)*

This completes the Security and Domain Concepts sections. Would you like me to continue with the remaining sections (Data Aggregation, Usage Calculation, Cost Management, Testing, and Future Enhancements)?
