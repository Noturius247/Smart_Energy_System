# Energy Overview - Daily Usage Changes

## Summary
Modified the Energy Overview screen to display the **latest daily usage data** from Usage History, showing the **difference between past and present daily readings** instead of calculating based on per-second data.

## Changes Made

### 1. Added New Imports
- `../services/usage_history_service.dart`
- `../models/usage_history_entry.dart`

### 2. Updated State Variables
**Before:**
```dart
double _latestDailyTotalEnergy = 0.0;
```

**After:**
```dart
UsageHistoryEntry? _latestDailyUsage;
late UsageHistoryService _usageHistoryService;
```

### 3. Replaced Data Fetching Method

**Old Method:** `_fetchLatestDailyEnergyTotal()`
- Fetched raw daily aggregation data
- Stored cumulative energy reading
- Calculated usage by subtracting from current per-second reading

**New Method:** `_fetchLatestDailyUsage()`
- Uses `UsageHistoryService` to calculate usage
- Fetches the latest daily usage entry (difference already calculated)
- Stores complete `UsageHistoryEntry` with:
  - `timestamp`: When the reading was taken
  - `previousReading`: Yesterday's cumulative energy
  - `currentReading`: Today's cumulative energy
  - `usage`: The calculated difference (what was consumed)

### 4. Updated Daily Usage Card (`_solarProductionCard`)

**Key Changes:**
- **Title:** Changed from "Daily Cost" to "Daily Usage"
- **Data Source:** Now uses `_latestDailyUsage?.usage` instead of calculating from per-second data
- **Tooltip:** Updated to explain the new calculation method
- **Date Display:** Added formatted timestamp showing when the usage was recorded
- **Progress Bar:** Now shows 0.0 when no data available

**Before:**
```dart
final totalEnergy = (recentEnergy - _latestDailyTotalEnergy).clamp(0.0, double.infinity);
```

**After:**
```dart
final totalEnergy = _latestDailyUsage?.usage ?? 0.0;
final dateLabel = _latestDailyUsage != null
    ? _latestDailyUsage!.getFormattedTimestamp()
    : 'No data';
```

### 5. Updated Monthly Estimate Card (`_monthlyCostCard`)

**Key Changes:**
- **Data Source:** Now uses `_latestDailyUsage?.usage` instead of averaging 24h per-second data
- **Calculation:** `monthlyEstimate = dailyUsage × 30 days`
- **Tooltip:** Updated to reflect usage from Usage History

**Before:**
```dart
// Calculate average daily energy from 24h data
final dailyEnergy = data.isNotEmpty
    ? data.map((d) => d.energy).reduce((a, b) => a + b) / data.length
    : 0.0;
```

**After:**
```dart
// Use the latest daily usage from Usage History
// This provides accurate daily consumption based on actual meter readings
final dailyEnergy = _latestDailyUsage?.usage ?? 0.0;
```

**Benefits:**
- More accurate monthly projection based on actual daily consumption
- Consistent with Usage History calculations
- Not affected by incomplete 24h data
- Shows realistic monthly estimate based on yesterday's usage

### 6. Updated All Method Calls
- `initState()`: Calls `_fetchLatestDailyUsage()`
- Primary hub listener: Calls `_fetchLatestDailyUsage()` when hub changes
- Hub removed listener: Sets `_latestDailyUsage = null` when no hubs available

## Benefits

1. **Accurate Usage Calculation**
   - Uses the same calculation logic as the Usage History screen
   - Ensures consistency across the app
   - Properly calculates daily difference (today - yesterday)

2. **Better Data Transparency**
   - Shows the exact date of the usage data
   - Displays both previous and current readings in debug logs
   - Users can verify the calculation

3. **Cleaner Architecture**
   - Reuses existing `UsageHistoryService` instead of duplicating logic
   - Single source of truth for usage calculations
   - Easier to maintain and debug

4. **Improved User Experience**
   - Clear "Daily Usage" label instead of confusing "Daily Cost"
   - Date label shows when the data was recorded
   - Proper handling when no data is available

## Data Flow

```
User opens Energy Overview
         ↓
_fetchLatestDailyUsage() called
         ↓
UsageHistoryService.calculateUsageHistory(
  interval: UsageInterval.daily,
  minRows: 1
)
         ↓
Service fetches daily aggregations from Firebase
         ↓
Calculates: Usage = Current Day Reading - Previous Day Reading
         ↓
Returns UsageHistoryEntry with:
  - timestamp
  - previousReading
  - currentReading
  - usage (difference)
         ↓
Energy Overview displays:
  - Daily Usage: [usage] kWh
  - Daily Cost: [usage × pricePerKWh]
  - Date: [formatted timestamp]
```

## Example Output

### Debug Log:
```
[EnergyOverview] Latest daily usage: 5.234 kWh (Dec 8, 2025) -
Previous: 123.456 kWh, Current: 128.690 kWh
```

### UI Display:
```
┌─────────────────┐
│ Daily Usage     │
│ ₱62.81          │
│ ▓▓▓▓▓▓▓░░░      │
│ Energy: 5.23 kWh│
│ Dec 8, 2025     │
└─────────────────┘
```

## Testing Recommendations

1. **Verify Usage Calculation**
   - Check that daily usage matches Usage History screen
   - Confirm the difference calculation is correct
   - Test with multiple days of data

2. **Test Edge Cases**
   - No data available (newly added hub)
   - Single day of data
   - Hub switching
   - Hub removal

3. **Check UI Updates**
   - Date label displays correctly
   - Progress bar behaves properly with 0 data
   - Cost calculation uses correct price per kWh

## Notes

- The card still calculates cost as `usage × _pricePerKWH`
- The progress bar is currently fixed at 70% when data exists (can be enhanced later)
- The card width is 110 pixels to fit the new date label
- Debug logging includes detailed information for troubleshooting
