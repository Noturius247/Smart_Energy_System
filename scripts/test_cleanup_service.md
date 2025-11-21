# Data Cleanup Service Test Plan

## Overview
The automatic cleanup service deletes per-second data older than 2 minutes every 5 minutes.

## Test Steps

### 1. Manual Testing
1. Run the app and log in as a user
2. Check debug console for cleanup service logs:
   - `[DataCleanupService] Starting automatic cleanup service`
   - `[DataCleanupService] Starting cleanup cycle...`
   - `[DataCleanupService] Hub {serial}: Deleted X old per-second records`
   - `[DataCleanupService] Cleanup cycle completed. Total records deleted: X`

### 2. Verify Data Retention
1. Go to Firebase Realtime Database console
2. Navigate to `users/espthesisbmn/hubs/{hubSerial}/aggregations/per_second`
3. Check timestamps - should only see records from last 2 minutes
4. Wait 5 minutes and check again - old records should be deleted

### 3. Expected Behavior
- **Initial cleanup**: Should delete most historical per-second data on first run
- **Subsequent cleanups**: Should delete records older than 2 minutes every 5 minutes
- **Storage impact**: Storage should stabilize at ~2 MB (constant) instead of growing 62 MB/day

### 4. Monitor Storage Usage
- Check Firebase Console > Storage usage
- Before cleanup: Growing at ~62 MB/day
- After cleanup: Should stabilize at ~2 MB total for per-second data

## Key Features Implemented

### Cleanup Service (`lib/services/data_cleanup_service.dart`)
- Runs every 5 minutes automatically
- Deletes per-second data older than 2 minutes
- Queries only user's own hubs (filtered by ownerId)
- Logs all cleanup operations for monitoring

### Integration (`lib/main.dart`)
- Starts cleanup service when user logs in
- Stops cleanup service when user logs out
- Properly disposes service on app termination

## Performance Impact

### Before Cleanup
- **Storage**: 62 MB/day growth → 1 GB limit in 16.6 days
- **Bandwidth**: 0.19% of free tier (excellent)
- **Records**: Unlimited historical data

### After Cleanup
- **Storage**: ~2 MB constant → Never hits limit
- **Bandwidth**: 0.19% of free tier (unchanged, still excellent)
- **Records**: Only last 2 minutes (120 records per hub)

## Troubleshooting

### If cleanup is not running:
1. Check if user is authenticated
2. Check debug logs for error messages
3. Verify Firebase permissions allow delete operations

### If old data still exists:
1. Wait for next cleanup cycle (runs every 5 minutes)
2. Check if data is actually older than 2 minutes
3. Verify the hub belongs to authenticated user

## Security Considerations
- Cleanup only deletes data from hubs owned by authenticated user
- Uses Firebase security rules to prevent unauthorized deletions
- No admin privileges required for user's own data
