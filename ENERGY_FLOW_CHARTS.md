# Smart Energy System - Detailed Flow Charts

## Table of Contents
1. [Overall System Architecture Flow](#1-overall-system-architecture-flow)
2. [Energy Data Collection Flow](#2-energy-data-collection-flow)
3. [Real-Time Data Synchronization Flow](#3-real-time-data-synchronization-flow)
4. [Analytics Recording Flow](#4-analytics-recording-flow)
5. [User Interface Data Flow](#5-user-interface-data-flow)
6. [Hub Control Flow](#6-hub-control-flow)
7. [Data Cleanup & Retention Flow](#7-data-cleanup--retention-flow)
8. [Authentication & Access Control Flow](#8-authentication--access-control-flow)
9. [Usage Calculation Flow](#9-usage-calculation-flow)
10. [Complete End-to-End Energy Flow](#10-complete-end-to-end-energy-flow)

---

## 1. Overall System Architecture Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PHYSICAL LAYER                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐          │
│  │ Smart Plug 1 │    │ Smart Plug 2 │    │ Smart Plug N │          │
│  │ (Appliance   │    │ (Appliance   │    │ (Appliance   │          │
│  │  Monitor)    │    │  Monitor)    │    │  Monitor)    │          │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘          │
│         │                   │                   │                   │
│         └───────────────────┼───────────────────┘                   │
│                             │                                        │
│                    ┌────────▼────────┐                               │
│                    │  Central Hub    │                               │
│                    │  (SP001, SP002) │                               │
│                    │   SSR Control   │                               │
│                    └────────┬────────┘                               │
└─────────────────────────────┼──────────────────────────────────────┘
                              │
                              │ WiFi/Network
                              │
┌─────────────────────────────▼──────────────────────────────────────┐
│                        CLOUD LAYER                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │         Firebase Realtime Database                          │   │
│  │                                                              │   │
│  │  users/espthesisbmn/hubs/{serialNumber}/                   │   │
│  │  ├── ssr_state (boolean)                                    │   │
│  │  ├── assigned (boolean)                                     │   │
│  │  ├── ownerId (user_uid)                                     │   │
│  │  ├── nickname (string)                                      │   │
│  │  │                                                           │   │
│  │  ├── plugs/{plugId}/                                        │   │
│  │  │   ├── name                                               │   │
│  │  │   ├── power (W)                                          │   │
│  │  │   ├── voltage (V)                                        │   │
│  │  │   ├── current (A)                                        │   │
│  │  │   ├── energy (kWh)                                       │   │
│  │  │   └── ssr_state (boolean)                               │   │
│  │  │                                                           │   │
│  │  └── aggregations/                                          │   │
│  │      ├── per_second/data/{timestamp}                        │   │
│  │      │   ├── total_power                                    │   │
│  │      │   ├── total_voltage                                  │   │
│  │      │   ├── total_current                                  │   │
│  │      │   └── total_energy                                   │   │
│  │      ├── hourly/{YYYY-MM-DD-HH}/                           │   │
│  │      ├── daily/{YYYY-MM-DD}/                               │   │
│  │      ├── weekly/{YYYY-Www}/                                │   │
│  │      └── monthly/{YYYY-MM}/                                │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │         Firebase Cloud Firestore                            │   │
│  │  users/{userId}/                                            │   │
│  │  ├── email                                                  │   │
│  │  ├── dueDate (billing cycle)                               │   │
│  │  └── pricePerKwh                                            │   │
│  └────────────────────────────────────────────────────────────┘   │
└─────────────────────────────┬──────────────────────────────────────┘
                              │
                              │ Stream Subscriptions
                              │
┌─────────────────────────────▼──────────────────────────────────────┐
│                    APPLICATION LAYER (Flutter)                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │           State Management (Provider Pattern)               │   │
│  │                                                              │   │
│  │  ┌─────────────────────────────────────────────────────┐   │   │
│  │  │  RealtimeDbService (Primary Service)                │   │   │
│  │  │  ├── hubDataStream (BehaviorSubject)                │   │   │
│  │  │  ├── activeHubStream (BehaviorSubject)              │   │   │
│  │  │  ├── primaryHubStream (BehaviorSubject)             │   │   │
│  │  │  ├── hubAddedStream (StreamController)             │   │   │
│  │  │  └── hubRemovedStream (StreamController)            │   │   │
│  │  └─────────────────────────────────────────────────────┘   │   │
│  │                                                              │   │
│  │  ┌─────────────────────────────────────────────────────┐   │   │
│  │  │  Supporting Services                                 │   │   │
│  │  │  ├── AnalyticsRecordingService (per-second logs)    │   │   │
│  │  │  ├── UsageHistoryService (live calculations)        │   │   │
│  │  │  ├── DataCleanupService (retention management)      │   │   │
│  │  │  ├── ThemeNotifier (app theme)                      │   │   │
│  │  │  ├── DueDateProvider (billing settings)             │   │   │
│  │  │  ├── PriceProvider (energy rates)                   │   │   │
│  │  │  └── NotificationProvider (alerts)                  │   │   │
│  │  └─────────────────────────────────────────────────────┘   │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │                 User Interface Screens                      │   │
│  │                                                              │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │   │
│  │  │  Devices Tab │  │   Analytics  │  │    History   │     │   │
│  │  │ (explore.dart)│  │(analytics.dart)│ (history.dart)│     │   │
│  │  │              │  │              │  │              │     │   │
│  │  │ - Hub list   │  │ - Charts     │  │ - Usage table│     │   │
│  │  │ - Plug list  │  │ - Time range │  │ - Export     │     │   │
│  │  │ - SSR toggle │  │ - Trends     │  │ - Filter     │     │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘     │   │
│  │                                                              │   │
│  │  ┌──────────────┐  ┌──────────────┐                        │   │
│  │  │   Overview   │  │   Settings   │                        │   │
│  │  │(energy_      │  │              │                        │   │
│  │  │overview_     │  │ - Theme      │                        │   │
│  │  │screen.dart)  │  │ - Pricing    │                        │   │
│  │  │              │  │ - Due date   │                        │   │
│  │  │ - Dashboard  │  │ - Account    │                        │   │
│  │  │ - Calculator │  │              │                        │   │
│  │  └──────────────┘  └──────────────┘                        │   │
│  └────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Energy Data Collection Flow

```
START: Smart Plug Measures Energy
         │
         ▼
┌─────────────────────────────┐
│  Smart Plug Sensors Read:   │
│  - Voltage (V)              │
│  - Current (A)              │
│  - Power (W = V × A)        │
│  - Energy (kWh cumulative)  │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│  Data Sent to Central Hub   │
│  (Every 1 second)            │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  Central Hub Aggregates All Plugs:      │
│  - total_power = Σ(all plug power)      │
│  - total_voltage = avg(plug voltages)   │
│  - total_current = Σ(all plug currents) │
│  - total_energy = Σ(all plug energy)    │
└──────────┬──────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────────┐
│  Hub Uploads to Firebase RTDB:             │
│                                             │
│  Path: users/espthesisbmn/hubs/            │
│        {serialNumber}/aggregations/        │
│        per_second/data/{timestamp}         │
│                                             │
│  Data: {                                   │
│    timestamp: milliseconds,                │
│    total_power: W,                         │
│    total_voltage: V,                       │
│    total_current: A,                       │
│    total_energy: kWh                       │
│  }                                          │
└────────────┬───────────────────────────────┘
             │
             ▼
┌───────────────────────────────────────────┐
│  ALSO: Update Individual Plug Data        │
│                                            │
│  Path: users/espthesisbmn/hubs/           │
│        {serialNumber}/plugs/{plugId}      │
│                                            │
│  Data: {                                  │
│    name: string,                          │
│    power: W,                              │
│    voltage: V,                            │
│    current: A,                            │
│    energy: kWh,                           │
│    ssr_state: boolean                     │
│  }                                         │
└────────────┬──────────────────────────────┘
             │
             ▼
┌───────────────────────────────────────────┐
│  Data Retention Policy Triggered:         │
│                                            │
│  - DataCleanupService runs every 5 min    │
│  - Deletes per_second data older than     │
│    2 minutes                               │
│  - Keeps aggregated data (hourly/daily/   │
│    weekly/monthly) permanently            │
└───────────────────────────────────────────┘
             │
             ▼
          END
```

---

## 3. Real-Time Data Synchronization Flow

```
START: App Launch / User Login
         │
         ▼
┌─────────────────────────────────────┐
│  Authentication Flow                 │
│  - Firebase Auth                     │
│  - Get userId                        │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  Initialize RealtimeDbService           │
│  - Create stream controllers            │
│  - Setup BehaviorSubjects               │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  Query User's Hubs from Firebase        │
│                                          │
│  Query: users/espthesisbmn/hubs/        │
│  Filter: ownerId == currentUserId       │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  For Each Hub: Start Listeners          │
│  startListening(serialNumber)           │
└──────────┬──────────────────────────────┘
           │
           ├─────────────────────────────────────┐
           │                                     │
           ▼                                     ▼
┌──────────────────────────┐    ┌────────────────────────────┐
│  Listen to SSR State     │    │  Listen to Plug Changes    │
│                          │    │                            │
│  Path: hubs/{serial}/    │    │  Path: hubs/{serial}/      │
│        ssr_state         │    │        plugs/              │
│                          │    │                            │
│  On Change:              │    │  On Child Added:           │
│  - Emit 'hub_state'      │    │  - Emit 'plug_added'       │
│    event to stream       │    │                            │
└──────────┬───────────────┘    │  On Child Changed:         │
           │                    │  - Emit 'plug_changed'     │
           │                    │                            │
           │                    │  On Child Removed:         │
           │                    │  - Emit 'plug_removed'     │
           │                    └────────────┬───────────────┘
           │                                 │
           └─────────────┬───────────────────┘
                         │
                         ▼
┌───────────────────────────────────────────────┐
│  Hub Data Stream Broadcasts Events:           │
│                                                │
│  _hubDataController.add({                     │
│    'type': 'hub_state' | 'plug_added' |       │
│            'plug_changed' | 'plug_removed',   │
│    'serialNumber': string,                    │
│    'data': event_data                         │
│  })                                            │
└──────────┬────────────────────────────────────┘
           │
           ├──────────────┬──────────────┬──────────────┐
           │              │              │              │
           ▼              ▼              ▼              ▼
┌─────────────┐  ┌──────────────┐  ┌─────────┐  ┌──────────┐
│ DevicesTab  │  │  Analytics   │  │ Overview│  │ History  │
│             │  │   Screen     │  │ Screen  │  │ Screen   │
│ Updates:    │  │              │  │         │  │          │
│ - Hub list  │  │ Updates:     │  │ Updates:│  │ Updates: │
│ - Plug list │  │ - Charts     │  │ - Metrics│ │ - Table  │
│ - Status    │  │ - Real-time  │  │ - Gauges│  │ - Stats  │
│   indicators│  │   graphs     │  │         │  │          │
└─────────────┘  └──────────────┘  └─────────┘  └──────────┘
           │              │              │              │
           └──────────────┴──────────────┴──────────────┘
                         │
                         ▼
          UI Updates Automatically
          (StreamBuilder/Provider)
                         │
                         ▼
                       END
```

---

## 4. Analytics Recording Flow

```
START: User Opens App / Analytics Screen
         │
         ▼
┌──────────────────────────────────────┐
│  AnalyticsRecordingService.start()   │
│  - Initialize Timer (1 second)       │
│  - Set recording = true              │
└──────────┬───────────────────────────┘
           │
           ▼
┌──────────────────────────────────────┐
│  Timer Ticks Every 1 Second          │
└──────────┬───────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  Query Current Hub Data:                 │
│  - Get primaryHub serial number          │
│  - Read plugs data                       │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  Calculate Aggregated Metrics:          │
│                                          │
│  total_power = 0                         │
│  total_voltage = 0                       │
│  total_current = 0                       │
│  total_energy = 0                        │
│  plug_count = 0                          │
│                                          │
│  For each plug:                          │
│    total_power += plug.power             │
│    total_voltage += plug.voltage         │
│    total_current += plug.current         │
│    total_energy += plug.energy           │
│    plug_count++                          │
│                                          │
│  avg_voltage = total_voltage/plug_count │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  Create Snapshot Object:                 │
│                                          │
│  {                                       │
│    timestamp: DateTime.now().            │
│               millisecondsSinceEpoch,    │
│    total_power: double,                  │
│    total_voltage: double,                │
│    total_current: double,                │
│    total_energy: double                  │
│  }                                       │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  Write to Firebase RTDB:                 │
│                                          │
│  Path: users/espthesisbmn/hubs/         │
│        {serialNumber}/aggregations/     │
│        per_second/data/{timestamp}      │
│                                          │
│  Method: set(snapshot)                  │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  Automatic Aggregation Calculation:      │
│  (Triggered by Firebase functions or     │
│   scheduled jobs - inferred)             │
│                                          │
│  - Calculate hourly stats from          │
│    per_second data                       │
│  - Calculate daily stats from hourly    │
│  - Calculate weekly stats from daily    │
│  - Calculate monthly stats from daily   │
│                                          │
│  Stats include:                          │
│  - average_power                         │
│  - min_power                             │
│  - max_power                             │
│  - total_energy                          │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  Wait 1 Second                           │
└──────────┬──────────────────────────────┘
           │
           ▼
      ┌─────────────┐
      │ Is recording│
      │  = true?    │
      └─────┬───────┘
            │
      Yes ──┴── No
       │         │
       │         ▼
       │    Stop Timer
       │         │
       │         ▼
       │       END
       │
       └──> Loop back to "Timer Ticks Every 1 Second"


PARALLEL PROCESS:
┌─────────────────────────────────────────┐
│  DataCleanupService                      │
│  (Runs every 5 minutes)                  │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  Calculate Cutoff Time:                  │
│  cutoff = now - 2 minutes                │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  Query per_second/data                   │
│  WHERE timestamp < cutoff                │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  Delete Old Entries                      │
│  (Keep only last 2 minutes)              │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  Wait 5 Minutes                          │
└──────────┬──────────────────────────────┘
           │
           └──> Loop back to "Calculate Cutoff Time"
```

---

## 5. User Interface Data Flow

```
START: User Opens Devices Tab (explore.dart)
         │
         ▼
┌────────────────────────────────────────┐
│  initState() Lifecycle                  │
│  - Initialize state variables           │
│  - _devices = []                        │
│  - _hubs = {}                           │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  _initializeDevicesAndHubs()            │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Get RealtimeDbService from Provider   │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Query All Hubs for Current User        │
│  realtimeDb.getAllHubsForCurrentUser()  │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Store Hubs in _hubs Map                │
│  _hubs[serialNumber] = hubData          │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  For Each Hub:                          │
│  - Get plugs data                       │
│  - Create ConnectedDevice objects       │
│  - Add to _devices list                 │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Subscribe to Hub Data Stream           │
│  realtimeDb.hubDataStream.listen()      │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Start Listeners for Each Hub           │
│  realtimeDb.startListening(serial)      │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Auto-activate First Hub for Analytics  │
│  realtimeDb.activateHub(firstSerial)    │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Wait 800ms for Stream Initialization   │
│  (Critical for SSR state sync)          │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Re-fetch SSR States to Sync            │
│  (Handles missed events during init)    │
│                                         │
│  For each hub:                          │
│    realtimeDb.getHubSsrStateStream()    │
│      .first.then((state) {              │
│        Update _hubs[serial] state       │
│        Update UI (setState)             │
│      })                                 │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────────────┐
│  Listen to Real-Time Events:                   │
│                                                 │
│  EVENT: 'hub_state'                            │
│  ├─> Update hub SSR state in _hubs             │
│  └─> setState() to rebuild UI                  │
│                                                 │
│  EVENT: 'plug_added'                           │
│  ├─> Create new ConnectedDevice                │
│  ├─> Add to _devices list                      │
│  └─> setState() to rebuild UI                  │
│                                                 │
│  EVENT: 'plug_changed'                         │
│  ├─> Find device in _devices list              │
│  ├─> Update power/voltage/current/energy       │
│  └─> setState() to rebuild UI                  │
│                                                 │
│  EVENT: 'plug_removed'                         │
│  ├─> Find and remove from _devices list        │
│  └─> setState() to rebuild UI                  │
└──────────┬─────────────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Build UI Widget Tree                   │
│                                         │
│  StreamBuilder(                         │
│    stream: realtimeDb.activeHubStream,  │
│    builder: (context, snapshot) {       │
│      return Column(                     │
│        children: [                      │
│          HubList(_hubs),                │
│          DeviceGrid(_devices)           │
│        ]                                │
│      )                                  │
│    }                                    │
│  )                                      │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  User Interaction: Toggle SSR           │
│  onTap() -> toggleHubSsr()              │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Call RealtimeDbService:                │
│  realtimeDb.setHubSsrState(             │
│    serialNumber,                        │
│    newState                             │
│  )                                      │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Update Firebase RTDB:                  │
│  hubs/{serial}/ssr_state = newState     │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Firebase Triggers Listener             │
│  (from Step: "Listen to SSR State")     │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Hub Data Stream Emits 'hub_state'      │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  UI Receives Event and Updates          │
│  setState() rebuilds widget             │
└──────────┬─────────────────────────────┘
           │
           ▼
      UI Shows Updated State
      (SSR ON/OFF indicator changes)
           │
           ▼
         END


PARALLEL FLOW - Analytics Screen:
┌────────────────────────────────────────┐
│  User Opens Analytics Screen            │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Select Time Range (Hourly/Daily/      │
│  Weekly/Monthly)                        │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Query Aggregation Data:                │
│                                         │
│  realtimeDb.getAggregationData(         │
│    serialNumber,                        │
│    'hourly' | 'daily' | 'weekly' |      │
│    'monthly',                           │
│    dateKey                              │
│  )                                      │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Receive Map<String, dynamic>:          │
│  {                                      │
│    'average_power': double,             │
│    'min_power': double,                 │
│    'max_power': double,                 │
│    'total_energy': double               │
│  }                                      │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Render Chart:                          │
│  - Line chart for trends                │
│  - Bar chart for comparisons            │
│  - Show power/energy over time          │
└──────────┬─────────────────────────────┘
           │
           ▼
         END
```

---

## 6. Hub Control Flow

```
START: User Wants to Control Hub (Turn ON/OFF)
         │
         ▼
┌────────────────────────────────────────┐
│  User Taps SSR Toggle Switch in UI     │
│  (Devices Tab)                          │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Read Current SSR State:                │
│  currentState = _hubs[serial]['ssr_    │
│                 state']                 │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Calculate New State:                   │
│  newState = !currentState               │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Show Loading Indicator (Optional)      │
│  setState(() { isLoading = true })      │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Call Service Method:                   │
│  realtimeDbService.setHubSsrState(      │
│    serialNumber: serial,                │
│    state: newState                      │
│  )                                      │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  RealtimeDbService Validates:           │
│  - Check user authentication            │
│  - Verify hub ownership (security)      │
└──────────┬─────────────────────────────┘
           │
           ▼
      ┌─────────────┐
      │ Authorized? │
      └─────┬───────┘
            │
      No ───┴─── Yes
       │          │
       ▼          ▼
┌─────────────┐  ┌────────────────────────────┐
│ Show Error  │  │ Update Firebase RTDB:      │
│ Message     │  │                            │
│ "Access     │  │ Reference path:            │
│  Denied"    │  │ users/espthesisbmn/hubs/   │
└─────────────┘  │ {serialNumber}/ssr_state   │
       │         │                            │
       │         │ dbRef.set(newState)        │
       │         └────────────┬───────────────┘
       │                      │
       │                      ▼
       │         ┌─────────────────────────────┐
       │         │ Firebase RTDB Writes Value  │
       │         └────────────┬────────────────┘
       │                      │
       │                      ▼
       │         ┌─────────────────────────────┐
       │         │ Firebase Triggers Listener  │
       │         │ (SSR State Listener)        │
       │         └────────────┬────────────────┘
       │                      │
       │                      ▼
       │         ┌─────────────────────────────┐
       │         │ Listener Receives New State │
       │         └────────────┬────────────────┘
       │                      │
       │                      ▼
       │         ┌─────────────────────────────┐
       │         │ Emit Event to hubDataStream:│
       │         │ {                           │
       │         │   type: 'hub_state',        │
       │         │   serialNumber: serial,     │
       │         │   data: { ssr_state: state }│
       │         │ }                           │
       │         └────────────┬────────────────┘
       │                      │
       │                      ▼
       │         ┌─────────────────────────────┐
       │         │ All Subscribed UI Components│
       │         │ Receive Event               │
       │         └────────────┬────────────────┘
       │                      │
       │                      ├─────────────────────────┐
       │                      │                         │
       │                      ▼                         ▼
       │         ┌─────────────────────┐  ┌──────────────────────┐
       │         │ Devices Tab Updates │  │ Overview Tab Updates │
       │         │ SSR Indicator       │  │ Hub Status Display   │
       │         └────────────┬────────┘  └──────────┬───────────┘
       │                      │                      │
       │                      ▼                      ▼
       │         ┌─────────────────────────────────────┐
       │         │ setState() Rebuilds Widget Tree     │
       │         │ - Toggle shows new position         │
       │         │ - Icon changes (ON/OFF)             │
       │         │ - Color changes (green/red)         │
       │         └────────────┬────────────────────────┘
       │                      │
       │                      ▼
       │         ┌─────────────────────────────────────┐
       │         │ Hide Loading Indicator              │
       │         │ setState(() { isLoading = false })  │
       │         └────────────┬────────────────────────┘
       │                      │
       └──────────────────────┴─> END


PARALLEL PROCESS - Physical Device Control:
┌─────────────────────────────────────────┐
│ Central Hub Monitors Firebase RTDB      │
│ (Hardware-side listener)                │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ Hub Detects ssr_state Change            │
│ in Firebase                             │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ Hub Reads New State Value               │
│ newState = Firebase.read('ssr_state')   │
└──────────┬──────────────────────────────┘
           │
           ▼
      ┌─────────────┐
      │ newState =  │
      │    true?    │
      └─────┬───────┘
            │
      Yes ──┴── No
       │         │
       ▼         ▼
┌─────────────┐ ┌─────────────────┐
│ Activate    │ │ Deactivate      │
│ Solid State │ │ Solid State     │
│ Relay       │ │ Relay           │
│             │ │                 │
│ - Close     │ │ - Open circuit  │
│   circuit   │ │ - Cut power to  │
│ - Supply    │ │   all smart     │
│   power to  │ │   plugs         │
│   all smart │ │                 │
│   plugs     │ │                 │
└─────┬───────┘ └─────┬───────────┘
      │               │
      └───────┬───────┘
              │
              ▼
┌──────────────────────────────────────┐
│ Smart Plugs Respond:                 │
│ - If ON: Start monitoring & sending  │
│          data                        │
│ - If OFF: Stop monitoring, send last │
│           reading                    │
└──────────────────────────────────────┘
              │
              ▼
            END
```

---

## 7. Data Cleanup & Retention Flow

```
START: App Initialization / Background Service
         │
         ▼
┌──────────────────────────────────────────┐
│  DataCleanupService.initialize()         │
│  - Create Timer (periodic)               │
│  - Interval: 5 minutes                   │
└──────────┬───────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────┐
│  Timer Triggers Every 5 Minutes          │
└──────────┬───────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────┐
│  Calculate Retention Cutoff:             │
│  cutoffTime = DateTime.now()             │
│               .subtract(Duration(        │
│                 minutes: 2))             │
│               .millisecondsSinceEpoch    │
└──────────┬───────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────┐
│  Get All Hubs for Current User           │
│  realtimeDb.getAllHubsForCurrentUser()   │
└──────────┬───────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────┐
│  FOR EACH Hub:                           │
│  serialNumber = hub.key                  │
└──────────┬───────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────┐
│  Build Database Reference:               │
│  path = users/espthesisbmn/hubs/         │
│         {serialNumber}/aggregations/     │
│         per_second/data                  │
└──────────┬───────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────┐
│  Query Old Data:                         │
│  dbRef.orderByChild('timestamp')         │
│       .endAt(cutoffTime)                 │
│       .once()                            │
└──────────┬───────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────┐
│  Receive DataSnapshot                    │
│  snapshot.value = {                      │
│    {timestamp1}: {data},                 │
│    {timestamp2}: {data},                 │
│    ...                                   │
│  }                                       │
└──────────┬───────────────────────────────┘
           │
           ▼
      ┌─────────────┐
      │ Has old     │
      │ data?       │
      └─────┬───────┘
            │
      No ───┴─── Yes
       │          │
       │          ▼
       │    ┌──────────────────────────────┐
       │    │ FOR EACH Old Entry:          │
       │    │ timestampKey = entry.key     │
       │    └──────────┬───────────────────┘
       │               │
       │               ▼
       │    ┌──────────────────────────────┐
       │    │ Delete Entry:                │
       │    │ dbRef.child(timestampKey)    │
       │    │      .remove()               │
       │    └──────────┬───────────────────┘
       │               │
       │               ▼
       │    ┌──────────────────────────────┐
       │    │ Log Deletion:                │
       │    │ print("Deleted old data:     │
       │    │        $timestampKey")       │
       │    └──────────┬───────────────────┘
       │               │
       │               └──> NEXT Entry
       │                        │
       │                        │ (All deleted)
       │                        ▼
       │    ┌──────────────────────────────┐
       │    │ Log Summary:                 │
       │    │ print("Cleanup complete for  │
       │    │        $serialNumber")       │
       │    └──────────┬───────────────────┘
       │               │
       └───────────────┴─> NEXT Hub
                            │
                            │ (All hubs processed)
                            ▼
┌──────────────────────────────────────────┐
│  Update Cleanup Statistics:              │
│  - Total entries deleted                 │
│  - Total space freed                     │
│  - Last cleanup timestamp                │
└──────────┬───────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────┐
│  Wait 5 Minutes                          │
└──────────┬───────────────────────────────┘
           │
           └──> Loop back to "Timer Triggers Every 5 Minutes"


RETENTION POLICY SUMMARY:
┌─────────────────────────────────────────────────────────┐
│  Data Type          │ Retention Period │ Purpose        │
├─────────────────────────────────────────────────────────┤
│  per_second/data    │ 2 minutes        │ Real-time view │
│  hourly/            │ Permanent        │ Analytics      │
│  daily/             │ Permanent        │ Analytics      │
│  weekly/            │ Permanent        │ Analytics      │
│  monthly/           │ Permanent        │ Analytics      │
│  plugs/{plugId}     │ Permanent        │ Current status │
│  ssr_state          │ Permanent        │ Hub control    │
└─────────────────────────────────────────────────────────┘
```

---

## 8. Authentication & Access Control Flow

```
START: User Opens App
         │
         ▼
┌────────────────────────────────────────┐
│  Check Firebase Auth State             │
│  FirebaseAuth.instance.currentUser     │
└──────────┬─────────────────────────────┘
           │
           ▼
      ┌─────────────┐
      │ User logged │
      │   in?       │
      └─────┬───────┘
            │
      No ───┴─── Yes
       │          │
       ▼          ▼
┌─────────────┐  ┌────────────────────────┐
│ Redirect to │  │ Get User ID (uid)      │
│ Login Screen│  │ userId = currentUser   │
└─────────────┘  │        .uid            │
       │         └────────────┬───────────┘
       │                      │
       ▼                      ▼
┌─────────────────────────┐  ┌──────────────────────────┐
│ User Enters Credentials │  │ Load User Profile from   │
│ - Email                 │  │ Firestore:               │
│ - Password              │  │                          │
└─────────┬───────────────┘  │ users/{userId}/          │
          │                  │ - email                  │
          ▼                  │ - dueDate                │
┌─────────────────────────┐  │ - pricePerKwh            │
│ Firebase Auth Login:    │  └──────────┬───────────────┘
│ signInWithEmailAnd      │             │
│ Password()              │             │
└─────────┬───────────────┘             │
          │                             │
          ▼                             │
      ┌─────────────┐                  │
      │ Login       │                  │
      │ Success?    │                  │
      └─────┬───────┘                  │
            │                          │
      No ───┴─── Yes                   │
       │          │                    │
       ▼          └────────────────────┘
┌─────────────┐             │
│ Show Error  │             │
│ Message     │             ▼
└─────────────┘  ┌────────────────────────────────┐
       │         │ Initialize Providers:           │
       │         │ - RealtimeDbService             │
       │         │ - ThemeNotifier                 │
       │         │ - DueDateProvider               │
       │         │ - PriceProvider                 │
       │         │ - NotificationProvider          │
       │         └────────────┬───────────────────┘
       │                      │
       │                      ▼
       │         ┌────────────────────────────────┐
       │         │ Query User's Hubs:             │
       │         │                                │
       │         │ Database path:                 │
       │         │ users/espthesisbmn/hubs/       │
       │         │                                │
       │         │ Filter:                        │
       │         │ WHERE ownerId == userId        │
       │         └────────────┬───────────────────┘
       │                      │
       │                      ▼
       │         ┌────────────────────────────────┐
       │         │ Firebase RTDB Security Rules   │
       │         │ Check:                         │
       │         │                                │
       │         │ ".read": "auth != null &&      │
       │         │           data.child('ownerId')│
       │         │           .val() == auth.uid"  │
       │         └────────────┬───────────────────┘
       │                      │
       │                      ▼
       │              ┌───────────────┐
       │              │ Authorized?   │
       │              └───────┬───────┘
       │                      │
       │               No ────┴──── Yes
       │                │            │
       │                ▼            ▼
       │    ┌──────────────────┐  ┌──────────────────────┐
       │    │ Deny Access      │  │ Return Hub Data:     │
       │    │ Return null/[]   │  │ {                    │
       │    └──────────────────┘  │   serialNumber: {    │
       │                          │     assigned: bool,  │
       │                          │     ownerId: uid,    │
       │                          │     nickname: str,   │
       │                          │     ssr_state: bool, │
       │                          │     plugs: {...}     │
       │                          │   }                  │
       │                          │ }                    │
       │                          └──────────┬───────────┘
       │                                     │
       │                                     ▼
       │                          ┌────────────────────────┐
       │                          │ Store Hubs in App State│
       │                          │ Render Home Screen     │
       │                          └────────────┬───────────┘
       │                                       │
       └───────────────────────────────────────┘
                                               │
                                               ▼
                                    APP READY FOR USE


HUB CONTROL AUTHORIZATION:
┌────────────────────────────────────────────────────────┐
│  User Attempts Hub Control (SSR Toggle)                │
└──────────┬─────────────────────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────────────────────┐
│  Request Write to Firebase RTDB:                       │
│  hubs/{serialNumber}/ssr_state = newState              │
└──────────┬─────────────────────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────────────────────┐
│  Firebase RTDB Security Rules Check:                   │
│                                                         │
│  ".write": "auth != null &&                            │
│             data.parent().child('ownerId')             │
│             .val() == auth.uid"                        │
└──────────┬─────────────────────────────────────────────┘
           │
           ▼
      ┌─────────────┐
      │ User is     │
      │ owner?      │
      └─────┬───────┘
            │
      No ───┴─── Yes
       │          │
       ▼          ▼
┌─────────────┐  ┌────────────────────────┐
│ DENY Write  │  │ ALLOW Write            │
│ Return error│  │ Update ssr_state       │
└─────────────┘  └────────────────────────┘


ADMIN ACCESS CONTROL (Firestore):
┌────────────────────────────────────────────────────────┐
│  Admin Accesses User Data                              │
└──────────┬─────────────────────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────────────────────┐
│  Firestore Security Rules Check:                       │
│                                                         │
│  function isAdmin() {                                  │
│    return request.auth != null &&                      │
│           request.auth.token.admin == true;            │
│  }                                                      │
│                                                         │
│  function isAdminEmail() {                             │
│    return request.auth.token.email in [                │
│      'espthesisbmn@gmail.com',                         │
│      'smartenergymeter11@gmail.com'                    │
│    ];                                                   │
│  }                                                      │
│                                                         │
│  match /users/{userId} {                               │
│    allow read, write: if isOwner(userId) ||            │
│                          isAdmin() ||                  │
│                          isAdminEmail();               │
│  }                                                      │
└──────────┬─────────────────────────────────────────────┘
           │
           ▼
      ┌─────────────┐
      │ Is admin or │
      │ owner?      │
      └─────┬───────┘
            │
      No ───┴─── Yes
       │          │
       ▼          ▼
┌─────────────┐  ┌────────────────────────┐
│ DENY Access │  │ ALLOW Access           │
└─────────────┘  └────────────────────────┘
                            │
                            ▼
                          END
```

---

## 9. Usage Calculation Flow

```
START: User Opens Energy History Screen
         │
         ▼
┌────────────────────────────────────────┐
│  Select Aggregation Level:             │
│  - Hourly                              │
│  - Daily                               │
│  - Weekly                              │
│  - Monthly                             │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Select Hub (Serial Number)            │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  UsageHistoryService.calculateUsage()  │
│  - aggregationType                     │
│  - serialNumber                        │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Build Database Path Based on Type:    │
│                                        │
│  HOURLY:                               │
│  path = aggregations/hourly/           │
│         {YYYY-MM-DD-HH}                │
│                                        │
│  DAILY:                                │
│  path = aggregations/daily/            │
│         {YYYY-MM-DD}                   │
│                                        │
│  WEEKLY:                               │
│  path = aggregations/weekly/           │
│         {YYYY-Www}                     │
│                                        │
│  MONTHLY:                              │
│  path = aggregations/monthly/          │
│         {YYYY-MM}                      │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Query Firebase RTDB:                  │
│  dbRef.once('value')                   │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Receive Snapshot:                     │
│  {                                     │
│    '{dateKey}': {                      │
│      average_power: double,            │
│      min_power: double,                │
│      max_power: double,                │
│      total_energy: double              │
│    }                                   │
│  }                                     │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Parse Data into UsageHistoryEntry     │
│  List:                                 │
│                                        │
│  FOR EACH entry in snapshot:           │
│    UsageHistoryEntry(                  │
│      period: dateKey,                  │
│      averagePower: avg_power,          │
│      minPower: min_power,              │
│      maxPower: max_power,              │
│      totalEnergy: total_energy         │
│    )                                   │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Calculate Additional Metrics:         │
│                                        │
│  FOR EACH entry:                       │
│    - usage = current_reading -         │
│              previous_reading          │
│    - cost = usage × pricePerKwh        │
│    - percentage = (usage /             │
│                    total_usage) × 100  │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Sort Entries by Date:                 │
│  entries.sort((a, b) =>                │
│    a.period.compareTo(b.period))       │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Return List<UsageHistoryEntry>        │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Display in Table:                     │
│  ┌──────┬───────┬─────┬──────┬──────┐ │
│  │Period│ Avg W │Min W│Max W │kWh   │ │
│  ├──────┼───────┼─────┼──────┼──────┤ │
│  │ ...  │  ...  │ ... │ ...  │ ...  │ │
│  └──────┴───────┴─────┴──────┴──────┘ │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  User Can Export to Excel:             │
│  - Generate XLSX file                  │
│  - Include all calculated metrics      │
│  - Download to device                  │
└──────────┬─────────────────────────────┘
           │
           ▼
         END


BILLING CALCULATION:
┌────────────────────────────────────────┐
│  Get Billing Settings from Firestore:  │
│  - dueDate (day of month)              │
│  - pricePerKwh (cost per unit)         │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Calculate Billing Period:             │
│  startDate = previousDueDate           │
│  endDate = currentDueDate              │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Query Daily Aggregations:             │
│  FOR date IN [startDate...endDate]:    │
│    Get daily total_energy              │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Sum Total Energy:                     │
│  billingPeriodUsage = Σ(daily_energy)  │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Calculate Cost:                       │
│  totalCost = billingPeriodUsage ×      │
│              pricePerKwh               │
└──────────┬─────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────┐
│  Display on Overview Screen:           │
│  - Current usage (kWh)                 │
│  - Estimated cost                      │
│  - Days until next billing             │
└────────────────────────────────────────┘
           │
           ▼
         END
```

---

## 10. Complete End-to-End Energy Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    COMPLETE ENERGY FLOW DIAGRAM                      │
└─────────────────────────────────────────────────────────────────────┘

PHASE 1: ENERGY MEASUREMENT
┌───────────────┐
│ Power Source  │ (Grid/Solar)
└───────┬───────┘
        │ Energy flows
        ▼
┌───────────────────┐
│ Household Device  │ (Appliance/Load)
│ - Refrigerator    │
│ - AC Unit         │
│ - TV              │
└────────┬──────────┘
         │ Power consumption
         ▼
┌──────────────────────────┐
│ Smart Plug Sensor        │
│ - Measures Voltage (V)   │
│ - Measures Current (A)   │
│ - Calculates Power (W)   │
│ - Tracks Energy (kWh)    │
│                          │
│ Sample Rate: 1 Hz        │
└────────┬─────────────────┘
         │ Sensor data via serial/WiFi
         ▼

PHASE 2: DATA AGGREGATION AT HUB
┌────────────────────────────────────┐
│ Central Hub (ESP32/IoT Gateway)    │
│ Serial: SP001, SP002, etc.         │
│                                    │
│ Receives from multiple smart plugs:│
│ ┌────────────────────────────────┐ │
│ │ Plug 1: 50W, 230V, 0.22A       │ │
│ │ Plug 2: 100W, 230V, 0.43A      │ │
│ │ Plug 3: 75W, 230V, 0.33A       │ │
│ └────────────────────────────────┘ │
│                                    │
│ Aggregation Logic:                 │
│ total_power = 50 + 100 + 75 = 225W │
│ total_current = 0.22+0.43+0.33=0.98A│
│ avg_voltage = (230+230+230)/3=230V │
│ total_energy = Σ(plug energies)    │
│                                    │
│ SSR State: ON/OFF (controls power) │
└────────┬───────────────────────────┘
         │ WiFi/Internet
         ▼

PHASE 3: CLOUD STORAGE
┌──────────────────────────────────────────────────┐
│ Firebase Realtime Database                       │
│                                                  │
│ users/espthesisbmn/hubs/SP001/                  │
│ ├── ssr_state: true                             │
│ ├── assigned: true                              │
│ ├── ownerId: "user123"                          │
│ │                                                │
│ ├── plugs/                                      │
│ │   ├── plug1/                                  │
│ │   │   ├── power: 50                           │
│ │   │   ├── voltage: 230                        │
│ │   │   ├── current: 0.22                       │
│ │   │   └── energy: 1.25                        │
│ │   ├── plug2/ {...}                            │
│ │   └── plug3/ {...}                            │
│ │                                                │
│ └── aggregations/                               │
│     ├── per_second/data/1234567890/             │
│     │   ├── timestamp: 1234567890               │
│     │   ├── total_power: 225                    │
│     │   ├── total_voltage: 230                  │
│     │   ├── total_current: 0.98                 │
│     │   └── total_energy: 3.5                   │
│     │                                            │
│     ├── hourly/2025-12-08-14/                   │
│     │   ├── average_power: 220                  │
│     │   ├── min_power: 180                      │
│     │   ├── max_power: 250                      │
│     │   └── total_energy: 0.22                  │
│     │                                            │
│     ├── daily/2025-12-08/                       │
│     │   ├── average_power: 215                  │
│     │   ├── min_power: 150                      │
│     │   ├── max_power: 300                      │
│     │   └── total_energy: 5.16                  │
│     │                                            │
│     ├── weekly/2025-W49/                        │
│     └── monthly/2025-12/                        │
└──────────┬───────────────────────────────────────┘
           │ Real-time sync
           ▼

PHASE 4: APPLICATION LAYER
┌──────────────────────────────────────────────────┐
│ Flutter App (Android/iOS/Web)                    │
│                                                  │
│ ┌──────────────────────────────────────────────┐ │
│ │ RealtimeDbService (State Manager)            │ │
│ │                                              │ │
│ │ Streams (RxDart BehaviorSubjects):           │ │
│ │ ┌──────────────────────────────────────────┐ │ │
│ │ │ hubDataStream                            │ │ │
│ │ │ - Broadcasts: hub_state, plug_changed    │ │ │
│ │ │              plug_added, plug_removed    │ │ │
│ │ └──────────────────────────────────────────┘ │ │
│ │                                              │ │
│ │ ┌──────────────────────────────────────────┐ │ │
│ │ │ activeHubStream                          │ │ │
│ │ │ - Tracks: [SP001, SP002]                 │ │ │
│ │ └──────────────────────────────────────────┘ │ │
│ │                                              │ │
│ │ ┌──────────────────────────────────────────┐ │ │
│ │ │ primaryHubStream                         │ │ │
│ │ │ - Selected hub for analytics: SP001      │ │ │
│ │ └──────────────────────────────────────────┘ │ │
│ └──────────────────────────────────────────────┘ │
│                                                  │
│ ┌──────────────────────────────────────────────┐ │
│ │ Supporting Services                          │ │
│ │ ┌──────────────────────────────────────────┐ │ │
│ │ │ AnalyticsRecordingService                │ │ │
│ │ │ - Records every 1 second                 │ │ │
│ │ │ - Writes to per_second/data              │ │ │
│ │ └──────────────────────────────────────────┘ │ │
│ │                                              │ │
│ │ ┌──────────────────────────────────────────┐ │ │
│ │ │ DataCleanupService                       │ │ │
│ │ │ - Runs every 5 minutes                   │ │ │
│ │ │ - Deletes data older than 2 minutes      │ │ │
│ │ └──────────────────────────────────────────┘ │ │
│ │                                              │ │
│ │ ┌──────────────────────────────────────────┐ │ │
│ │ │ UsageHistoryService                      │ │ │
│ │ │ - Calculates usage from aggregations     │ │ │
│ │ │ - No storage, live calculations          │ │ │
│ │ └──────────────────────────────────────────┘ │ │
│ └──────────────────────────────────────────────┘ │
└──────────┬───────────────────────────────────────┘
           │
           │ Data flows to UI
           │
    ┌──────┴───────┬──────────┬──────────┐
    │              │          │          │
    ▼              ▼          ▼          ▼

PHASE 5: USER INTERFACE
┌─────────────┐ ┌───────────┐ ┌──────────┐ ┌─────────┐
│ Devices Tab │ │ Analytics │ │ Overview │ │ History │
└─────────────┘ └───────────┘ └──────────┘ └─────────┘

DEVICES TAB DISPLAY:
┌───────────────────────────────────────┐
│ Central Hubs                          │
│ ┌───────────────────────────────────┐ │
│ │ SP001 - Living Room               │ │
│ │ Status: ON  │ Power: 225W         │ │
│ │ [Toggle SSR]                      │ │
│ └───────────────────────────────────┘ │
│                                       │
│ Connected Devices                     │
│ ┌───────────────────────────────────┐ │
│ │ Refrigerator    50W   1.25 kWh    │ │
│ │ AC Unit        100W   2.10 kWh    │ │
│ │ TV              75W   1.15 kWh    │ │
│ └───────────────────────────────────┘ │
└───────────────────────────────────────┘

ANALYTICS DISPLAY:
┌───────────────────────────────────────┐
│ Time Range: Hourly ▼   Hub: SP001 ▼  │
│                                       │
│ Power Consumption Trend               │
│   W                                   │
│ 300┤         ╭─╮                      │
│ 250┤      ╭──╯ ╰─╮                    │
│ 200┤   ╭──╯      ╰──╮                 │
│ 150┤╭──╯            ╰─╮               │
│ 100┤╯                 └──             │
│    └────────────────────────          │
│     12  14  16  18  20  22  Hour      │
│                                       │
│ Statistics:                           │
│ Avg Power: 220W                       │
│ Min Power: 150W                       │
│ Max Power: 300W                       │
│ Total Energy: 0.22 kWh                │
└───────────────────────────────────────┘

OVERVIEW DISPLAY:
┌───────────────────────────────────────┐
│ Current Consumption                   │
│ ┌───────────────┐  ┌───────────────┐ │
│ │    225 W      │  │    230 V      │ │
│ │    Power      │  │   Voltage     │ │
│ └───────────────┘  └───────────────┘ │
│                                       │
│ Monthly Usage                         │
│ ┌───────────────────────────────────┐ │
│ │ 154.8 kWh                         │ │
│ │ Estimated Cost: $23.22            │ │
│ │ Days until due date: 23           │ │
│ └───────────────────────────────────┘ │
│                                       │
│ Energy Calculator                     │
│ ┌───────────────────────────────────┐ │
│ │ Wattage: 100W                     │ │
│ │ Hours/day: 8                      │ │
│ │ Days: 30                          │ │
│ │ ───────────────────               │ │
│ │ Monthly Cost: $3.60               │ │
│ └───────────────────────────────────┘ │
└───────────────────────────────────────┘

HISTORY DISPLAY:
┌───────────────────────────────────────────────┐
│ Type: Daily ▼   Hub: SP001 ▼   [Export Excel]│
│                                               │
│ ┌─────────────────────────────────────────┐  │
│ │ Period    │Avg W│Min W│Max W│  kWh    │  │
│ ├───────────┼─────┼─────┼─────┼─────────┤  │
│ │2025-12-01 │ 215 │ 150 │ 300 │  5.16   │  │
│ │2025-12-02 │ 220 │ 160 │ 310 │  5.28   │  │
│ │2025-12-03 │ 210 │ 155 │ 295 │  5.04   │  │
│ │2025-12-04 │ 225 │ 165 │ 320 │  5.40   │  │
│ │...        │ ... │ ... │ ... │  ...    │  │
│ └─────────────────────────────────────────┘  │
└───────────────────────────────────────────────┘

PHASE 6: USER CONTROL FEEDBACK LOOP
┌───────────────────────────────────────┐
│ User toggles SSR in Devices Tab       │
└──────────┬────────────────────────────┘
           │
           ▼
┌───────────────────────────────────────┐
│ App calls setHubSsrState(SP001, OFF)  │
└──────────┬────────────────────────────┘
           │
           ▼
┌───────────────────────────────────────┐
│ Firebase RTDB updates                 │
│ hubs/SP001/ssr_state = false          │
└──────────┬────────────────────────────┘
           │
           ├───────────────────────┐
           │                       │
           ▼                       ▼
┌─────────────────┐  ┌──────────────────────┐
│ Central Hub     │  │ App receives event   │
│ receives update │  │ via listener         │
│                 │  │ 'hub_state' emitted  │
│ Sets SSR relay  │  └──────────┬───────────┘
│ to OPEN         │             │
│                 │             ▼
│ Cuts power to   │  ┌──────────────────────┐
│ all smart plugs │  │ UI updates:          │
└─────────────────┘  │ - SSR indicator: OFF │
                     │ - Power readings: 0W │
                     │ - Status: Inactive   │
                     └──────────────────────┘

PHASE 7: ANALYTICS & REPORTING
┌───────────────────────────────────────┐
│ Background Processes                  │
│                                       │
│ Every 1 second:                       │
│ - Record per_second snapshot          │
│                                       │
│ Every 5 minutes:                      │
│ - Clean up old per_second data        │
│                                       │
│ Every hour (scheduled):               │
│ - Calculate hourly aggregations       │
│ - Stats: avg, min, max, total         │
│                                       │
│ Every day (scheduled):                │
│ - Calculate daily aggregations        │
│ - Update weekly/monthly aggregations  │
│                                       │
│ On billing due date:                  │
│ - Calculate total usage for period    │
│ - Generate billing notification       │
│ - Reset period counter                │
└───────────────────────────────────────┘

PHASE 8: DATA LIFECYCLE SUMMARY
┌─────────────────────────────────────────────────────┐
│ Data Type        │ Frequency  │ Retention           │
├─────────────────────────────────────────────────────┤
│ Sensor reading   │ 1/second   │ N/A (processed)     │
│ per_second/data  │ 1/second   │ 2 minutes           │
│ hourly/          │ 1/hour     │ Permanent           │
│ daily/           │ 1/day      │ Permanent           │
│ weekly/          │ 1/week     │ Permanent           │
│ monthly/         │ 1/month    │ Permanent           │
│ plugs/{id}       │ Real-time  │ Permanent (current) │
│ ssr_state        │ On-change  │ Permanent (current) │
└─────────────────────────────────────────────────────┘

END OF COMPLETE ENERGY FLOW
```

---

## Summary

This document provides comprehensive flowcharts covering:

1. **System Architecture**: Overall structure and components
2. **Data Collection**: How energy is measured and sent to the cloud
3. **Real-Time Sync**: Stream-based data flow to UI
4. **Analytics Recording**: Per-second snapshot recording
5. **UI Data Flow**: How screens receive and display data
6. **Hub Control**: SSR toggle and device control
7. **Data Cleanup**: Retention policy and cleanup process
8. **Authentication**: Security and access control
9. **Usage Calculation**: How energy usage is computed
10. **End-to-End Flow**: Complete journey from sensor to UI

Each flowchart uses ASCII art for clarity and can be easily understood without specialized diagram tools.

---

**Document Version**: 1.0
**Last Updated**: 2025-12-08
**Created For**: Smart Energy System Project
