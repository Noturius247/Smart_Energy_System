# ⚡ Quick Start Guide - Cloud Functions

## 🎯 Goal
Make your device schedules work **24/7**, even when app is closed!

---

## 📝 5-Minute Setup

### 1️⃣ Install Firebase CLI
```bash
npm install -g firebase-tools
```

### 2️⃣ Login to Firebase
```bash
firebase login
```

### 3️⃣ Navigate to Project
```bash
cd "d:\latestupdate\Smart_Energy_System"
```

### 4️⃣ Initialize Functions (if needed)
```bash
firebase init functions
```
- Select **existing project**
- Choose **JavaScript**
- Install dependencies: **Yes**

### 5️⃣ Upgrade to Blaze Plan
- Go to: https://console.firebase.google.com/
- Click **Upgrade** → Select **Blaze Plan**
- Add card (you won't be charged - within free tier)
- **Optional:** Set budget alert to $1

### 6️⃣ Deploy!
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### 7️⃣ Verify
```bash
firebase functions:log
```

---

## ✅ Done!

Your schedules now run automatically in **Philippine Time (UTC+8)**!

---

## 🔍 Quick Commands

| Command | What it does |
|---------|-------------|
| `firebase deploy --only functions` | Deploy/update functions |
| `firebase functions:log` | View function logs |
| `firebase functions:delete checkSchedules` | Stop function |
| `firebase open functions` | Open console |

---

## 💰 Cost

**$0.00/month** (within free tier: 2M calls/month, you use 44k)

---

## 📚 More Details

See [CLOUD_FUNCTIONS_SETUP.md](CLOUD_FUNCTIONS_SETUP.md) for complete guide!
