# Debug running — ADB + logcat (your setup)

Short cheat sheet for **big debugging** on your Android TV / device: connect, capture logs, save them. Not app-specific — works for any package.

## Your paths and address

| What | Value |
|------|--------|
| **Android SDK `platform-tools`** | `C:\Users\themi\AppData\Local\Android\Sdk\platform-tools` |
| **Wireless ADB** (TV / device) | `192.168.20.199:34167` |
| **This app’s package** (when filtering) | `com.iptvil.iptvil` |

## Before you start

1. On the **device**: enable **Developer options** → **Wireless debugging** (or USB debugging if you use a cable).
2. **PC and device** on the **same LAN** (for wireless).

## Open a terminal in `platform-tools`

**PowerShell or CMD:**

```text
cd C:\Users\themi\AppData\Local\Android\Sdk\platform-tools
```

(Optional) Add that folder to your user **PATH** once — then you can run `adb` from anywhere.

## Connect

**Wireless (your address):**

```text
adb connect 192.168.20.199:34167
adb devices
```

You should see a device listed as `192.168.20.199:34167` (or similar). If it says `unauthorized`, accept the **RSA fingerprint** on the TV screen.

**USB:** plug in the device, same `adb devices` check.

## Capture logs (logcat)

**Everything** (noisy — good for “something big is wrong”):

```text
adb logcat
```

**Only lines that mention this app or common crash tags** (good default on Windows):

```text
adb logcat | findstr /i "iptvil flutter AndroidRuntime SQLite chromium"
```

**Filter by process ID** (after the app is running — PowerShell):

```powershell
$p = (adb shell pidof com.iptvil.iptvil).Trim(); adb logcat --pid=$p
```

If `pidof` returns nothing, the app is not running; open the app first.

**Save to a file** (share with someone or review later):

```text
adb logcat -d > C:\Users\themi\Desktop\android-log.txt
```

`-d` dumps current buffer and exits. To record **live** to a file, omit `-d` and use redirection while you reproduce the issue:

```text
adb logcat > C:\Users\themi\Desktop\android-log-live.txt
```

Stop with **Ctrl+C**.

## Clean run (optional)

Right before reproducing the bug:

```text
adb logcat -c
```

Then start `adb logcat` (or your filtered command) and **do the steps once** so the file isn’t full of old noise.

## Disconnect wireless (optional)

```text
adb disconnect 192.168.20.199:34167
```

## If `adb` is not recognized

You are not in `platform-tools`, or PATH is not set. Always works:

```text
cd C:\Users\themi\AppData\Local\Android\Sdk\platform-tools
.\adb.exe devices
```

---

*Personal reference — update the IP/port if the TV gets a new wireless debugging pairing.*

====================================================

----Shield Test Box Info-----
Step 1 To Connect:

cd C:\Users\themi\Desktop\platform-tools
.\adb.exe connect 192.168.20.45:5555
.\adb.exe devices

Step-2 Clear the log:

.\adb.exe logcat -c

Step-3 test the bug then Run This To Get The DeBug:

run this you will get the log:
.\adb.exe logcat -d > C:\Users\themi\Desktop\iptvil_log.txt

---

## Windows: `Dart snapshot generator failed` / `gen_snapshot` / `ExceptionCode=-1073741795`

Release APK runs the **AOT compiler** (`gen_snapshot`). On some PCs it exits with **access violation** or **illegal instruction** (negative exit codes like **-1073740791**). The project code is usually fine; the failure is **environmental**.

**Try in order:**

1. **Clean and rebuild**
   ```text
   cd C:\Users\themi\Desktop\IpTvIl
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

2. **Single ABI** (less work for the compiler — sometimes avoids memory / flaky runs):
   ```text
   flutter build apk --release --target-platform android-arm64
   ```

3. **Repair Flutter tool cache** (corrupted `gen_snapshot`):
   ```text
   flutter precache
   ```
   If it still fails, delete **`%LOCALAPPDATA%`** … actually the standard fix is delete **`flutter\bin\cache`** inside your Flutter SDK (not the project), then run `flutter doctor` and `flutter precache` again.

4. **Antivirus / Controlled Folder Access** — add **exclusions** for your Flutter SDK folder, this project folder, and `%LOCALAPPDATA%\Pub\Cache`.

5. **Update Flutter** (`flutter upgrade`) and run **`flutter doctor -v`**.

6. **RAM / page file** — AOT is heavy; close other apps or raise Windows virtual memory.

If release keeps failing but **debug** works (`flutter build apk --debug`), it confirms an AOT/toolchain issue on that machine, not app logic.

