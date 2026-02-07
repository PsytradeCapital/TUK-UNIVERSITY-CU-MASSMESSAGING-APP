# 🚀 TUK CU Mass Messaging App - Launch Guide

Welcome! This guide will help you launch and share your Christian Union Mass Messaging App.

---

## 📱 What is This App?

The TUK CU Mass Messaging App helps your Christian Union manage attendance and communicate with members efficiently. You can:
- ✅ Register attendees quickly
- 📊 Track attendance for services
- 💬 Send bulk SMS messages
- 📸 Scan documents to extract attendee information
- 📈 View attendance reports and analytics

---

## 🎯 Quick Start - Installing on Your Phone

### Option 1: Direct Installation (Easiest)

1. **Connect your phone to your computer** using a USB cable
2. **Enable USB Debugging** on your phone:
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times (you'll see "You are now a developer!")
   - Go back to Settings → Developer Options
   - Turn on "USB Debugging"
   - Allow the connection when prompted

3. **Run the installation command**:
   ```
   adb install -r build\app\outputs\flutter-apk\app-release.apk
   ```

4. **Open the app** on your phone and sign in!

### Option 2: Transfer APK File

1. **Find the APK file** on your computer:
   ```
   build\app\outputs\flutter-apk\app-release.apk
   ```

2. **Copy it to your phone**:
   - Connect phone via USB
   - Copy the APK file to your phone's Downloads folder
   - Or email it to yourself
   - Or use Google Drive/WhatsApp to send it

3. **Install on your phone**:
   - Open the APK file from your phone
   - Tap "Install"
   - If prompted, allow "Install from Unknown Sources"

---

## 🌍 Sharing the App with Others

### Method 1: Share the APK File (Recommended)

**The APK file is located at:**
```
build\app\outputs\flutter-apk\app-release.apk
```

**Ways to share it:**

1. **WhatsApp/Telegram**
   - Send the APK file directly in a chat
   - Recipients tap to download and install

2. **Google Drive**
   - Upload the APK to Google Drive
   - Share the link with "Anyone with the link can view"
   - Recipients download and install

3. **Email**
   - Attach the APK file to an email
   - Send to your team members

4. **USB Transfer**
   - Copy APK to a USB drive
   - Share physically with team members

### Method 2: Host on a Website

1. **Upload the APK** to your website or file hosting service
2. **Share the download link** with your team
3. **Users download and install** from their phones

### Method 3: Google Play Store (Advanced)

For wider distribution, you can publish to Google Play Store:
1. Create a Google Play Developer account ($25 one-time fee)
2. Prepare app listing (description, screenshots, icon)
3. Upload the APK
4. Submit for review
5. Once approved, anyone can download from Play Store

---

## 👥 User Accounts & Permissions

### Admin Account (You)
- **Email:** martinmbugua300@gmail.com
- **Role:** Admin (automatically approved)
- **Can do:** Everything - register attendees, send messages, approve users, view reports

### New Users
When someone installs the app:
1. They tap "Register" on the login screen
2. Enter their name, email, and password
3. Their account is created but **pending approval**
4. **You (admin) must approve them** before they can use the app

### How to Approve New Users
1. Sign in as admin
2. Go to **Settings** → **User Management**
3. See list of pending users
4. Tap **Approve** next to their name
5. They can now sign in and use the app!

---

## 🔐 First Time Setup

### For You (Admin)
1. **Install the app** using one of the methods above
2. **Open the app**
3. **Sign in** with:
   - Email: `martinmbugua300@gmail.com`
   - Password: `Martin900mbugu#`
4. **Set up a PIN** for quick access (optional but recommended)
5. **Start using the app!**

### For Team Members
1. **Install the app** (you'll share the APK with them)
2. **Open the app**
3. **Tap "Register"**
4. **Fill in their details:**
   - Full Name
   - Email Address
   - Password (at least 8 characters)
5. **Wait for admin approval**
6. **Sign in** once approved

---

## 📖 How to Use the App

### 🏠 Home Screen
After signing in, you'll see:
- **Register Attendee** - Add new attendees
- **Messaging** - Send bulk SMS
- **Reports** - View attendance statistics
- **Settings** - Manage app settings

### ✍️ Registering Attendees

**Manual Registration:**
1. Tap **"Register Attendee"**
2. Fill in the form:
   - Name
   - Phone Number (format: 0712345678)
   - Year of Study (for students)
   - Location (e.g., Main Campus, Hostels)
   - Category (Student/Associate/Visitor)
3. Tap **"Register"**
4. Attendee is saved!

**Scan Documents (Fast Registration):**
1. Tap **"Register Attendee"**
2. Tap the **camera icon** (Document Scanner)
3. Take a photo of an attendance sheet
4. The app extracts names and phone numbers automatically
5. Review and confirm the attendees
6. Tap **"Save All"**

### 💬 Sending Messages

1. Tap **"Messaging"**
2. **Select Recipients:**
   - All attendees
   - By category (Students/Associates/Visitors)
   - By location
   - Specific service attendees
3. **Type your message**
4. **Preview** who will receive it
5. Tap **"Send"**
6. Messages are sent via SMS!

### 📊 Viewing Reports

1. Tap **"Reports"**
2. See:
   - Total attendees
   - Attendance by service
   - Attendance trends
   - Category breakdown
3. **Export reports** as CSV or PDF
4. **Share reports** via email or WhatsApp

### ⚙️ Settings

- **User Management** - Approve new users (admin only)
- **Sync Settings** - Configure cloud sync
- **Backup & Restore** - Backup your data
- **Profile** - Update your profile
- **Sign Out** - Log out of the app

---

## 🔄 Syncing Data

The app works **offline** and syncs when you have internet:

- **Automatic Sync:** Data syncs automatically when online
- **Manual Sync:** Pull down on any screen to refresh
- **Sync Status:** Check the sync icon at the top

**What gets synced:**
- ✅ Attendee records
- ✅ Service attendance
- ✅ Message logs
- ✅ User accounts

---

## 🆘 Troubleshooting

### "Pending Approval" Screen
**Problem:** New user can't access the app
**Solution:** Admin must approve them in Settings → User Management

### Can't Install APK
**Problem:** "Install blocked" message
**Solution:** 
1. Go to Settings → Security
2. Enable "Unknown Sources" or "Install Unknown Apps"
3. Try installing again

### App Crashes on Startup
**Problem:** App closes immediately
**Solution:**
1. Clear app data: Settings → Apps → TUK CU → Clear Data
2. Reinstall the app
3. Sign in again

### Messages Not Sending
**Problem:** SMS messages fail to send
**Solution:**
1. Check phone has SMS permission
2. Ensure phone has airtime/SMS bundle
3. Check internet connection for logging

### Data Not Syncing
**Problem:** Changes don't appear on other devices
**Solution:**
1. Check internet connection
2. Pull down to refresh
3. Go to Settings → Force Sync

---

## 📞 Support & Help

**Need help?**
- Contact the admin: martinmbugua300@gmail.com
- Check the User Guide (in the app: Settings → Help)
- Report bugs to your IT team

---

## 🔒 Security & Privacy

- ✅ All passwords are encrypted
- ✅ Phone numbers are hashed for privacy
- ✅ Data is backed up to secure cloud storage
- ✅ Only approved users can access the app
- ✅ Admin controls who can register attendees

---

## 🎉 Tips for Success

1. **Backup regularly** - Go to Settings → Backup & Restore
2. **Approve users promptly** - Check for pending users daily
3. **Use document scanner** - Faster than manual entry
4. **Review reports weekly** - Track attendance trends
5. **Keep the app updated** - Install new versions when available

---

## 📝 Quick Reference

| Task | Steps |
|------|-------|
| Install app | Copy APK → Open → Install |
| Register user | Open app → Register → Fill form → Wait for approval |
| Add attendee | Register Attendee → Fill form → Save |
| Send message | Messaging → Select recipients → Type → Send |
| View reports | Reports → Select report type |
| Approve user | Settings → User Management → Approve |
| Backup data | Settings → Backup & Restore → Backup Now |

---

## 🚀 Ready to Launch!

You're all set! Share the APK file with your team and start managing your Christian Union attendance efficiently.

**Remember:**
- You're the admin - approve new users
- Backup your data regularly
- Share the APK file securely
- Train your team on how to use the app

**Happy messaging! 🎊**

---

*Last updated: February 7, 2026*
*App Version: 1.0.0*
*For: TUK Christian Union*
