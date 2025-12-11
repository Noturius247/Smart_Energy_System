# COMPREHENSIVE THEORETICAL BACKGROUND - SMART ENERGY SYSTEM

## Executive Summary

The Smart Energy System is a sophisticated, cross-platform IoT energy monitoring and management application built with Flutter. It provides real-time monitoring, analytics, cost management, and intelligent insights for residential and commercial energy consumption. The system integrates hardware (ESP-based smart plugs and hubs), cloud infrastructure (Firebase), and a feature-rich mobile/web/desktop application to deliver a complete energy management solution.

---

## 1. APPLICATION STRUCTURE AND ARCHITECTURE

### 1.1 Technology Stack

**Primary Framework:** Flutter 3.8.1 (Cross-platform mobile/web/desktop application)
- **Language:** Dart
- **UI Framework:** Material Design with custom theming
- **Platforms:** Android, iOS, Web, Windows, macOS, Linux

**Backend Infrastructure:**
- **Primary Database:** Firebase Realtime Database (time-series data)
- **Secondary Database:** Cloud Firestore (user profiles, devices, settings)
- **Authentication:** Firebase Authentication
- **Cloud Functions:** Serverless data aggregation

### 1.2 Architectural Pattern

**Pattern:** Provider-based State Management with Service-Oriented Architecture

The application follows a layered architecture that separates concerns and promotes maintainability:

**Physical Layer:** Smart plugs and central hubs (ESP-based hardware)
- ESP32/ESP8266 microcontrollers
- Current sensors (ACS712 or similar)
- Voltage divider circuits
- Power calculation modules
- Wi-Fi connectivity

**Cloud Layer:** Firebase services (Realtime Database + Firestore)
- Real-time data synchronization
- Hierarchical data aggregation
- User authentication and authorization
- Serverless computing

**Application Layer:** Flutter app with Provider state management
- Business logic services
- State management providers
- Data transformation
- Stream management

**Presentation Layer:** Responsive UI with adaptive layouts
- Material Design components
- Custom widgets
- Responsive breakpoints
- Platform-adaptive navigation

### 1.3 Project Structure

```
lib/
├── main.dart                    # Application entry point with MultiProvider setup
├── constants.dart               # Global constants, enums, and helper functions
├── firebase_options.dart        # Firebase configuration (auto-generated)
├── api_base.dart               # Backend API configuration
│
├── models/                     # Data models and entities
│   ├── usage_history_entry.dart  # Usage calculation model
│   └── history_record.dart       # Historical data record model
│
├── services/                   # Business logic services
│   ├── realtime_db_service.dart          # Core Firebase RTDB service
│   ├── chatbot_data_service.dart         # Chatbot data aggregation
│   ├── usage_history_service.dart        # Usage calculation service
│   ├── notification_service.dart         # Notification management
│   ├── analytics_recording_service.dart  # Analytics data recording
│   ├── data_cleanup_service.dart         # Automated data cleanup
│   └── table_update_notification_service.dart  # Table change notifications
│
├── providers/                  # State management providers
│   ├── theme_provider.dart     # Theme (dark/light) management
│   ├── price_provider.dart     # Electricity rate management
│   ├── due_date_provider.dart  # Billing due date management
│   └── notification_provider.dart  # Notification state management
│
├── screen/                     # UI screens (features)
│   ├── login.dart              # Authentication screen
│   ├── admin_home.dart         # Admin-specific home
│   ├── energy_overview_screen.dart  # Main dashboard
│   ├── explore.dart            # Device management
│   ├── analytics.dart          # Analytics and charts
│   ├── history.dart            # Usage history
│   ├── chatbot.dart            # Intelligent chatbot
│   ├── settings.dart           # User settings
│   ├── profile.dart            # User profile
│   └── theadmin.dart           # Admin panel
│
└── widgets/                    # Reusable UI components
    ├── notification_box.dart   # Price and due date widget
    └── notification_panel.dart # Notification list widget
```

### 1.4 Design Philosophy

**Separation of Concerns:**
- Models: Pure data structures with no business logic
- Services: Business logic, API calls, data transformations
- Providers: State management and UI updates
- Screens: UI composition and user interactions
- Widgets: Reusable UI components

**Single Responsibility Principle:**
- Each service handles one specific domain
- Clear boundaries between authentication, data, and presentation
- Focused, testable components

**Dependency Injection:**
- MultiProvider at app root
- Services provided via constructor injection
- Easy mocking for testing

---

## 2. KEY FEATURES AND FUNCTIONALITIES

### 2.1 Core Features

#### A. Real-Time Energy Monitoring

**Live Power Consumption Tracking:**
- Updates every second via Firebase Realtime Database streams
- Displays instantaneous power consumption in Watts (W)
- Aggregates data from multiple devices/plugs
- Visual indicators for consumption levels

**Voltage Monitoring:**
- Standard operating range: 210-230V (Philippines standard)
- Real-time voltage stability tracking
- Alerts for voltage fluctuations
- Historical voltage trends

**Current Measurement:**
- Amperage tracking for each device
- Combined current for all devices
- Overload detection
- Safety monitoring

**Cumulative Energy Consumption:**
- Total kilowatt-hours (kWh) tracking
- Meter-style cumulative reading
- Difference-based usage calculation
- Accurate billing information

**Multi-Hub and Multi-Device Support:**
- Support for multiple central hubs per user
- Multiple smart plugs per hub
- Independent control and monitoring
- Aggregated and individual views

**Technical Implementation:**
```dart
// Real-time stream subscription
Stream<Map<String, dynamic>> hubDataStream =
  realtimeDbService.subscribeToAllUserHubs();

// Automatic UI updates via StreamBuilder
StreamBuilder<Map<String, dynamic>>(
  stream: hubDataStream,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return MetricDisplay(data: snapshot.data);
    }
    return LoadingIndicator();
  },
)
```

#### B. Device Management

**Central Hub Linking and Unlinking:**
- Add hub via serial number
- Ownership assignment (ownerId field)
- Hub nickname customization
- Status indicators (online/offline)

**Individual Smart Plug Control:**
- Per-plug SSR (Solid State Relay) control
- Toggle power remotely
- Named device assignment
- Custom icons (40+ Font Awesome icons)

**Device Naming and Categorization:**
- Custom device names
- Icon assignment for easy identification
- Device grouping by hub
- Search and filter capabilities

**SSR (Solid State Relay) State Control:**
- Remote power on/off
- Real-time state synchronization
- Safety interlocks
- Manual override capability

**Device Status Monitoring:**
- Online/offline detection
- Last seen timestamp
- Connectivity strength
- Automatic reconnection

**Data Flow:**
```
User Action (Toggle SSR)
  → Update Firebase RTDB (/hubs/{serial}/ssr_state)
  → Hardware listens to state change
  → Hardware executes relay toggle
  → Confirmation written back to Firebase
  → UI reflects new state
```

#### C. Analytics and Visualization

**Multiple Time-Range Views:**
- **Hourly:** 24-hour sliding window
- **Daily:** 30-day view
- **Weekly:** 12-week view
- **Monthly:** 12-month view

**Interactive Charts (fl_chart library):**
- Line charts for trends
- Bar charts for comparisons
- Touch interactions and tooltips
- Smooth animations
- Zoom and pan capabilities

**Multiple Metric Types:**
- **Power (W):** Purple color coding
- **Voltage (V):** Orange color coding
- **Current (A):** Blue color coding
- **Energy (kWh):** Green color coding

**Real-time 60-Second Live Chart:**
- Updates every second
- Sliding window of last 60 data points
- Auto-pauses when SSR is off
- Smooth animations

**Historical Data Aggregation:**
- Hourly averages
- Daily totals
- Weekly summaries
- Monthly trends

**Statistical Summaries:**
- Minimum values
- Maximum values
- Average values
- Total consumption
- Reading count

**Excel Export Functionality:**
- Export charts as Excel files
- Formatted tables with headers
- Timestamp conversions
- Cross-platform support (mobile/web)

**Implementation Example:**
```dart
// Analytics service fetching aggregated data
Future<List<Map<String, dynamic>>> fetchHourlyData(
  String serialNumber,
  DateTime start,
  DateTime end,
) async {
  final ref = FirebaseDatabase.instance
    .ref('users/espthesisbmn/hubs/$serialNumber/aggregations/hourly_aggregation');

  final snapshot = await ref
    .orderByKey()
    .startAt(DateFormat('yyyy-MM-dd-HH').format(start))
    .endAt(DateFormat('yyyy-MM-dd-HH').format(end))
    .get();

  return processAggregatedData(snapshot);
}
```

#### D. Usage History

**Hierarchical Consumption Calculation:**
- Calculates usage as difference between readings
- Prevents negative values
- Handles meter rollovers
- Accurate to 3 decimal places

**Four Interval Types:**
- **Hourly:** Hour-by-hour consumption
- **Daily:** Day-by-day consumption
- **Weekly:** Week-by-week consumption (ISO 8601)
- **Monthly:** Month-by-month consumption

**Difference-Based Usage Calculation:**
```
Usage[n] = Current_Reading[n] - Previous_Reading[n]
```

**Example:**
```
Hour 1: 1000.500 kWh (current reading)
Hour 2: 1002.300 kWh (current reading)
Usage for Hour 2: 1002.300 - 1000.500 = 1.800 kWh
```

**Excel Export Functionality:**
- Generate .xlsx files
- Columns: Previous Reading, Current Reading, Usage, Timestamp
- Automatic filename with date
- Download for web, save for mobile

**Pagination Support:**
- 20 entries per page
- Total page calculation
- Navigation controls
- Efficient data loading

**Timezone Correction Handling:**
- UTC to local time conversion
- Handles UTC+3 to UTC+8 offset (5-hour correction for specific hardware)
- Display in user's local timezone
- Proper DST handling

**Technical Implementation:**
```dart
class UsageHistoryEntry {
  final String timestamp;
  final String formattedTimestamp;
  final double previousReading;
  final double currentReading;
  final double usage;
  final IntervalType intervalType;

  // Constructor with validation
  UsageHistoryEntry({
    required this.timestamp,
    required this.formattedTimestamp,
    required this.previousReading,
    required this.currentReading,
    required this.usage,
    required this.intervalType,
  }) : assert(usage >= 0, 'Usage cannot be negative'),
       assert(currentReading >= previousReading, 'Invalid readings');
}
```

#### E. Cost Management

**Customizable Electricity Rate:**
- Set price per kWh in Philippine Pesos (₱)
- Real-time cost updates
- Persistent storage in Firestore
- Admin-adjustable rates

**Daily Cost Calculation:**
```
Daily_Cost = (Today_Total_Energy - Yesterday_Total_Energy) × Price_per_kWh
```

**Monthly Cost Projection:**
```
Monthly_Estimate = (Daily_Average_Usage × Days_in_Month) × Price_per_kWh
```

**Bill Due Date Tracking:**
- Set monthly due date
- Days remaining indicator
- Color-coded warnings (red when < 7 days)
- Overdue status

**Cost History Tracking:**
- Historical cost data
- Month-over-month comparison
- Cost trends visualization

**Usage Cost Calculator:**
- Real-time cost display on dashboard
- Per-device cost breakdown
- Projected monthly bill

**Implementation:**
```dart
class PriceProvider extends ChangeNotifier {
  double _pricePerKWH = 11.0; // Default rate

  // Calculate cost for given energy consumption
  double calculateCost(double energyKWH) {
    return energyKWH * _pricePerKWH;
  }

  // Update price and persist to Firestore
  Future<void> updatePrice(double newPrice) async {
    _pricePerKWH = newPrice;
    await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUserId)
      .update({'pricePerKWH': newPrice});
    notifyListeners();
  }
}
```

#### F. Intelligent Chatbot

**Dynamic Data Integration:**
- Real-time access to all system data
- Hub information
- Device status
- Energy metrics
- Cost calculations
- Historical data

**Natural Language Query Support:**
- "What's my current power consumption?"
- "How much energy did I use yesterday?"
- "What's my monthly bill estimate?"
- "Which device is using the most power?"
- "Is my voltage stable?"

**Real-time System Status:**
- All hubs online/offline
- Total power consumption
- Voltage levels
- Active devices count

**Energy Metrics Queries:**
- Current power, voltage, current
- Energy consumption (today, this week, this month)
- Peak usage times
- Consumption trends

**Device Information:**
- List all devices
- Device status (on/off)
- Device consumption
- Device assignments

**Cost Calculations:**
- Current day cost
- Projected monthly bill
- Cost per device
- Rate information

**Historical Data Queries:**
- Yesterday's usage
- Last week comparison
- Monthly trends
- Year-over-year comparison

**Proactive Alerts:**
- High consumption warnings
- Unusual patterns
- Due date reminders
- Offline device notifications

**Technical Architecture:**
```dart
class ChatbotDataService {
  final RealtimeDbService _realtimeService;
  final FirebaseFirestore _firestore;

  // Aggregate all relevant data
  Future<Map<String, dynamic>> getSystemSnapshot() async {
    final hubs = await _realtimeService.getAllHubsData();
    final devices = await _firestore.collection('devices').get();
    final userSettings = await _firestore
      .collection('users')
      .doc(userId)
      .get();

    return {
      'hubs': hubs,
      'devices': devices,
      'settings': userSettings,
      'timestamp': DateTime.now(),
    };
  }
}
```

#### G. Notifications System

**Hub Toggle Notifications:**
- Alert when hub SSR state changes
- Timestamp and hub identification
- User-initiated vs automatic changes

**Device State Change Alerts:**
- Device turned on/off
- SSR state changes
- Connection status changes

**Price Update Notifications:**
- Electricity rate changes
- Admin updates
- Effective date

**Due Date Reminders:**
- 7 days before due date
- 3 days before due date
- Overdue alerts

**Energy Consumption Alerts:**
- Daily threshold exceeded
- Unusual consumption patterns
- High power usage warnings

**Cost Threshold Warnings:**
- Approaching budget limit
- Cost exceeded threshold
- Projected bill alerts

**Notification Management:**
- Mark as read/unread
- Delete notifications
- Clear all notifications
- Notification history
- Push notifications (future)

**Implementation:**
```dart
class NotificationProvider extends ChangeNotifier {
  final List<NotificationItem> _notifications = [];

  void addNotification(NotificationType type, String message) {
    _notifications.insert(0, NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      message: message,
      timestamp: DateTime.now(),
      isRead: false,
    ));
    notifyListeners();
  }

  int get unreadCount =>
    _notifications.where((n) => !n.isRead).length;
}
```

### 2.2 Administrative Features

#### A. Admin Panel (theadmin.dart)

**User Management:**
- View all registered users
- User details (email, full name, phone)
- User activity monitoring
- Account status management

**Hub Assignment:**
- Assign hubs to users
- Unassign hubs from users
- Transfer hub ownership
- Hub inventory management

**System Monitoring:**
- Total users count
- Total hubs count
- Active/inactive hubs
- System health metrics

**Global Settings:**
- Default electricity rates
- System-wide configurations
- Feature flags
- Maintenance mode

#### B. Multi-User Support

**User Authentication via Firebase Auth:**
- Email/password authentication
- Google OAuth 2.0
- Secure token management
- Session persistence

**Role-Based Access (admin/regular user):**
- Admin users: Custom claim `admin: true`
- Admin emails whitelist
- Role verification on each request
- Frontend role-based UI rendering

**Per-User Data Isolation:**
- Hub filtering by ownerId
- Private user documents
- Isolated notification streams
- Secure Firestore rules

**Owner-Based Hub Filtering:**
```dart
// Query only user's hubs
final userHubsQuery = FirebaseDatabase.instance
  .ref('users/espthesisbmn/hubs')
  .orderByChild('ownerId')
  .equalTo(currentUser.uid);
```

**Admin Privileges:**
```dart
// Check if user is admin
bool isAdmin(User user) {
  return user.email == 'espthesisbmn@gmail.com' ||
         user.email == 'smartenergymeter11@gmail.com';
}

// Custom claim check
Future<bool> isAdminViaClaims(User user) async {
  final idTokenResult = await user.getIdTokenResult();
  return idTokenResult.claims?['admin'] == true;
}
```

---

## 3. TECHNOLOGIES, FRAMEWORKS, AND LIBRARIES

### 3.1 Core Dependencies

#### Firebase Ecosystem

**firebase_core: ^3.6.0**
- Core Firebase functionality
- Platform initialization
- Configuration management

**firebase_auth: ^5.3.1**
- User authentication
- Email/password auth
- Google Sign-In integration
- Token management
- Custom claims support

**firebase_database: ^11.0.0**
- Realtime Database client
- Real-time synchronization
- Offline persistence
- Query capabilities
- Stream-based updates

**cloud_firestore: ^5.4.4**
- Firestore document database
- Complex queries
- Compound indexes
- Offline support
- Real-time listeners

#### State Management

**provider: ^6.1.5+1**
- State management pattern
- Dependency injection
- ChangeNotifier pattern
- Consumer widgets
- Selector optimization

**rxdart: ^0.28.0**
- Reactive programming extensions
- BehaviorSubject for state streams
- Stream transformations
- Debouncing and throttling
- CombineLatest and merge operators

#### Data Visualization

**fl_chart: ^0.63.0**
- Advanced charting library
- Line charts with gradients
- Bar charts
- Pie charts
- Interactive tooltips
- Touch interactions
- Smooth animations
- Custom renderers

**Features:**
- Real-time data updates
- Responsive sizing
- Custom styling
- Multi-series support
- Axis customization

#### UI Components

**font_awesome_flutter: ^10.7.0**
- 1,600+ vector icons
- Icon customization
- Consistent sizing
- Brand icons
- Solid and regular variants

**lucide_icons: ^0.257.0**
- Modern icon set
- Clean design
- Additional options
- Consistent style

**lottie: ^2.2.0**
- JSON-based animations
- Loading indicators
- Empty states
- Success/error animations
- Cross-platform support

**rflutter_alert: ^2.0.7**
- Customizable alert dialogs
- Confirmation prompts
- Input dialogs
- Animated alerts
- Custom buttons

#### Utilities

**intl: ^0.20.2**
- Internationalization support
- Date/time formatting
- Number formatting
- Currency formatting
- Locale support

**collection: ^1.18.0**
- Collection utilities
- List extensions
- Map utilities
- Grouping and sorting
- Deep equality

**shared_preferences: ^2.5.3**
- Local key-value storage
- Persistent settings
- Theme preferences
- User preferences
- Cross-platform support

**url_launcher: ^6.2.6**
- Launch URLs
- Open external apps
- Email links
- Phone calls
- Platform-specific handling

#### Data Export

**excel: ^4.0.6**
- Excel file generation (.xlsx)
- Workbook creation
- Cell formatting
- Formulas
- Cross-platform export

**path_provider: ^2.1.5**
- File system access
- App directory paths
- Temporary directory
- Downloads folder
- Platform-specific paths

**universal_html: ^2.2.4**
- Web compatibility layer
- Cross-platform HTML/DOM
- Blob creation for downloads
- Browser APIs

#### Authentication

**google_sign_in: ^6.2.1**
- Google OAuth 2.0
- Cross-platform support
- Token retrieval
- User profile access

#### Testing

**mocktail: ^1.0.0**
- Modern mocking framework
- Type-safe mocks
- Verification
- Stubbing
- Argument matchers

**fake_cloud_firestore: ^3.0.3**
- Firestore testing mock
- In-memory database
- No Firebase connection needed
- Fast test execution

**firebase_auth_mocks: ^0.14.1**
- Auth testing mock
- Mock users
- Token simulation
- No backend required

**test: ^1.25.8**
- Core testing utilities
- Test runner
- Assertions
- Test organization

### 3.2 Development Dependencies

**flutter_lints: ^5.0.0**
- Recommended lint rules
- Code quality checks
- Best practices enforcement

**build_runner: ^2.4.14**
- Code generation
- Build automation
- Asset processing

### 3.3 Platform-Specific Configuration

**Android:**
- Min SDK: 21 (Android 5.0)
- Target SDK: 34 (Android 14)
- Compile SDK: 34
- Google Services plugin

**iOS:**
- Min iOS version: 12.0
- CocoaPods integration
- Firebase iOS SDK

**Web:**
- Firebase JS SDK
- HTML5 compliance
- Progressive Web App capable

**Windows/macOS/Linux:**
- Desktop support enabled
- Native plugins
- Platform channels

---

## 4. COMPONENT HIERARCHY AND ORGANIZATION

### 4.1 Navigation Structure

```
MyApp (MaterialApp)
└── MultiProvider
    └── AuthWrapper (Authentication Gate)
        ├── LoginScreen (Unauthenticated State)
        │   ├── Email/Password Form
        │   ├── Google Sign-In Button
        │   └── Sign-Up Link
        │
        └── HomeScreen (Authenticated State)
            ├── Scaffold
            │   ├── CustomHeader (AppBar)
            │   │   ├── User Profile Button
            │   │   ├── Theme Toggle
            │   │   ├── Notification Badge
            │   │   └── Search Icon
            │   │
            │   ├── CustomSidebarNav (Drawer/BottomNav)
            │   │   ├── [0] Profile
            │   │   ├── [1] Energy Overview
            │   │   ├── [2] Devices
            │   │   ├── [3] Analytics
            │   │   ├── [4] History
            │   │   └── [5] Settings
            │   │
            │   └── Body (IndexedStack for page preservation)
            │       ├── [0] ProfileScreen
            │       ├── [1] EnergyOverviewScreen
            │       ├── [2] ExploreScreen (Devices)
            │       ├── [3] AnalyticsScreen
            │       ├── [4] HistoryScreen
            │       └── [5] SettingsScreen
            │
            └── FloatingActionButton (Chatbot)
                └── ChatbotScreen
```

### 4.2 Screen Components Deep Dive

#### Energy Overview Screen (Dashboard)

**Layout:**
```
Column
├── MiniNotificationBox (Price & Due Date)
├── Hub Selector Dropdown
├── Real-time Metric Cards Row
│   ├── Power Card (Purple)
│   ├── Voltage Card (Orange)
│   ├── Current Card (Blue)
│   └── Energy Card (Green)
├── 24-Hour Consumption Chart
│   ├── Chart Title
│   ├── Line Chart (fl_chart)
│   └── Time Axis (0-23 hours)
├── Daily Usage Summary Card
│   ├── Energy Today
│   ├── Cost Today
│   └── Comparison to Yesterday
└── Cost Calculator Card
    ├── Energy Input
    ├── Rate Display
    └── Calculated Cost
```

**Real-time Updates:**
```dart
StreamBuilder<Map<String, dynamic>>(
  stream: realtimeDbService.hubDataStream,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final aggregatedData = _aggregateAllHubsData(snapshot.data);
      return MetricCardsRow(
        power: aggregatedData['power'],
        voltage: aggregatedData['voltage'],
        current: aggregatedData['current'],
        energy: aggregatedData['energy'],
      );
    }
    return LoadingState();
  },
)
```

#### Devices Screen (Explore)

**Layout:**
```
Column
├── Search Bar
├── Add Hub Button
├── Hubs List
│   └── For each Hub:
│       ├── Hub Card
│       │   ├── Hub Nickname
│       │   ├── Serial Number
│       │   ├── SSR State Toggle
│       │   ├── Status Indicator (online/offline)
│       │   └── Action Buttons (Edit, Delete)
│       │
│       └── Plugs Grid
│           └── For each Plug:
│               ├── Device Card
│               │   ├── Custom Icon
│               │   ├── Device Name
│               │   ├── Real-time Metrics
│               │   │   ├── Power
│               │   │   ├── Voltage
│               │   │   └── Current
│               │   ├── SSR Toggle Switch
│               │   └── Edit Icon
│               │
│               └── Add Device Card
└── Floating Action Button (Add Hub)
```

**Device Control Flow:**
```dart
// Toggle SSR state
Future<void> toggleSSRState(String serialNumber, bool newState) async {
  await FirebaseDatabase.instance
    .ref('users/espthesisbmn/hubs/$serialNumber/ssr_state')
    .set(newState);

  // Notification
  notificationProvider.addNotification(
    NotificationType.hubToggle,
    'Hub ${serialNumber} turned ${newState ? "ON" : "OFF"}',
  );
}
```

#### Analytics Screen

**Layout:**
```
Column
├── Controls Row
│   ├── Metric Selector (Power/Voltage/Current/Energy)
│   ├── Time Range Selector (Hourly/Daily/Weekly/Monthly)
│   └── Hub Filter Dropdown (All Hubs / Specific Hub)
│
├── Live Chart Section
│   ├── Section Title: "Live (Last 60 seconds)"
│   ├── Line Chart (60-second sliding window)
│   └── Auto-refresh indicator
│
├── Historical Chart Section
│   ├── Section Title: "Historical Data"
│   ├── Line Chart (aggregated data)
│   ├── Statistical Summary
│   │   ├── Min Value
│   │   ├── Max Value
│   │   ├── Average Value
│   │   └── Total Readings
│   └── Export to Excel Button
│
└── Loading/Error States
```

**Chart Configuration:**
```dart
LineChart(
  LineChartData(
    lineBarsData: [
      LineChartBarData(
        spots: dataPoints.map((point) => FlSpot(
          point['timestamp'],
          point['value'],
        )).toList(),
        isCurved: true,
        gradient: LinearGradient(
          colors: [Colors.purple, Colors.purpleAccent],
        ),
        barWidth: 3,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              Colors.purple.withOpacity(0.3),
              Colors.purple.withOpacity(0.0),
            ],
          ),
        ),
      ),
    ],
    titlesData: FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            return Text(formatTimestamp(value));
          },
        ),
      ),
    ),
    gridData: FlGridData(show: true),
    borderData: FlBorderData(show: true),
    lineTouchData: LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            return LineTooltipItem(
              '${spot.y.toStringAsFixed(2)} ${getUnit()}',
              TextStyle(color: Colors.white),
            );
          }).toList();
        },
      ),
    ),
  ),
)
```

**Data Fetching:**
```dart
Future<List<Map<String, dynamic>>> fetchAnalyticsData(
  String metric,
  String timeRange,
  String? hubSerial,
) async {
  final aggregationPath = _getAggregationPath(timeRange);

  if (hubSerial == null) {
    // Fetch from all hubs and aggregate
    final allHubs = await _getAllUserHubs();
    final allData = await Future.wait(
      allHubs.map((hub) => _fetchHubData(hub, aggregationPath)),
    );
    return _combineHubData(allData, metric);
  } else {
    // Fetch from specific hub
    return await _fetchHubData(hubSerial, aggregationPath);
  }
}
```

#### History Screen

**Layout:**
```
Column
├── Controls Row
│   ├── Interval Selector (Hourly/Daily/Weekly/Monthly)
│   ├── Hub Selector Dropdown
│   └── Export to Excel Button
│
├── Data Table
│   ├── Table Header
│   │   ├── Timestamp
│   │   ├── Previous Reading (kWh)
│   │   ├── Current Reading (kWh)
│   │   └── Usage (kWh)
│   │
│   └── Table Rows (Paginated)
│       └── For each entry:
│           ├── Formatted Timestamp
│           ├── Previous Reading (3 decimals)
│           ├── Current Reading (3 decimals)
│           └── Usage (3 decimals, colored)
│
└── Pagination Controls
    ├── Previous Button
    ├── Page Indicator (Page X of Y)
    └── Next Button
```

**Usage Calculation:**
```dart
class UsageHistoryService {
  Future<List<UsageHistoryEntry>> calculateUsage(
    String serialNumber,
    IntervalType interval,
  ) async {
    // 1. Fetch aggregated data
    final aggregationPath = _getAggregationPath(interval);
    final snapshot = await FirebaseDatabase.instance
      .ref('users/espthesisbmn/hubs/$serialNumber/aggregations/$aggregationPath')
      .get();

    // 2. Parse and sort by timestamp
    final records = _parseRecords(snapshot);
    records.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 3. Calculate differences
    final usageEntries = <UsageHistoryEntry>[];
    for (int i = 1; i < records.length; i++) {
      final prevReading = records[i - 1].totalEnergy;
      final currReading = records[i].totalEnergy;
      final usage = currReading - prevReading;

      if (usage >= 0) {  // Prevent negative usage
        usageEntries.add(UsageHistoryEntry(
          timestamp: records[i].timestamp,
          formattedTimestamp: _formatTimestamp(records[i].timestamp, interval),
          previousReading: prevReading,
          currentReading: currReading,
          usage: usage,
          intervalType: interval,
        ));
      }
    }

    // 4. Sort descending for display (most recent first)
    usageEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return usageEntries;
  }
}
```

#### Chatbot Screen

**Layout:**
```
Column
├── App Bar
│   ├── Back Button
│   └── Title: "Energy Assistant"
│
├── Message List (Expanded)
│   └── ListView.builder
│       └── For each message:
│           ├── User Message (Right-aligned, Blue)
│           │   ├── Message Text
│           │   └── Timestamp
│           │
│           └── Bot Message (Left-aligned, Grey)
│               ├── Avatar Icon
│               ├── Message Text
│               ├── Data Cards (if applicable)
│               │   ├── Hub Status Card
│               │   ├── Energy Metrics Card
│               │   └── Cost Information Card
│               └── Timestamp
│
├── Typing Indicator (when bot is processing)
│
└── Input Row
    ├── Text Field (Message Input)
    ├── Attachment Button
    └── Send Button
```

**Chatbot Data Integration:**
```dart
class ChatbotDataService {
  final RealtimeDbService _realtimeService;
  final FirebaseFirestore _firestore;
  final PriceProvider _priceProvider;

  Future<String> generateResponse(String userQuery) async {
    // 1. Fetch current system state
    final systemData = await getSystemSnapshot();

    // 2. Parse user intent (simplified NLP)
    final intent = _parseIntent(userQuery);

    // 3. Generate response based on intent
    switch (intent) {
      case Intent.currentPower:
        return _generatePowerResponse(systemData);
      case Intent.costToday:
        return _generateCostResponse(systemData);
      case Intent.deviceStatus:
        return _generateDeviceStatusResponse(systemData);
      case Intent.energyHistory:
        return _generateHistoryResponse(systemData);
      default:
        return _generateGeneralResponse(userQuery, systemData);
    }
  }

  Future<Map<String, dynamic>> getSystemSnapshot() async {
    final hubs = await _realtimeService.getAllHubsData();
    final devices = await _firestore
      .collection('users')
      .doc(_userId)
      .collection('devices')
      .get();

    // Aggregate totals
    double totalPower = 0;
    double totalEnergy = 0;
    double avgVoltage = 0;
    int hubCount = 0;

    hubs.forEach((serial, hubData) {
      totalPower += hubData['total_power'] ?? 0;
      totalEnergy += hubData['total_energy'] ?? 0;
      avgVoltage += hubData['total_voltage'] ?? 0;
      hubCount++;
    });

    avgVoltage = hubCount > 0 ? avgVoltage / hubCount : 0;

    return {
      'totalPower': totalPower,
      'totalEnergy': totalEnergy,
      'avgVoltage': avgVoltage,
      'hubCount': hubCount,
      'activeDevices': devices.docs.length,
      'pricePerKWH': _priceProvider.pricePerKWH,
      'timestamp': DateTime.now(),
    };
  }
}
```

#### Settings Screen

**Layout:**
```
ListView
├── User Profile Section
│   ├── Profile Picture
│   ├── Full Name
│   └── Email
│
├── Energy Settings
│   ├── Price per kWh
│   │   ├── Current Price Display
│   │   └── Edit Button
│   ├── Bill Due Date
│   │   ├── Current Due Date
│   │   └── Edit Button
│   └── Default Analytics View
│       ├── Default Metric
│       └── Default Time Range
│
├── Appearance
│   ├── Theme Toggle (Dark/Light)
│   └── Font Size Preference
│
├── Notifications
│   ├── Enable/Disable Notifications
│   ├── Notification Preferences
│   │   ├── Hub Toggle Alerts
│   │   ├── Cost Threshold Alerts
│   │   └── Due Date Reminders
│   └── Notification Sound
│
├── Account
│   ├── Change Password
│   ├── Email Verification Status
│   └── Account Creation Date
│
└── Actions
    ├── Logout Button
    └── Delete Account Button (with confirmation)
```

### 4.3 Reusable Widgets

#### MiniNotificationBox

**Purpose:** Display price and due date information with quick edit access

```dart
class MiniNotificationBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<PriceProvider, DueDateProvider>(
      builder: (context, priceProvider, dueDateProvider, child) {
        final daysRemaining = dueDateProvider.daysUntilDue;
        final isOverdue = dueDateProvider.isOverdue;

        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Price section
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.attach_money, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      '₱${priceProvider.pricePerKWH.toStringAsFixed(2)}/kWh',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit, size: 16),
                      onPressed: () => _showEditPriceDialog(context),
                    ),
                  ],
                ),
              ),

              // Due date section
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: isOverdue ? Colors.red : Colors.blue,
                    ),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOverdue ? 'Overdue!' : '$daysRemaining days',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isOverdue ? Colors.red : null,
                          ),
                        ),
                        Text(
                          DateFormat('MMM dd').format(dueDateProvider.dueDate),
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.edit, size: 16),
                      onPressed: () => _showEditDueDateDialog(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

#### NotificationPanel

**Purpose:** Display notification stream with read/delete functionality

```dart
class NotificationPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final notifications = notificationProvider.notifications;

        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No notifications',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return Dismissible(
              key: Key(notification.id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) {
                notificationProvider.deleteNotification(notification.id);
              },
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: EdgeInsets.only(right: 16),
                child: Icon(Icons.delete, color: Colors.white),
              ),
              child: ListTile(
                leading: _getNotificationIcon(notification.type),
                title: Text(
                  notification.message,
                  style: TextStyle(
                    fontWeight: notification.isRead
                      ? FontWeight.normal
                      : FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  _formatTimestamp(notification.timestamp),
                  style: TextStyle(fontSize: 12),
                ),
                trailing: notification.isRead
                  ? null
                  : Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                onTap: () {
                  if (!notification.isRead) {
                    notificationProvider.markAsRead(notification.id);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.hubToggle:
        return Icon(Icons.power_settings_new, color: Colors.orange);
      case NotificationType.priceUpdate:
        return Icon(Icons.attach_money, color: Colors.green);
      case NotificationType.dueDate:
        return Icon(Icons.calendar_today, color: Colors.blue);
      case NotificationType.highUsage:
        return Icon(Icons.warning, color: Colors.red);
      default:
        return Icon(Icons.info, color: Colors.grey);
    }
  }
}
```

#### CustomHeader

**Purpose:** App bar with user profile, theme toggle, and notifications

```dart
class CustomHeader extends StatelessWidget implements PreferredSizeWidget {
  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text('Smart Energy System'),
      actions: [
        // Theme toggle
        Consumer<ThemeNotifier>(
          builder: (context, themeNotifier, child) {
            return IconButton(
              icon: Icon(
                themeNotifier.isDarkMode
                  ? Icons.light_mode
                  : Icons.dark_mode,
              ),
              onPressed: () {
                themeNotifier.toggleTheme();
              },
            );
          },
        ),

        // Notifications
        Consumer<NotificationProvider>(
          builder: (context, notificationProvider, child) {
            final unreadCount = notificationProvider.unreadCount;
            return Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NotificationPanel(),
                      ),
                    );
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$unreadCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        // User profile
        IconButton(
          icon: CircleAvatar(
            backgroundImage: AssetImage('assets/default_avatar.png'),
          ),
          onPressed: () {
            Navigator.pushNamed(context, '/profile');
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
```

#### CustomSidebarNav

**Purpose:** Adaptive navigation (sidebar for desktop, bottom nav for mobile)

```dart
class CustomSidebarNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;

    if (isDesktop) {
      return NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onItemSelected,
        labelType: NavigationRailLabelType.all,
        destinations: _buildNavItems(),
      );
    } else {
      return BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onItemSelected,
        items: _buildBottomNavItems(),
        type: BottomNavigationBarType.fixed,
      );
    }
  }

  List<NavigationRailDestination> _buildNavItems() {
    return [
      NavigationRailDestination(
        icon: Icon(Icons.person),
        label: Text('Profile'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.dashboard),
        label: Text('Overview'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.devices),
        label: Text('Devices'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.analytics),
        label: Text('Analytics'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.history),
        label: Text('History'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.settings),
        label: Text('Settings'),
      ),
    ];
  }

  List<BottomNavigationBarItem> _buildBottomNavItems() {
    return [
      BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Overview'),
      BottomNavigationBarItem(icon: Icon(Icons.devices), label: 'Devices'),
      BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
      BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
      BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
    ];
  }
}
```

---

## 5. STATE MANAGEMENT APPROACH

### 5.1 Provider Pattern Implementation

**Why Provider?**
- Official Flutter recommendation
- Simple to understand and implement
- Excellent for medium-complexity apps
- Good balance between simplicity and power
- Strong community support
- Built-in dependency injection

**MultiProvider Setup** (main.dart):
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        // Core service (singleton)
        Provider<RealtimeDbService>(
          create: (_) => RealtimeDbService(),
          dispose: (_, service) => service.dispose(),
        ),

        // Theme management
        ChangeNotifierProvider<ThemeNotifier>(
          create: (_) => ThemeNotifier(),
        ),

        // Price management
        ChangeNotifierProvider<PriceProvider>(
          create: (context) => PriceProvider(
            firestoreService: context.read<FirebaseFirestore>(),
          ),
        ),

        // Due date management
        ChangeNotifierProvider<DueDateProvider>(
          create: (context) => DueDateProvider(
            firestoreService: context.read<FirebaseFirestore>(),
          ),
        ),

        // Notification management
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider(),
        ),
      ],
      child: MyApp(),
    ),
  );
}
```

**Consuming Providers in UI:**
```dart
// 1. Consumer (rebuilds only this widget)
Consumer<PriceProvider>(
  builder: (context, priceProvider, child) {
    return Text('₱${priceProvider.pricePerKWH}');
  },
)

// 2. Consumer2 (multiple providers)
Consumer2<PriceProvider, DueDateProvider>(
  builder: (context, priceProvider, dueDateProvider, child) {
    return PriceAndDueDateWidget(
      price: priceProvider.pricePerKWH,
      dueDate: dueDateProvider.dueDate,
    );
  },
)

// 3. Provider.of (simple access)
final priceProvider = Provider.of<PriceProvider>(context);

// 4. context.watch (in build method, rebuilds on change)
final price = context.watch<PriceProvider>().pricePerKWH;

// 5. context.read (one-time access, no rebuild)
context.read<PriceProvider>().updatePrice(12.0);
```

### 5.2 Key State Providers

#### A. RealtimeDbService (Core Service Provider)

**Responsibility:** Central hub for all Firebase Realtime Database interactions

```dart
class RealtimeDbService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Streams (BehaviorSubjects for replay capability)
  final _hubDataController = StreamController<Map<String, dynamic>>.broadcast();
  final _activeHubController = BehaviorSubject<List<String>>();
  final _primaryHubController = BehaviorSubject<String?>();
  final _hubRemovedController = StreamController<String>.broadcast();
  final _hubAddedController = StreamController<String>.broadcast();

  // Public stream getters
  Stream<Map<String, dynamic>> get hubDataStream => _hubDataController.stream;
  Stream<List<String>> get activeHubStream => _activeHubController.stream;
  Stream<String?> get primaryHubStream => _primaryHubController.stream;
  Stream<String> get hubRemovedStream => _hubRemovedController.stream;
  Stream<String> get hubAddedStream => _hubAddedController.stream;

  // Private state
  Map<String, StreamSubscription> _subscriptions = {};
  List<String> _activeHubs = [];
  String? _primaryHub;

  // Initialize service
  Future<void> initialize(String userId) async {
    await _subscribeToUserHubs(userId);
  }

  // Subscribe to user's hubs
  Future<void> _subscribeToUserHubs(String userId) async {
    final hubsRef = _database
      .ref('users/espthesisbmn/hubs')
      .orderByChild('ownerId')
      .equalTo(userId);

    // Listen for hub additions
    hubsRef.onChildAdded.listen((event) {
      final serial = event.snapshot.key;
      if (serial != null) {
        _activeHubs.add(serial);
        _activeHubController.add(_activeHubs);
        _subscribeToHubData(serial);
        _hubAddedController.add(serial);

        // Set as primary if first hub
        if (_primaryHub == null) {
          _primaryHub = serial;
          _primaryHubController.add(_primaryHub);
        }
      }
    });

    // Listen for hub removals
    hubsRef.onChildRemoved.listen((event) {
      final serial = event.snapshot.key;
      if (serial != null) {
        _activeHubs.remove(serial);
        _activeHubController.add(_activeHubs);
        _subscriptions[serial]?.cancel();
        _subscriptions.remove(serial);
        _hubRemovedController.add(serial);

        // Update primary hub if removed
        if (_primaryHub == serial) {
          _primaryHub = _activeHubs.isNotEmpty ? _activeHubs.first : null;
          _primaryHubController.add(_primaryHub);
        }
      }
    });
  }

  // Subscribe to individual hub data
  void _subscribeToHubData(String serialNumber) {
    final hubRef = _database.ref(
      'users/espthesisbmn/hubs/$serialNumber/aggregations/per_second/data'
    );

    final subscription = hubRef.limitToLast(1).onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(
          event.snapshot.value as Map
        );

        _hubDataController.add({
          serialNumber: data,
        });
      }
    });

    _subscriptions[serialNumber] = subscription;
  }

  // Get all hubs data snapshot
  Future<Map<String, Map<String, dynamic>>> getAllHubsData() async {
    final result = <String, Map<String, dynamic>>{};

    for (final serial in _activeHubs) {
      final snapshot = await _database
        .ref('users/espthesisbmn/hubs/$serial/aggregations/per_second/data')
        .limitToLast(1)
        .get();

      if (snapshot.value != null) {
        final data = Map<String, dynamic>.from(
          (snapshot.value as Map).values.first
        );
        result[serial] = data;
      }
    }

    return result;
  }

  // Set primary hub for analytics
  void setPrimaryHub(String serialNumber) {
    if (_activeHubs.contains(serialNumber)) {
      _primaryHub = serialNumber;
      _primaryHubController.add(_primaryHub);
    }
  }

  // Cleanup
  void dispose() {
    _subscriptions.values.forEach((sub) => sub.cancel());
    _hubDataController.close();
    _activeHubController.close();
    _primaryHubController.close();
    _hubRemovedController.close();
    _hubAddedController.close();
  }
}
```

**Key Streams:**

1. **hubDataStream** - Broadcasts real-time hub and plug data updates
   - Updated every second
   - Contains power, voltage, current, energy for all plugs
   - Used by Energy Overview screen

2. **activeHubStream** - List of currently active hubs
   - Updates when hubs added/removed
   - Used for hub selection dropdowns

3. **primaryHubStream** - Primary hub for analytics
   - User-selectable via dropdown
   - Persists across sessions
   - Used by Analytics screen

4. **hubRemovedStream** - Hub removal events
   - Triggers cleanup logic
   - Updates UI to remove hub displays

5. **hubAddedStream** - Hub addition events
   - Triggers subscription to new hub
   - Updates UI to show new hub

#### B. ThemeNotifier

**Responsibility:** Manage dark/light theme preference

```dart
class ThemeNotifier extends ChangeNotifier {
  bool _isDarkMode = false;
  final SharedPreferences _prefs;

  ThemeNotifier() {
    _loadThemePreference();
  }

  bool get isDarkMode => _isDarkMode;

  ThemeData get currentTheme => _isDarkMode ? _darkTheme : _lightTheme;

  // Load saved preference
  Future<void> _loadThemePreference() async {
    _isDarkMode = _prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  // Toggle theme
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  // Theme definitions
  static final _lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.white,
    scaffoldBackgroundColor: Colors.grey[100],
    cardColor: Colors.white,
    colorScheme: ColorScheme.light(
      primary: Colors.blue,
      secondary: Colors.blueAccent,
    ),
  );

  static final _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Color(0xFF0f1419),
    scaffoldBackgroundColor: Color(0xFF0f1419),
    cardColor: Color(0xFF1a2332),
    colorScheme: ColorScheme.dark(
      primary: Color(0xFF1a2332),
      secondary: Colors.blueAccent,
    ),
  );
}
```

**Usage:**
```dart
// In MaterialApp
Consumer<ThemeNotifier>(
  builder: (context, themeNotifier, child) {
    return MaterialApp(
      theme: themeNotifier.currentTheme,
      home: HomeScreen(),
    );
  },
)
```

#### C. PriceProvider

**Responsibility:** Manage electricity rate and cost calculations

```dart
class PriceProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final String _userId;

  double _pricePerKWH = 11.0;  // Default rate
  List<PriceHistory> _priceHistory = [];

  PriceProvider({
    required FirebaseFirestore firestoreService,
    required String userId,
  })  : _firestore = firestoreService,
        _userId = userId {
    _loadPrice();
  }

  double get pricePerKWH => _pricePerKWH;
  List<PriceHistory> get priceHistory => _priceHistory;

  // Load price from Firestore
  Future<void> _loadPrice() async {
    try {
      final doc = await _firestore
        .collection('users')
        .doc(_userId)
        .get();

      if (doc.exists && doc.data()?['pricePerKWH'] != null) {
        _pricePerKWH = doc.data()!['pricePerKWH'].toDouble();
        notifyListeners();
      }
    } catch (e) {
      print('Error loading price: $e');
    }
  }

  // Update price and save to Firestore
  Future<void> updatePrice(double newPrice) async {
    if (newPrice <= 0) {
      throw ArgumentError('Price must be greater than 0');
    }

    try {
      // Save to Firestore
      await _firestore
        .collection('users')
        .doc(_userId)
        .update({'pricePerKWH': newPrice});

      // Add to price history
      await _firestore
        .collection('users')
        .doc(_userId)
        .collection('priceHistory')
        .add({
          'oldPrice': _pricePerKWH,
          'newPrice': newPrice,
          'timestamp': FieldValue.serverTimestamp(),
        });

      _pricePerKWH = newPrice;
      notifyListeners();
    } catch (e) {
      print('Error updating price: $e');
      rethrow;
    }
  }

  // Calculate cost for given energy consumption
  double calculateCost(double energyKWH) {
    return energyKWH * _pricePerKWH;
  }

  // Calculate daily cost
  Future<double> calculateDailyCost(String serialNumber) async {
    final today = DateTime.now();
    final yesterday = today.subtract(Duration(days: 1));

    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final yesterdayKey = DateFormat('yyyy-MM-dd').format(yesterday);

    final todaySnapshot = await FirebaseDatabase.instance
      .ref('users/espthesisbmn/hubs/$serialNumber/aggregations/daily_aggregation/$todayKey')
      .get();

    final yesterdaySnapshot = await FirebaseDatabase.instance
      .ref('users/espthesisbmn/hubs/$serialNumber/aggregations/daily_aggregation/$yesterdayKey')
      .get();

    if (todaySnapshot.exists && yesterdaySnapshot.exists) {
      final todayEnergy = (todaySnapshot.value as Map)['total_energy'] ?? 0;
      final yesterdayEnergy = (yesterdaySnapshot.value as Map)['total_energy'] ?? 0;

      final usage = todayEnergy - yesterdayEnergy;
      return calculateCost(usage);
    }

    return 0.0;
  }
}
```

**Test Coverage:** 41 tests (100% coverage)
- Price validation
- Firestore synchronization
- Cost calculations
- Price history tracking

#### D. DueDateProvider

**Responsibility:** Manage billing due date

```dart
class DueDateProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final String _userId;

  DateTime _dueDate = DateTime.now().add(Duration(days: 30));

  DueDateProvider({
    required FirebaseFirestore firestoreService,
    required String userId,
  })  : _firestore = firestoreService,
        _userId = userId {
    _loadDueDate();
  }

  DateTime get dueDate => _dueDate;

  int get daysUntilDue {
    final now = DateTime.now();
    return _dueDate.difference(now).inDays;
  }

  bool get isOverdue => daysUntilDue < 0;

  bool get isDueSoon => daysUntilDue <= 7 && daysUntilDue >= 0;

  // Load due date from Firestore
  Future<void> _loadDueDate() async {
    try {
      final doc = await _firestore
        .collection('users')
        .doc(_userId)
        .get();

      if (doc.exists && doc.data()?['dueDate'] != null) {
        final timestamp = doc.data()!['dueDate'] as Timestamp;
        _dueDate = timestamp.toDate();
        notifyListeners();
      }
    } catch (e) {
      print('Error loading due date: $e');
    }
  }

  // Update due date
  Future<void> updateDueDate(DateTime newDueDate) async {
    try {
      await _firestore
        .collection('users')
        .doc(_userId)
        .update({
          'dueDate': Timestamp.fromDate(newDueDate),
        });

      _dueDate = newDueDate;
      notifyListeners();
    } catch (e) {
      print('Error updating due date: $e');
      rethrow;
    }
  }
}
```

**Usage:**
```dart
Consumer<DueDateProvider>(
  builder: (context, dueDateProvider, child) {
    return Text(
      dueDateProvider.isOverdue
        ? 'OVERDUE!'
        : '${dueDateProvider.daysUntilDue} days until due',
      style: TextStyle(
        color: dueDateProvider.isOverdue
          ? Colors.red
          : dueDateProvider.isDueSoon
            ? Colors.orange
            : Colors.green,
      ),
    );
  },
)
```

#### E. NotificationProvider

**Responsibility:** Manage in-app notifications

```dart
class NotificationProvider extends ChangeNotifier {
  final List<NotificationItem> _notifications = [];

  List<NotificationItem> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Add notification
  void addNotification(NotificationType type, String message) {
    final notification = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      message: message,
      timestamp: DateTime.now(),
      isRead: false,
    );

    _notifications.insert(0, notification);
    notifyListeners();
  }

  // Mark as read
  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  // Mark all as read
  void markAllAsRead() {
    _notifications.replaceRange(
      0,
      _notifications.length,
      _notifications.map((n) => n.copyWith(isRead: true)).toList(),
    );
    notifyListeners();
  }

  // Delete notification
  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  // Clear all
  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  NotificationItem copyWith({
    String? id,
    NotificationType? type,
    String? message,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}

enum NotificationType {
  hubToggle,
  deviceStateChange,
  priceUpdate,
  dueDate,
  highUsage,
  costThreshold,
}
```

### 5.3 Reactive State Management with RxDart

**Why RxDart?**
- Extends Dart streams with powerful operators
- BehaviorSubject provides last value replay
- Efficient stream transformations
- Reactive programming paradigm

**BehaviorSubject Usage:**
```dart
// In RealtimeDbService
final _activeHubController = BehaviorSubject<List<String>>();

// Provides last emitted value to new subscribers
Stream<List<String>> get activeHubStream => _activeHubController.stream;

// Late subscriber still gets current state
_activeHubController.add(['hub1', 'hub2']);
// ... time passes ...
activeHubStream.listen((hubs) {
  print(hubs);  // Immediately receives ['hub1', 'hub2']
});
```

**Stream Transformations:**
```dart
// Combine multiple hub streams
Stream<Map<String, dynamic>> get combinedHubData {
  return Rx.combineLatest(
    _activeHubs.map((serial) => _getHubStream(serial)),
    (values) {
      final combined = <String, dynamic>{};
      for (int i = 0; i < values.length; i++) {
        combined[_activeHubs[i]] = values[i];
      }
      return combined;
    },
  );
}

// Debounce rapid updates
Stream<String> get debouncedSearch {
  return _searchController.stream
    .debounceTime(Duration(milliseconds: 300));
}

// Switch to latest stream
Stream<List<UsageHistoryEntry>> get usageStream {
  return _intervalController.stream
    .switchMap((interval) => _fetchUsageData(interval));
}
```

**Memory Management:**
```dart
class SomeService {
  final _subscriptions = <StreamSubscription>[];

  void initialize() {
    // Store subscriptions for cleanup
    _subscriptions.add(
      someStream.listen((data) {
        // Handle data
      }),
    );
  }

  void dispose() {
    // Cancel all subscriptions
    _subscriptions.forEach((sub) => sub.cancel());
    _behaviorSubject.close();
  }
}
```

---

## 6. API INTEGRATION AND DATA FLOW PATTERNS

### 6.1 Firebase Realtime Database Structure

**Complete Schema:**
```
users/
└── espthesisbmn/
    └── hubs/
        └── {hubSerialNumber}/           # e.g., "SN12345678"
            ├── assigned: boolean        # true if linked to user
            ├── ownerId: string          # Firebase Auth UID
            ├── nickname: string         # User-assigned hub name
            ├── ssr_state: boolean       # Master relay state (on/off)
            ├── last_seen: timestamp     # Last communication timestamp
            │
            ├── plugs/
            │   └── {plugId}/            # e.g., "plug1", "plug2"
            │       ├── name: string     # Device name
            │       ├── power: number    # Current power (Watts)
            │       ├── voltage: number  # Current voltage (Volts)
            │       ├── current: number  # Current amperage (Amps)
            │       ├── energy: number   # Cumulative energy (kWh)
            │       └── ssr_state: boolean  # Individual plug relay state
            │
            └── aggregations/
                ├── per_second/
                │   └── data/
                │       └── {timestamp}/         # Unix milliseconds
                │           ├── total_power: number    # Sum of all plugs
                │           ├── total_voltage: number  # Avg of all plugs
                │           ├── total_current: number  # Sum of all plugs
                │           ├── total_energy: number   # Sum of all plugs
                │           └── timestamp: number      # Server timestamp
                │
                ├── hourly_aggregation/
                │   └── {YYYY-MM-DD-HH}/        # e.g., "2025-12-09-14"
                │       ├── avg_power: number         # Average power in hour
                │       ├── total_energy: number      # Cumulative at hour end
                │       ├── avg_voltage: number       # Average voltage
                │       ├── avg_current: number       # Average current
                │       ├── min_voltage: number       # Minimum voltage
                │       ├── max_voltage: number       # Maximum voltage
                │       ├── total_readings: number    # Count of samples
                │       └── timestamp: number         # Hour start timestamp
                │
                ├── daily_aggregation/
                │   └── {YYYY-MM-DD}/           # e.g., "2025-12-09"
                │       ├── avg_power: number
                │       ├── total_energy: number
                │       ├── avg_voltage: number
                │       ├── avg_current: number
                │       ├── min_voltage: number
                │       ├── max_voltage: number
                │       ├── total_readings: number
                │       └── timestamp: number
                │
                ├── weekly_aggregation/
                │   └── {YYYY-Www}/             # ISO 8601 week, e.g., "2025-W50"
                │       ├── avg_power: number
                │       ├── total_energy: number
                │       ├── avg_voltage: number
                │       ├── avg_current: number
                │       ├── min_voltage: number
                │       ├── max_voltage: number
                │       ├── total_readings: number
                │       └── timestamp: number
                │
                └── monthly_aggregation/
                    └── {YYYY-MM}/              # e.g., "2025-12"
                        ├── avg_power: number
                        ├── total_energy: number
                        ├── avg_voltage: number
                        ├── avg_current: number
                        ├── min_voltage: number
                        ├── max_voltage: number
                        ├── total_readings: number
                        └── timestamp: number
```

**Design Rationale:**

1. **Centralized Data Path (`users/espthesisbmn`):**
   - Simplifies hardware configuration (single upload path)
   - Reduces hub-side complexity
   - Filtering by `ownerId` provides multi-user support
   - Easier admin oversight

2. **Hierarchical Aggregations:**
   - Optimizes query performance (fewer data points)
   - Reduces bandwidth usage
   - Enables efficient historical queries
   - Balances storage vs. query speed

3. **Flat Plug Structure:**
   - Simple key-value pairs for fast reads
   - Direct SSR control path
   - Minimal nesting for real-time updates

### 6.2 Firebase Firestore Structure

**Complete Schema:**
```
users/
└── {userId}/                    # Firebase Auth UID
    ├── email: string
    ├── fullName: string
    ├── address: string
    ├── phoneNumber: string
    ├── photoURL: string
    ├── pricePerKWH: number      # Electricity rate (₱)
    ├── dueDate: Timestamp       # Billing due date
    ├── defaultAnalyticsMetric: string   # "power" | "voltage" | "current" | "energy"
    ├── defaultAnalyticsTimeRange: string # "hourly" | "daily" | "weekly" | "monthly"
    ├── createdAt: Timestamp
    ├── updatedAt: Timestamp
    │
    ├── devices/                 # Virtual devices (named plugs)
    │   └── {deviceId}/
    │       ├── name: string
    │       ├── status: string   # "active" | "inactive"
    │       ├── icon: number     # FontAwesome icon code point
    │       ├── usage: number    # Recent usage (kWh)
    │       ├── percent: number  # Usage percentage
    │       ├── plug: string     # Physical plug ID ("plug1", "plug2")
    │       ├── serialNumber: string  # Hub serial number
    │       ├── user_email: string
    │       └── createdAt: Timestamp
    │
    ├── priceHistory/            # Price change history
    │   └── {historyId}/
    │       ├── oldPrice: number
    │       ├── newPrice: number
    │       ├── timestamp: Timestamp
    │       └── changedBy: string  # User who made change
    │
    └── notifications/           # User notifications (future)
        └── {notificationId}/
            ├── type: string
            ├── message: string
            ├── timestamp: Timestamp
            ├── isRead: boolean
            └── data: map        # Additional metadata
```

**Design Rationale:**

1. **User-Centric Structure:**
   - Each user has isolated document
   - Easy to implement security rules
   - Scalable user management

2. **Device Abstraction:**
   - Virtual devices map to physical plugs
   - Allows renaming without hardware changes
   - Icon customization for UX

3. **Settings in User Document:**
   - Fast single-read access
   - Atomic updates
   - Minimal query overhead

### 6.3 Data Flow Patterns

#### A. Real-Time Data Synchronization Flow

```
┌──────────────────┐
│ Smart Plug       │ (ACS712 current sensor, voltage divider)
│ - Power calc     │
│ - Voltage read   │
│ - Current read   │
│ - Energy accum   │
└────────┬─────────┘
         │ Serial/SPI
         ▼
┌──────────────────┐
│ Central Hub      │ (ESP32)
│ - Aggregate data │
│ - Format JSON    │
│ - Wi-Fi transmit │
└────────┬─────────┘
         │ HTTPS/WebSocket
         ▼
┌──────────────────┐
│ Firebase RTDB    │
│ /per_second/data │
│ - Atomic write   │
│ - Timestamp gen  │
└────────┬─────────┘
         │ Real-time listener
         ▼
┌──────────────────┐
│ RealtimeDbService│ (Flutter app)
│ - Stream listen  │
│ - Data broadcast │
└────────┬─────────┘
         │ hubDataStream
         ▼
┌──────────────────┐
│ StreamBuilder    │ (UI)
│ - Automatic      │
│   rebuild        │
│ - Display update │
└──────────────────┘
```

**Code Implementation:**
```dart
// Hardware (pseudo-code)
void loop() {
  // Read sensors every second
  float power = readPower();
  float voltage = readVoltage();
  float current = readCurrent();
  float energy = accumulateEnergy(power);

  // Upload to Firebase
  String path = "users/espthesisbmn/hubs/SN123/aggregations/per_second/data";
  firebase.set(path + "/" + millis(), {
    "total_power": power,
    "total_voltage": voltage,
    "total_current": current,
    "total_energy": energy,
    "timestamp": millis()
  });

  delay(1000);
}

// Flutter App
class RealtimeDbService {
  void _subscribeToHubData(String serialNumber) {
    final ref = FirebaseDatabase.instance.ref(
      'users/espthesisbmn/hubs/$serialNumber/aggregations/per_second/data'
    );

    // Listen to last value only (efficient)
    ref.limitToLast(1).onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(
          (event.snapshot.value as Map).values.first
        );

        // Broadcast to UI
        _hubDataController.add({
          serialNumber: data,
        });
      }
    });
  }
}

// UI
StreamBuilder<Map<String, dynamic>>(
  stream: realtimeDbService.hubDataStream,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final power = snapshot.data?['total_power'] ?? 0;
      return Text('${power.toStringAsFixed(2)} W');
    }
    return CircularProgressIndicator();
  },
)
```

#### B. Historical Data Aggregation Flow

```
┌──────────────────┐
│ Per-second data  │ (Firebase RTDB)
│ - 3600 records   │ (1 hour worth)
└────────┬─────────┘
         │ Cloud Function (scheduled every hour)
         ▼
┌──────────────────┐
│ Aggregation Func │
│ - Query hour     │
│ - Calculate avg  │
│ - Find min/max   │
│ - Count readings │
└────────┬─────────┘
         │ Write aggregated data
         ▼
┌──────────────────┐
│ Hourly Agg Node  │ (Firebase RTDB)
│ /hourly/2025-..  │
│ - avg_power      │
│ - total_energy   │
│ - statistics     │
└────────┬─────────┘
         │ Delete source data (cleanup)
         ▼
┌──────────────────┐
│ Per-second data  │ (Deleted after aggregation)
│ (Storage saved)  │
└──────────────────┘
```

**Aggregation Logic (Cloud Function - pseudo-code):**
```javascript
// Cloud Function (Firebase Functions)
exports.aggregateHourlyData = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    const db = admin.database();
    const now = new Date();
    const hourKey = format(now, 'yyyy-MM-dd-HH');

    // For each hub
    const hubsSnapshot = await db.ref('users/espthesisbmn/hubs').once('value');

    for (const [serial, hubData] of Object.entries(hubsSnapshot.val())) {
      const perSecondRef = db.ref(
        `users/espthesisbmn/hubs/${serial}/aggregations/per_second/data`
      );

      // Query last hour's data
      const hourAgo = now.getTime() - (60 * 60 * 1000);
      const dataSnapshot = await perSecondRef
        .orderByKey()
        .startAt(String(hourAgo))
        .endAt(String(now.getTime()))
        .once('value');

      const data = Object.values(dataSnapshot.val() || {});

      // Calculate aggregations
      const aggregation = {
        avg_power: average(data.map(d => d.total_power)),
        total_energy: data[data.length - 1].total_energy, // Latest reading
        avg_voltage: average(data.map(d => d.total_voltage)),
        avg_current: average(data.map(d => d.total_current)),
        min_voltage: Math.min(...data.map(d => d.total_voltage)),
        max_voltage: Math.max(...data.map(d => d.total_voltage)),
        total_readings: data.length,
        timestamp: now.getTime(),
      };

      // Write to hourly aggregation
      await db.ref(
        `users/espthesisbmn/hubs/${serial}/aggregations/hourly_aggregation/${hourKey}`
      ).set(aggregation);

      // Delete aggregated per-second data (cleanup)
      await perSecondRef
        .orderByKey()
        .endAt(String(now.getTime()))
        .once('value')
        .then(snapshot => snapshot.ref.remove());
    }

    return null;
  });

// Daily aggregation (similar logic, runs once per day)
exports.aggregateDailyData = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    // Aggregate hourly data into daily
    // ...
  });
```

#### C. Usage Calculation Flow

```
┌──────────────────┐
│ User selects     │
│ interval type    │ (Hourly, Daily, Weekly, Monthly)
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ UsageHistory     │
│ Service          │
│ - Fetch agg data │
└────────┬─────────┘
         │ Firebase query
         ▼
┌──────────────────┐
│ Aggregated Data  │ (RTDB)
│ [..., ...]       │ Sorted by timestamp
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Difference       │
│ Calculation      │
│ usage = curr -   │
│         prev     │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ UsageHistory     │
│ Entry list       │
│ - Prev reading   │
│ - Curr reading   │
│ - Usage          │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ UI Display       │
│ - Table view     │
│ - Export Excel   │
└──────────────────┘
```

**Code Implementation:**
```dart
class UsageHistoryService {
  Future<List<UsageHistoryEntry>> calculateUsage(
    String serialNumber,
    IntervalType interval,
  ) async {
    // 1. Determine aggregation path
    final aggregationPath = _getAggregationPath(interval);

    // 2. Fetch data from Firebase
    final snapshot = await FirebaseDatabase.instance
      .ref('users/espthesisbmn/hubs/$serialNumber/aggregations/$aggregationPath')
      .orderByKey()
      .limitToLast(100)  // Last 100 intervals
      .get();

    if (!snapshot.exists) return [];

    // 3. Parse into HistoryRecord objects
    final records = <HistoryRecord>[];
    final data = Map<String, dynamic>.from(snapshot.value as Map);

    data.forEach((timestamp, value) {
      final valueMap = Map<String, dynamic>.from(value);
      records.add(HistoryRecord(
        timestamp: timestamp,
        totalEnergy: (valueMap['total_energy'] ?? 0).toDouble(),
        avgPower: (valueMap['avg_power'] ?? 0).toDouble(),
        avgVoltage: (valueMap['avg_voltage'] ?? 0).toDouble(),
        avgCurrent: (valueMap['avg_current'] ?? 0).toDouble(),
      ));
    });

    // 4. Sort by timestamp ascending
    records.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 5. Calculate differences
    final usageEntries = <UsageHistoryEntry>[];

    for (int i = 1; i < records.length; i++) {
      final prevReading = records[i - 1].totalEnergy;
      final currReading = records[i].totalEnergy;
      final usage = currReading - prevReading;

      // Only add if usage is non-negative (prevents meter rollover issues)
      if (usage >= 0) {
        usageEntries.add(UsageHistoryEntry(
          timestamp: records[i].timestamp,
          formattedTimestamp: _formatTimestamp(records[i].timestamp, interval),
          previousReading: prevReading,
          currentReading: currReading,
          usage: usage,
          intervalType: interval,
        ));
      }
    }

    // 6. Sort by timestamp descending (most recent first)
    usageEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return usageEntries;
  }

  String _getAggregationPath(IntervalType interval) {
    switch (interval) {
      case IntervalType.hourly:
        return 'hourly_aggregation';
      case IntervalType.daily:
        return 'daily_aggregation';
      case IntervalType.weekly:
        return 'weekly_aggregation';
      case IntervalType.monthly:
        return 'monthly_aggregation';
    }
  }

  String _formatTimestamp(String timestamp, IntervalType interval) {
    switch (interval) {
      case IntervalType.hourly:
        // "2025-12-09-14" → "Dec 09, 2025 - 2:00 PM"
        final parts = timestamp.split('-');
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
          int.parse(parts[3]),
        );
        return DateFormat('MMM dd, yyyy - h:00 a').format(date);

      case IntervalType.daily:
        // "2025-12-09" → "December 09, 2025"
        final parts = timestamp.split('-');
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        return DateFormat('MMMM dd, yyyy').format(date);

      case IntervalType.weekly:
        // "2025-W50" → "Week 50, 2025"
        return timestamp.replaceAll('W', 'Week ').replaceAll('-', ', ');

      case IntervalType.monthly:
        // "2025-12" → "December 2025"
        final parts = timestamp.split('-');
        final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
        return DateFormat('MMMM yyyy').format(date);
    }
  }
}
```

#### D. SSR Control Flow (User → Hardware)

```
┌──────────────────┐
│ User taps SSR    │
│ toggle button    │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ UI calls service │
│ toggleSSR(true)  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Update Firebase  │
│ RTDB:            │
│ /hubs/SN/        │
│ ssr_state = true │
└────────┬─────────┘
         │ Real-time listener (hardware)
         ▼
┌──────────────────┐
│ Hub receives     │
│ state change     │
│ event            │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Hub toggles      │
│ physical relay   │
│ (SSR ON)         │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Hub confirms by  │
│ writing state    │
│ back to Firebase │
└────────┬─────────┘
         │ Real-time listener (app)
         ▼
┌──────────────────┐
│ UI reflects new  │
│ SSR state        │
│ (toggle updated) │
└──────────────────┘
```

**Code Implementation:**
```dart
// UI Widget
ElevatedButton(
  onPressed: () async {
    final currentState = ssrState;
    await context.read<RealtimeDbService>().toggleSSR(
      serialNumber: 'SN123',
      newState: !currentState,
    );
  },
  child: Text(ssrState ? 'Turn OFF' : 'Turn ON'),
)

// Service
class RealtimeDbService {
  Future<void> toggleSSR({
    required String serialNumber,
    required bool newState,
  }) async {
    await FirebaseDatabase.instance
      .ref('users/espthesisbmn/hubs/$serialNumber/ssr_state')
      .set(newState);

    // Add notification
    final notificationProvider = // ... get provider
    notificationProvider.addNotification(
      NotificationType.hubToggle,
      'Hub $serialNumber turned ${newState ? "ON" : "OFF"}',
    );
  }
}

// Hardware (pseudo-code)
void setup() {
  firebase.subscribe("users/espthesisbmn/hubs/SN123/ssr_state", [](bool newState) {
    digitalWrite(RELAY_PIN, newState ? HIGH : LOW);

    // Confirm state change
    firebase.set("users/espthesisbmn/hubs/SN123/ssr_state", newState);
  });
}
```

---

## 7. UI/UX DESIGN PATTERNS AND PRINCIPLES

### 7.1 Design System

#### Color Scheme

**Light Theme Palette:**
```dart
static final lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: Colors.white,
  scaffoldBackgroundColor: Colors.grey[100],
  cardColor: Colors.white,

  colorScheme: ColorScheme.light(
    primary: Colors.blue,
    secondary: Colors.blueAccent,
    surface: Colors.white,
    background: Colors.grey[100]!,
    error: Colors.red,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Colors.black87,
    onBackground: Colors.black87,
    onError: Colors.white,
  ),

  // Card styling
  cardTheme: CardTheme(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    color: Colors.white,
  ),

  // App bar styling
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black87,
    elevation: 1,
  ),
);
```

**Dark Theme Palette:**
```dart
static final darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: Color(0xFF0f1419),  // Deep dark blue-black
  scaffoldBackgroundColor: Color(0xFF0f1419),
  cardColor: Color(0xFF1a2332),     // Lighter dark blue-grey

  colorScheme: ColorScheme.dark(
    primary: Color(0xFF1a2332),
    secondary: Colors.blueAccent,
    surface: Color(0xFF1a2332),
    background: Color(0xFF0f1419),
    error: Colors.redAccent,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Colors.white70,
    onBackground: Colors.white70,
    onError: Colors.white,
  ),

  cardTheme: CardTheme(
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    color: Color(0xFF1a2332),
  ),

  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF1a2332),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
);
```

**Metric-Specific Colors:**
```dart
class MetricColors {
  static const power = Colors.purple;        // Power (W)
  static const voltage = Colors.orange;      // Voltage (V)
  static const current = Colors.blue;        // Current (A)
  static const energy = Colors.green;        // Energy (kWh)

  static Color getColor(String metric) {
    switch (metric.toLowerCase()) {
      case 'power':
        return power;
      case 'voltage':
        return voltage;
      case 'current':
        return current;
      case 'energy':
        return energy;
      default:
        return Colors.grey;
    }
  }
}
```

**Semantic Colors:**
```dart
class StatusColors {
  static const success = Colors.green;
  static const warning = Colors.orange;
  static const error = Colors.red;
  static const info = Colors.blue;

  static const online = Colors.green;
  static const offline = Colors.grey;

  static const high = Colors.red;
  static const medium = Colors.orange;
  static const low = Colors.green;
}
```

#### Typography

```dart
static final textTheme = TextTheme(
  displayLarge: TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
  ),
  displayMedium: TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
  ),
  displaySmall: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  ),
  headlineMedium: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  ),
  headlineSmall: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  ),
  titleLarge: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  ),
  bodyLarge: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  ),
  bodyMedium: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  ),
  labelLarge: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  ),
);
```

#### Spacing System

```dart
class Spacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Card padding
  static const cardPadding = EdgeInsets.all(md);

  // Screen padding
  static const screenPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: lg,
  );

  // Section spacing
  static const sectionSpacing = SizedBox(height: lg);
}
```

### 7.2 Responsive Design

#### Breakpoints

```dart
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1440;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobile;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobile && width < desktop;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktop;
  }
}
```

#### Adaptive Layouts

**Navigation:**
```dart
Widget build(BuildContext context) {
  if (Breakpoints.isDesktop(context)) {
    return Row(
      children: [
        NavigationRail(...),  // Sidebar
        Expanded(child: content),
      ],
    );
  } else {
    return Scaffold(
      body: content,
      bottomNavigationBar: BottomNavigationBar(...),
    );
  }
}
```

**Grid Layout:**
```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: Breakpoints.isMobile(context) ? 2 : 4,
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
  ),
  itemBuilder: (context, index) => DeviceCard(...),
)
```

**Metric Cards:**
```dart
// Mobile: Vertical stack
Column(
  children: metricCards,
)

// Desktop: Horizontal row
Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: metricCards.map((card) => Expanded(child: card)).toList(),
)
```

#### Constrained Width

```dart
Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: 1100),
    child: content,
  ),
)
```

### 7.3 UX Patterns

#### A. Loading States

**Lottie Animations:**
```dart
// assets/loading_energy.json
Lottie.asset(
  'assets/loading_energy.json',
  width: 200,
  height: 200,
)
```

**Skeleton Loaders:**
```dart
Shimmer.fromColors(
  baseColor: Colors.grey[300]!,
  highlightColor: Colors.grey[100]!,
  child: Container(
    width: double.infinity,
    height: 200,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
  ),
)
```

**Progress Indicators:**
```dart
if (isLoading)
  Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Loading energy data...'),
      ],
    ),
  )
```

#### B. Empty States

```dart
Widget buildEmptyState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.bolt_outlined,
          size: 80,
          color: Colors.grey,
        ),
        SizedBox(height: 16),
        Text(
          'No devices found',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: 8),
        Text(
          'Add a hub to get started',
          style: TextStyle(color: Colors.grey),
        ),
        SizedBox(height: 24),
        ElevatedButton.icon(
          icon: Icon(Icons.add),
          label: Text('Add Hub'),
          onPressed: () => _showAddHubDialog(),
        ),
      ],
    ),
  );
}
```

#### C. Error Handling

**SnackBar Notifications:**
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Failed to update price'),
    backgroundColor: Colors.red,
    action: SnackBarAction(
      label: 'Retry',
      onPressed: () => _retryUpdate(),
    ),
  ),
);
```

**Alert Dialogs:**
```dart
Alert(
  context: context,
  type: AlertType.error,
  title: "Connection Error",
  desc: "Unable to connect to Firebase. Please check your internet connection.",
  buttons: [
    DialogButton(
      child: Text("OK"),
      onPressed: () => Navigator.pop(context),
    ),
  ],
).show();
```

**Inline Error Messages:**
```dart
if (hasError)
  Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.1),
      border: Border.all(color: Colors.red),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(Icons.error, color: Colors.red),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            errorMessage,
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  )
```

**Graceful Degradation:**
```dart
StreamBuilder<Map<String, dynamic>>(
  stream: hubDataStream,
  builder: (context, snapshot) {
    // Error state
    if (snapshot.hasError) {
      return ErrorWidget(
        error: snapshot.error.toString(),
        onRetry: () => _reconnect(),
      );
    }

    // Loading state
    if (snapshot.connectionState == ConnectionState.waiting) {
      return LoadingWidget();
    }

    // Empty state
    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return EmptyStateWidget();
    }

    // Success state
    return DataWidget(data: snapshot.data!);
  },
)
```

#### D. Animations

**Fade-in Animations:**
```dart
FadeTransition(
  opacity: _animationController,
  child: child,
)
```

**Slide Animations:**
```dart
SlideTransition(
  position: Tween<Offset>(
    begin: Offset(1, 0),
    end: Offset.zero,
  ).animate(_animationController),
  child: child,
)
```

**Chart Animations:**
```dart
LineChart(
  LineChartData(
    lineBarsData: [
      LineChartBarData(
        spots: dataPoints,
        isCurved: true,
        dotData: FlDotData(show: false),
      ),
    ],
  ),
  swapAnimationDuration: Duration(milliseconds: 250),
  swapAnimationCurve: Curves.easeInOut,
)
```

**Button Ripples:**
```dart
Material(
  color: Colors.blue,
  borderRadius: BorderRadius.circular(8),
  child: InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () => _handleTap(),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text('Button'),
    ),
  ),
)
```

#### E. Accessibility

**Text Scaling Control:**
```dart
MaterialApp(
  builder: (context, child) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(1.0),
      ),
      child: child!,
    );
  },
)
```

**High Contrast Support:**
```dart
if (MediaQuery.of(context).highContrast) {
  return HighContrastTheme();
} else {
  return NormalTheme();
}
```

**Icon and Text Labels:**
```dart
IconButton(
  icon: Icon(Icons.delete),
  tooltip: 'Delete device',
  onPressed: () => _deleteDevice(),
)
```

**Semantic Labels:**
```dart
Semantics(
  label: 'Current power consumption: 1250 watts',
  child: Text('1250 W'),
)
```

---

*(Continued in next section...)*

---

This theoretical background provides an in-depth understanding of your Smart Energy System's architecture, features, and implementation. Would you like me to continue with the remaining sections (Security, Domain Concepts, Testing, etc.)?

