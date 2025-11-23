# Usage History Feature

## Overview
The Usage History table tracks resource consumption across hourly, daily, weekly, and monthly periods by calculating usage **live** from meter readings stored in your database.

**Key Feature**: No usage values are ever saved - all calculations are performed on-demand from raw meter readings.

## How It Works

### 1. Database Structure
- Stores meter readings (electricity) with timestamps in Firebase Realtime Database
- Uses aggregations at different levels:
  - `per_second/data/` - Real-time second-by-second data
  - `hourly/` - Hourly aggregated data
  - `daily/` - Daily aggregated data
  - `weekly/` - Weekly aggregated data

**Note:** Monthly usage is calculated from daily aggregations, not stored separately.

### 2. Live Calculation Process
Every time you open or refresh the Usage History table:

1. **Fetches raw readings** from the database for the selected time period
2. **Finds pairs of readings** for each interval (start and end of hour/day/week/month)
3. **Calculates usage** by subtracting:
   ```
   Usage = Current Reading - Previous Reading
   ```
4. **Populates the table** with:
   - Timestamp
   - Interval type (Hourly, Daily, Weekly, Monthly)
   - Previous reading value
   - Current reading value
   - Calculated usage (difference)

### 3. Monthly Interval (Custom Due Date)
For monthly calculations, you can set a custom billing cycle due date (e.g., 23rd of each month):

- **Due Date Setup**: Go to Settings → Set your billing due date
- **Monthly Periods**: Calculated from due date to due date
  - Example: Oct 23 → Nov 23 → Dec 23
- **Data Source**: Monthly usage is calculated by finding daily readings at billing period boundaries
  - Fetches daily aggregation data
  - Finds closest daily reading to start due date
  - Finds closest daily reading to end due date
  - Calculates usage as the difference
- **Current Period**: If today is before the next due date, usage continues to accumulate until the due date is reached

### 4. Historical Data & Infinite Scroll
- **Minimum Display**: Shows at least 10 rows initially
- **Scrolling**: Scroll down to load more historical intervals automatically
- **Pagination**: Loads 10 additional rows each time you scroll to the bottom (80% threshold)
- **All intervals available**: The table can show any historical period where meter readings exist

## Usage Example

### Sample Table Row
```
┌────────────────────┬──────────┬──────────────────┬─────────────────┬────────────┐
│ Timestamp          │ Interval │ Previous Reading │ Current Reading │ Usage      │
├────────────────────┼──────────┼──────────────────┼─────────────────┼────────────┤
│ Nov 24, 2025 02:00 │ Hourly   │ 10010.00 kWh     │ 10100.00 kWh    │ 90.00 kWh  │
└────────────────────┴──────────┴──────────────────┴─────────────────┴────────────┘
```

**Interpretation**: During the hour ending at 2:00 AM on November 24, 2025, the meter consumed 90 kWh of energy.

## User Interface Features

### Hub Selection
- If you have multiple hubs, select which hub's usage history to view
- Dropdown selector appears at the top when multiple hubs are available

### Interval Buttons
Switch between different time periods:
- **Hourly**: Hour-by-hour usage (24-hour periods)
- **Daily**: Day-by-day usage
- **Weekly**: Week-by-week usage
- **Monthly**: Month-by-month usage (based on your custom due date)

### Real-time Updates
- Click the refresh button to recalculate usage from the latest readings
- Data is always current and accurate
- No cached or stale data

## Technical Implementation

### Files Created
1. **`lib/models/usage_history_entry.dart`**
   - Model class for a single usage history row
   - Contains timestamp, interval, readings, and calculated usage

2. **`lib/services/usage_history_service.dart`**
   - Service class that performs live calculations
   - Fetches aggregated data from Firebase
   - Calculates usage differences between readings
   - Handles pagination for infinite scroll

3. **`lib/screen/history.dart`** (Updated)
   - Added new Usage History table section
   - Displays below the existing Central Hub Data table
   - Implements infinite scroll with lazy loading

### Key Methods

#### `calculateUsageHistory()`
Main calculation method that:
- Takes hub serial number, interval type, optional due date
- Fetches appropriate aggregation data from database
- Calculates usage for each period
- Returns list of UsageHistoryEntry objects

#### `_calculateMonthlyHistory()`
Special handler for monthly intervals:
- Uses custom due date to determine billing periods
- Finds closest readings to billing cycle boundaries
- Handles edge cases when readings aren't exactly on due dates

## Advantages

### 1. No Storage Overhead
- Doesn't store calculated usage values
- Only raw meter readings are saved
- Reduces database size and complexity

### 2. Always Accurate
- Calculations use latest available readings
- No risk of stale or out-of-sync usage data
- Reflects database state in real-time

### 3. Flexible
- Can calculate usage for any time period on-demand
- Easy to add new interval types
- Simple to debug (just check raw readings)

### 4. Auditable
- Users can see both readings and calculated usage
- Easy to verify calculations manually
- Transparent billing

## Future Enhancements

Possible improvements:
- Export usage history to CSV/Excel
- Cost calculations based on electricity rates
- Usage trend graphs
- Comparison between periods
- Alert thresholds for high usage
- Multi-hub aggregated view

## Notes for Developers

### Adding New Interval Types
1. Add new enum value to `UsageInterval` in `usage_history_entry.dart`
2. Add calculation method to `UsageHistoryService`
3. Update color mapping in history screen UI
4. Implement formatting logic in `UsageHistoryEntry.getFormattedTimestamp()`

### Performance Considerations
- Aggregated data is already pre-processed by backend
- Calculations are lightweight (simple subtraction)
- Pagination prevents loading too much data at once
- Scroll listener uses 80% threshold for smooth UX
