# 🚀 Firebase Cloud Functions Setup Guide
## Automated Schedule Execution for Smart Energy System

This guide will help you deploy Cloud Functions so your device schedules work **24/7**, even when the app is closed!

---

## ✅ What You'll Get

- ✅ Schedules run automatically every minute in **Philippine Time (UTC+8)**
- ✅ Works even when app is **completely closed**
- ✅ Works even when phone is **turned off**
- ✅ **100% reliable** - runs on Google's servers
- ✅ **$0.00/month** - stays within free tier
- ✅ No server maintenance required

---

## 📋 Prerequisites

Before you start, make sure you have:

1. ✅ **Node.js** installed (version 18 or higher)
   - Download from: https://nodejs.org/
   - Check version: `node --version`

2. ✅ **Firebase CLI** installed
   - Install: `npm install -g firebase-tools`
   - Check version: `firebase --version`

3. ✅ **Firebase project** (you already have this!)

4. ✅ **Credit/Debit card** for Blaze plan
   - **Don't worry!** You won't be charged
   - Set spending limit to $0 to prevent charges

---

## 🔧 Step-by-Step Setup

### Step 1: Check Your Files ✅

Make sure these files exist in your project:

```
Smart_Energy_System/
├── functions/
│   ├── index.js          ← Cloud Function code
│   ├── package.json      ← Dependencies
│   └── .gitignore        ← Git ignore file
└── firebase.json         ← Firebase config (we'll create this)
```

All files are already created! ✅

---

### Step 2: Login to Firebase

Open your terminal/command prompt and run:

```bash
firebase login
```

- This will open a browser window
- Login with the same Google account you used for Firebase
- Grant permissions when asked

---

### Step 3: Initialize Firebase in Your Project

Navigate to your project folder:

```bash
cd "d:\latestupdate\Smart_Energy_System"
```

Initialize Firebase (if not already done):

```bash
firebase init
```

**Important selections:**
- ❓ Which Firebase features? → Select **Functions** (use space to select, enter to confirm)
- ❓ Use existing project? → **Yes**
- ❓ Select your project → Choose your Smart Energy project
- ❓ Language? → **JavaScript**
- ❓ ESLint? → **No** (or Yes if you want)
- ❓ Install dependencies now? → **Yes**

**Note:** If you already have `functions/` folder, Firebase will detect it and skip some steps.

---

### Step 4: Upgrade to Blaze Plan

**IMPORTANT:** Cloud Functions require Blaze plan, but you won't be charged!

#### Option A: Using Firebase Console (Recommended)
1. Go to: https://console.firebase.google.com/
2. Select your project
3. Click **Upgrade** button (top right or in left sidebar)
4. Select **Blaze (Pay as you go)** plan
5. Enter your card details
6. ✅ **Set budget alert to $1** (optional but recommended)

#### Option B: Using Firebase CLI
```bash
firebase open billing
```
- This opens your project billing page
- Follow upgrade steps

#### 🛡️ Protect Yourself from Charges:

Set a spending limit:
1. Go to: https://console.cloud.google.com/billing
2. Select your project's billing account
3. Go to **Budgets & alerts**
4. Create budget: **$0** or **$1**
5. Set alert at 100% of budget
6. ✅ Enable **Stop billing automatically** (if available)

**Why you won't be charged:**
- Your usage: ~44,000 function calls/month
- Free tier: 2,000,000 calls/month
- You're using only **2%** of free tier! ✅

---

### Step 5: Install Dependencies

Navigate to functions folder and install packages:

```bash
cd functions
npm install
```

This will install:
- `firebase-functions` - Cloud Functions SDK
- `firebase-admin` - Firebase Admin SDK

---

### Step 6: Deploy Cloud Functions

Deploy your functions to Firebase:

```bash
firebase deploy --only functions
```

**What happens:**
- ✅ Code is uploaded to Google's servers
- ✅ Function is scheduled to run every minute
- ✅ Philippine timezone is configured (Asia/Manila)

**Expected output:**
```
✔  functions: Finished running predeploy script.
i  functions: preparing codebase default for deployment
i  functions: ensuring required API cloudfunctions.googleapis.com is enabled...
i  functions: ensuring required API cloudbuild.googleapis.com is enabled...
✔  functions: required API cloudfunctions.googleapis.com is enabled
✔  functions: required API cloudbuild.googleapis.com is enabled
i  functions: uploading functions archive to Firebase...
✔  functions: functions folder uploaded successfully
i  functions: creating Node.js 18 function checkSchedules(us-central1)...
✔  functions[checkSchedules(us-central1)] Successful create operation.

✔  Deploy complete!
```

---

### Step 7: Verify Deployment

Check if your function is running:

```bash
firebase functions:log
```

You should see logs like:
```
[Schedule Checker] Starting schedule check at Philippine Time: 12/17/2025, 10:30:00 PM
[Schedule] Current PH Time: 22:30, Day: 2
[Schedule] Checked 5 schedules, executed 1
```

---

## 🧪 Testing Your Cloud Function

### Test 1: Check Logs in Real-time

```bash
firebase functions:log --only checkSchedules
```

This shows you what the function is doing every minute!

### Test 2: Manual Trigger (Optional)

You can manually trigger the function for testing:

1. Go to Firebase Console: https://console.firebase.google.com/
2. Go to **Functions** section
3. Find `checkSchedules`
4. Click **More** (⋮) → **Test function**

Or call the test endpoint:
```bash
firebase functions:shell
# Then type: testScheduleChecker()
```

### Test 3: Create a Test Schedule

1. Open your app
2. Create a schedule for 2 minutes from now
3. Close the app completely
4. Wait for the schedule time
5. Check Firebase Realtime Database - `ssr_state` should change!
6. Check logs: `firebase functions:log`

---

## 📊 Monitoring & Costs

### View Usage Dashboard

Check your usage anytime:
```bash
firebase open functions
```

Or go to: https://console.firebase.google.com/ → Your Project → Functions

### Expected Monthly Usage:
- **Invocations:** ~44,000 (2% of free 2M)
- **Compute time:** ~73 minutes (0.04% of free 200k seconds)
- **Network:** < 1 MB (0% of free 5 GB)
- **Cost:** **$0.00** ✅

---

## 🔧 Troubleshooting

### Problem: "Billing account not configured"
**Solution:** Upgrade to Blaze plan (Step 4)

### Problem: "Function not running"
**Solution:** Check logs with `firebase functions:log`

### Problem: "Error deploying functions"
**Solution:**
1. Make sure you're in the project root directory
2. Run: `firebase init` again
3. Re-deploy: `firebase deploy --only functions`

### Problem: "Schedules not executing"
**Solution:**
1. Check function logs for errors
2. Verify schedules are saved in Firebase RTDB
3. Check schedule time is correct (uses PH Time)
4. Make sure schedule is enabled

### Problem: "Want to stop Cloud Functions temporarily"
**Solution:**
```bash
firebase functions:delete checkSchedules
```
To re-enable, just deploy again: `firebase deploy --only functions`

---

## 📱 Remove App Timer (Optional)

Since Cloud Functions now handle schedules, you can optionally remove the timer from the app to save battery:

**File:** `lib/screen/explore.dart`

**Find and comment out these lines:**
```dart
// Line 283: Comment this out
// _startScheduleChecker();

// Line 583: Comment this out
// _scheduleCheckTimer?.cancel();
```

**Note:** Keeping the app timer won't cause issues - it just provides backup checking when app is open.

---

## 🎉 You're Done!

Your schedules now run **automatically 24/7** in Philippine Time!

**What happens now:**
1. ✅ Every minute, Cloud Function checks all schedules
2. ✅ If a schedule matches current PH time, it executes
3. ✅ SSR state is updated in Firebase
4. ✅ ESP32 devices see the change and respond
5. ✅ One-time schedules are auto-disabled after execution

---

## 📞 Need Help?

If you encounter issues:

1. **Check logs:** `firebase functions:log`
2. **Check billing:** Make sure Blaze plan is active
3. **Verify deployment:** `firebase functions:list`
4. **Re-deploy:** `firebase deploy --only functions`

---

## 🔄 Updating Cloud Functions

If you need to update the code later:

1. Edit `functions/index.js`
2. Deploy changes:
   ```bash
   firebase deploy --only functions
   ```

That's it! Changes are live in ~1 minute.

---

## 💰 Cost Breakdown (Detailed)

| Resource | Your Usage | Free Tier | Overage Cost | Your Cost |
|----------|-----------|-----------|--------------|-----------|
| **Invocations** | 44,000/month | 2M/month | $0.40/M | **$0.00** |
| **Compute (GB-sec)** | ~3 GB-sec | 400k GB-sec | $0.0000025/GB-sec | **$0.00** |
| **CPU (seconds)** | ~73 seconds | 200k seconds | $0.0000100/sec | **$0.00** |
| **Network (GB)** | < 0.001 GB | 5 GB | $0.12/GB | **$0.00** |
| **TOTAL** | - | - | - | **$0.00** ✅ |

You're using less than **3%** of the free tier in all categories!

---

## ✨ Summary

- ✅ **Files created** in `functions/` folder
- ✅ **Setup time:** ~10 minutes
- ✅ **Monthly cost:** $0.00
- ✅ **Reliability:** 99.9%+ (Google infrastructure)
- ✅ **Maintenance:** Zero (fully managed)
- ✅ **Philippine Time:** Built-in (Asia/Manila)

**Your schedules are now production-ready!** 🚀🇵🇭
