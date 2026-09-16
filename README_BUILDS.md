# Money Book - Build & Installation Guide (Android & iOS)

---

## 🤖 1. Android Installation (.apk)

The Android release APK is already generated and located in this directory:
- **File**: `Money_Book.apk`
- **Location**: `c:\Users\Acer\.gemini\antigravity\scratch\expense_tracker\Money_Book.apk`

### How to Install:
1. Transfer `Money_Book.apk` to your Android device (via USB cable, Google Drive, or messaging apps).
2. Tap the `.apk` file on your phone.
3. If prompted, allow "Install from Unknown Sources".
4. The **Money Book** app will be installed with the custom icon and full offline + auto-backup functionality.

---

## 🍎 2. iOS Installation (.ipa)

Apple devices require an **`.ipa`** package compiled through macOS / Xcode. Because this development machine is Windows, we have set up two effortless ways to get the `.ipa`:

### 🚀 Method A: Free Cloud Build via GitHub Actions (Recommended from Windows)
We have added an automated cloud build workflow: [`.github/workflows/build_apps.yml`](file:///.github/workflows/build_apps.yml).

1. Push this project to your GitHub repository:
   ```bash
   git init
   git add .
   git commit -m "Money Book with iOS & Android builds"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
   git push -u origin main
   ```
2. Go to your GitHub repository in your browser.
3. Click the **Actions** tab at the top.
4. You will see **Build Money Book (Android APK & iOS IPA)** running automatically on an Apple macOS cloud machine.
5. When complete, click on the workflow run and download:
   - **`Money_Book_iOS_IPA`** (`Money_Book.ipa`)
   - **`Money_Book_Android_APK`** (`Money_Book.apk`)

---

### 💻 Method B: Direct Build on any Mac
If you or a friend have a Mac:
1. Copy this folder to the Mac.
2. Open Terminal in this folder and run:
   ```bash
   chmod +x build_ios.sh
   ./build_ios.sh
   ```
   Or run:
   ```bash
   flutter build ipa --no-codesign
   ```
3. Your `Money_Book.ipa` will be ready instantly in the folder!

---

### 📲 How to Install `.ipa` on an iPhone:
Once you download `Money_Book.ipa`:
- **Option 1**: Use **AltStore** or **Sideloadly** (Free, connects via USB or Wi-Fi to install any `.ipa` to your iPhone directly).
- **Option 2**: If you have an Apple Developer account, upload to **TestFlight** via Transporter or Xcode.
