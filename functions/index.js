/**
 * Firebase Cloud Functions for Smart Energy System
 * Handles automatic schedule execution in Philippine Time (UTC+8)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

/**
 * Scheduled function that runs every minute to check and execute device schedules
 * Runs in Philippine Time (UTC+8)
 */
exports.checkSchedules = functions.pubsub
  .schedule('every 1 minutes')
  .timeZone('Asia/Manila') // Philippine Time Zone
  .onRun(async (context) => {
    console.log('[Schedule Checker] Starting schedule check at Philippine Time:', new Date().toLocaleString('en-PH', { timeZone: 'Asia/Manila' }));

    try {
      const db = admin.database();
      const now = new Date();

      // Get Philippine Time
      const phTime = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Manila' }));
      const currentHour = phTime.getHours();
      const currentMinute = phTime.getMinutes();
      const currentWeekday = phTime.getDay(); // 0=Sunday, 1=Monday, ..., 6=Saturday

      // Convert to 1=Monday, 7=Sunday format (to match app)
      const dayOfWeek = currentWeekday === 0 ? 7 : currentWeekday;

      console.log(`[Schedule] Current PH Time: ${currentHour}:${currentMinute}, Day: ${dayOfWeek}`);

      // Get all users
      const usersSnapshot = await db.ref('users').once('value');
      const users = usersSnapshot.val();

      if (!users) {
        console.log('[Schedule] No users found');
        return null;
      }

      let schedulesChecked = 0;
      let schedulesExecuted = 0;

      // Iterate through all users
      for (const [userEmail, userData] of Object.entries(users)) {
        if (!userData.hubs) continue;

        // Iterate through all hubs
        for (const [hubSerial, hubData] of Object.entries(userData.hubs)) {
          // Check hub schedules
          if (hubData.schedules) {
            const result = await checkAndExecuteSchedules(
              db,
              hubData.schedules,
              currentHour,
              currentMinute,
              dayOfWeek,
              userEmail,
              hubSerial,
              null, // null means it's a hub, not a plug
              'Hub'
            );
            schedulesChecked += result.checked;
            schedulesExecuted += result.executed;
          }

          // Check plug schedules
          if (hubData.plugs) {
            for (const [plugNumber, plugData] of Object.entries(hubData.plugs)) {
              if (plugData.schedules) {
                const result = await checkAndExecuteSchedules(
                  db,
                  plugData.schedules,
                  currentHour,
                  currentMinute,
                  dayOfWeek,
                  userEmail,
                  hubSerial,
                  plugNumber,
                  'Plug'
                );
                schedulesChecked += result.checked;
                schedulesExecuted += result.executed;
              }
            }
          }
        }
      }

      console.log(`[Schedule] Checked ${schedulesChecked} schedules, executed ${schedulesExecuted}`);
      return null;

    } catch (error) {
      console.error('[Schedule] Error checking schedules:', error);
      return null;
    }
  });

/**
 * Check and execute schedules for a device (hub or plug)
 */
async function checkAndExecuteSchedules(
  db,
  schedules,
  currentHour,
  currentMinute,
  currentWeekday,
  userEmail,
  hubSerial,
  plugNumber,
  deviceType
) {
  let checked = 0;
  let executed = 0;

  for (const [scheduleId, schedule] of Object.entries(schedules)) {
    checked++;

    // Skip if disabled
    if (schedule.isEnabled === false) {
      continue;
    }

    // Check if time matches
    if (schedule.hour !== currentHour || schedule.minute !== currentMinute) {
      continue;
    }

    // Check if should run today
    const repeatDays = schedule.repeatDays || [];
    const isOneTime = repeatDays.length === 0;

    if (!isOneTime && !repeatDays.includes(currentWeekday)) {
      continue;
    }

    // Execute the schedule
    const deviceName = plugNumber ? `Plug ${plugNumber}` : `Hub ${hubSerial}`;
    console.log(`[Schedule] Executing schedule for ${deviceName}: ${schedule.action} at ${currentHour}:${currentMinute}`);

    try {
      const targetState = schedule.action === 'turnOff' ? false : true;

      // Update ssr_state in Firebase
      let path;
      if (plugNumber) {
        // It's a plug
        path = `users/${userEmail}/hubs/${hubSerial}/plugs/${plugNumber}/data/ssr_state`;
      } else {
        // It's a hub
        path = `users/${userEmail}/hubs/${hubSerial}/ssr_state`;
      }

      await db.ref(path).set(targetState);
      console.log(`[Schedule] Updated ${path} to ${targetState}`);
      executed++;

      // If it's a one-time schedule, disable it
      if (isOneTime) {
        const schedulePath = plugNumber
          ? `users/${userEmail}/hubs/${hubSerial}/plugs/${plugNumber}/schedules/${scheduleId}/isEnabled`
          : `users/${userEmail}/hubs/${hubSerial}/schedules/${scheduleId}/isEnabled`;

        await db.ref(schedulePath).set(false);
        console.log(`[Schedule] Disabled one-time schedule ${scheduleId}`);
      }

    } catch (error) {
      console.error(`[Schedule] Error executing schedule ${scheduleId}:`, error);
    }
  }

  return { checked, executed };
}

/**
 * Optional: Manual trigger for testing
 * Can be called from Firebase Console or HTTP request
 */
exports.testScheduleChecker = functions.https.onRequest(async (req, res) => {
  console.log('[Test] Manual schedule check triggered');

  try {
    // Call the schedule checker directly
    await exports.checkSchedules.run({});
    res.status(200).send('Schedule check completed successfully');
  } catch (error) {
    console.error('[Test] Error:', error);
    res.status(500).send('Error: ' + error.message);
  }
});
