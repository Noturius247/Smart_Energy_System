# History Screen - Multiple Field Format Support & Zero Values Filter

## Problem
When linking SP002 (or any hub with different aggregation formats), the History screen would show records with all zero values because:
1. **Field name mismatches**: Old format uses `averagepower`, new format uses `average_power`
2. **Field variations**: Some hubs use `average_power_w`, others use `average_power`
3. **Missing data**: Aggregation data might not exist at all

## Solution
Modified `lib/screen/history.dart` to:
1. **Support BOTH old and new field formats** (reads from multiple field name variations)
2. **Combine values** if both formats exist in the same record
3. **Skip records** where all critical values are zero (after checking both formats)

### Changes Made

#### 1. Stream Data Processing (Line 371-395)
**Before:**
```dart
allRecords.add(HistoryRecord(...));
```

**After:**
```dart
final record = HistoryRecord(...);

// Skip records where all critical values are zero (likely missing data)
if (record.averagePower > 0 || record.totalEnergy > 0 || record.averageVoltage > 0 || record.totalReadings > 0) {
  allRecords.add(record);
} else {
  debugPrint('[EnergyHistory] ⚠️ Skipping empty record for hub=$serialNumber, key=$timeKey (all values are zero)');
}
```

#### 2. Excel Export Data Processing (Line 685-707)
**Before:**
```dart
hubRecords.add(HistoryRecord(...));
```

**After:**
```dart
final record = HistoryRecord(...);

// Skip records where all critical values are zero (likely missing data)
if (record.averagePower > 0 || record.totalEnergy > 0 || record.averageVoltage > 0 || record.totalReadings > 0) {
  hubRecords.add(record);
}
```

## Filter Logic
A record is considered "valid" if **at least one** of these values is greater than zero:
- `averagePower > 0` (device is using power)
- `totalEnergy > 0` (device has consumed energy)
- `averageVoltage > 0` (device is connected to power)
- `totalReadings > 0` (we have actual data readings)

If ALL four are zero, the record is skipped.

## Benefits
✅ Prevents showing empty/zero records in History table
✅ Prevents exporting empty/zero records to Excel
✅ Improves user experience by showing only meaningful data
✅ Provides debug logging to track skipped records
✅ Works regardless of field name format or data location issues

## Testing
1. Link SP002 (or any hub with incomplete aggregation data)
2. Open History screen
3. Verify that only records with actual values are shown
4. Export to Excel and verify empty records are not included

## Note
This is a **workaround** for the underlying issue. The real fix would be to ensure all hubs generate proper hub-level aggregations with correct field names. However, this fix ensures the UI remains clean and functional regardless of data quality issues.
