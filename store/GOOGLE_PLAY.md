# Google Play listing: Daily KJB 1.1

Everything to enter in Play Console, field by field. Character counts are checked against Google's limits.

## Before you upload

1. **Signing.** Release builds are signed with the upload key named in `dailykjb/android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`). That file and the `.jks` are git-ignored; keep a copy of both somewhere safe, since every update must be signed with the same upload key. Let Play App Signing hold the app signing key (the default for new apps).
2. **Version code.** `version: 1.1.0+24` in `dailykjb/pubspec.yaml` gives versionName 1.1.0 and versionCode 24. Every upload needs a higher code than the last, and the iPhone build number comes from the same line, so bump it for whichever store is next.
3. **Build:**
   ```bash
   cd dailykjb && flutter build appbundle --release
   ```
   Upload `dailykjb/build/app/outputs/bundle/release/app-release.aab` (about 67 MB; most of it is the Bible, Strong's and Webster's 1828 built in).
4. **A new personal developer account** must run a closed test with at least 12 testers for 14 days before it can publish to production. Organization accounts skip this. Testing > Closed testing > create a track, add the testers' Google accounts, and upload the same `.aab` there first.

## Main store listing

| Field | Value |
| --- | --- |
| App name (30) | `Daily KJB: King James Bible` (27) |
| Short description (80) | `Accountability Bible reading: your apps stay locked each day until you've read.` (79) |
| Full description (4000) | `store/google-play/description.txt` (2164) |
| App icon | `store/google-play/icon-512.png` (512 × 512) |
| Feature graphic | `store/google-play/feature-1024x500.png` (1024 × 500, no transparency) |
| Phone screenshots | `store/google-play/screenshots/`, in order (below) |
| Category | Books & Reference |
| Tags | Bible, Reading, Productivity (pick the closest Play offers) |
| Website | `https://github.com/Cinderwire-co/DailyKJB` |
| Contact email | Required by Play and shown on the listing: use a support address, not a personal one |
| Privacy policy | `https://github.com/Cinderwire-co/DailyKJB/blob/main/PRIVACY.md` |

The full description is the App Store's with the Apple-only parts taken out: no Apple Intelligence, no widgets, and Focus Mode's two Android permissions explained instead of Screen Time.

## Screenshots

Play takes up to eight per device type, 1080 × 1920 (9:16). They're the App Store set, captured on the Android emulator and framed as an Android phone with a punch-hole camera. The journal shot is left out to keep to eight.

| Order | Caption | File |
| --- | --- | --- |
| 1 | An accountability Bible reading app | `01-focus.jpg` |
| 2 | Your Bible before your apps | `02-shield.jpg` |
| 3 | A little of the Word, every day | `03-today.jpg` |
| 4 | Read it, or prove it | `04-reading.jpg` |
| 5 | Turn the page, chapter to chapter | `05-bible.jpg` |
| 6 | Back to the Hebrew and Greek | `06-word.jpg` |
| 7 | Watch the year take shape | `08-progress.jpg` |
| 8 | Parchment by day, lamplight by night | `09-bible-dark.jpg` |

The shield in `02-shield.jpg` is the real one, over the Clock app. To make them again: capture the screens from the emulator into a folder named as `tools/frame_screenshots.py` expects, then `frame_screenshots.py <raw> android store/google-play/screenshots` and `make_banners.py` with the same folder for the feature graphic.

## App content

Policy > App content, one section at a time:

| Section | Answer |
| --- | --- |
| Privacy policy | The URL above |
| Ads | No, the app has no ads |
| App access | All functionality is available without special access (no sign-in) |
| Content rating | Category Reference, News, or Educational; answer No to every question. Expect Everyone / PEGI 3 |
| Target audience | 13 and over. Including under-13s brings in the Families policy and its extra review |
| News app | No |
| Data safety | No data collected, no data shared (below) |
| Government app | No |
| Financial features | None |
| Health | None |
| Foreground service permissions | Special use (below) |

### Data safety

Answer **No** to "Does your app collect or share any of the required user data types?" Nothing leaves the phone: no account, no analytics, no ads, no crash reporting, no network calls. Reading, notes, highlights and settings are stored on the device. Usage access is read on the device to see which app is in front and is never stored or sent, which Play doesn't count as collection.

### Foreground service permissions

Focus Mode's service is a special-use foreground service (`FOREGROUND_SERVICE_SPECIAL_USE`, subtype "App blocking overlay for focus mode"). Play asks what it does, why it can't wait, and for a video.

**Description:**

```
When the user turns on Focus Mode, Daily KJB keeps the apps they chose closed until they have done the day's Bible reading. The foreground service checks which app is in front, using the usage access the user grants, and when it is one the user chose, covers it with a screen saying the app opens once today's reading is done, with a button that opens the reading. After the reading it keeps running and checks less often, so the chosen apps close again at midnight. Its notification shows the whole time it runs, and it stops when the user turns Focus Mode off.
```

**Impact if deferred or interrupted:**

```
The apps the user chose would open without the day's reading being done, which is the one thing Focus Mode is for. The service has to notice a chosen app coming to the front within about a second, and has to be running at midnight to close the apps again; neither can wait for a WorkManager job or an alarm.
```

**Video:** Play wants a link, so upload `store/google-play/focus-mode-demo.mp4` to YouTube as unlisted and paste its URL. In 22 seconds it shows Focus Mode on with Clock chosen, Clock opening to the cover, and Read now opening today's reading. To record another: `adb shell screenrecord /sdcard/focus.mp4` on the emulator or a phone.

## Permissions

| Permission | Why |
| --- | --- |
| `PACKAGE_USAGE_STATS` (usage access) | Which app is in front, so Focus Mode can cover a chosen one. Granted by the user in Settings, after the app explains it |
| `SYSTEM_ALERT_WINDOW` (display over other apps) | To show the cover over a chosen app. Granted by the user in Settings |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE` | Focus Mode's watching service |
| `RECEIVE_BOOT_COMPLETED` | Focus Mode back on after a restart; reminders rescheduled |
| `POST_NOTIFICATIONS` | The daily reminder, and Focus Mode's notification |
| `VIBRATE` | Reminder notifications |

Not used, so no declarations: exact alarms (reminders are inexact), `QUERY_ALL_PACKAGES` (the app list comes from a `<queries>` entry for launcher apps), accessibility services.

Before Settings opens, the app says what usage access and display over other apps are for and that nothing leaves the phone (`requestFocusAccess` in `dailykjb/lib/screens/focus_screen.dart`). That's the prominent disclosure Google's User Data policy looks for.

## Release notes

For the first release (500 characters):

```
Daily KJB on Android: an accountability Bible reading app. Choose the apps that pull you away; each day they stay locked until you've read. The King James Bible with reading plans, Strong's Hebrew and Greek, Webster's 1828 and cross references, all offline.
```

## Testing notes for review

Play Console has no notes field like App Review's, but if a reviewer asks how to try Focus Mode:

```
1. Complete the short setup (any name and plan).
2. Settings > Focus Mode > Permissions > Open Settings, allow Usage access for Daily KJB, return, and do the same for Display over other apps.
3. Apps to keep closed > choose an app (for example Clock) > Done.
4. Turn Focus Mode on (the accountability passcode can be skipped).
5. Open the chosen app: Daily KJB covers it. Read now opens today's reading.
6. In Daily KJB, read to the end of the day's chapters, wait for the short timer, and Mark as read. The chosen app opens again until midnight.
```

## How Android differs from iPhone

- **Focus Mode** uses usage access and an overlay instead of Apple's Screen Time, so the app does see which apps are chosen (it needs their package names to cover them). They stay on the phone.
- **Apple Intelligence** features (study notes, plain-English meanings, the written quiz) are iPhone-only and hidden on Android. Every other study tool and the word quiz work the same.
- **Widgets** are iPhone-only for now.
- **Typefaces:** Georgia is Apple's, so Android offers its own serif in its place.
