# App Store listing: Daily KJB 1.1

Everything to enter in App Store Connect, field by field. Character counts are checked against Apple's limits.

## Before you submit

1. **Signing.** Put your Apple Developer Team ID in `dailykjb/ios/Flutter/Signing.xcconfig` (copy the `.example` next to it). The file is git-ignored.
2. **Family Controls for the extensions.** Focus Mode uses Apple's Screen Time, and Apple grants its distribution entitlement per bundle ID. The app (`com.dailykjb.dailyKjb`) has it. Its three Screen Time extensions each need their own approval before an App Store build can be signed; see [Family Controls](#family-controls) below.
3. **Build numbers.** Every upload needs a higher build number: `version: 1.1.0+22` in `dailykjb/pubspec.yaml` means 1.1.0 (22). The extensions take their version and build number from it.
4. **Upload a build:**
   ```bash
   cd dailykjb && flutter build ipa --release && cd ..
   tools/upload_ios.sh
   ```
   The script uploads with the Apple ID signed in to Xcode. If it says "Failed to Use Accounts", sign in again in Xcode > Settings > Accounts, or drag the `.ipa` from `dailykjb/build/ios/ipa/` into Transporter and choose Deliver. The build appears under TestFlight after processing (usually 10 to 30 minutes).

## App information

| Field | Value |
| --- | --- |
| Name (30) | `Daily KJB: King James Bible` (27) |
| Subtitle (30) | `Reading plans & word study` (26) |
| Bundle ID | `com.dailykjb.dailyKjb` |
| Primary category | Reference |
| Secondary category | Books |
| Content rights | Contains third-party content it has the rights to use: public-domain texts and openly licensed data (see `NOTICE.md`) |
| Age rating | 4+ (answer None or No to every question in the questionnaire) |
| License agreement | Apple's standard EULA |

## Pricing and availability

Free, in every territory.

## App privacy

- Privacy Policy URL: `https://github.com/Cinderwire-co/DailyKJB/blob/main/PRIVACY.md`
- Data collection: **Data Not Collected**. No account, analytics, advertising or tracking SDKs; reading, notes and settings stay on the device; Apple Intelligence runs on the device; Screen Time choices are opaque tokens the app can't read; reminders are local notifications.

## Version information

**Support URL:** `https://github.com/Cinderwire-co/DailyKJB/issues`

**Marketing URL** (optional): `https://github.com/Cinderwire-co/DailyKJB`

**Keywords (100):**

```
kjv,king james,bible,reading plan,devotional,strongs,webster 1828,scripture,offline,study,verse
```

**Promotional text (170):**

```
The King James Bible, a little every day. Reading plans, Strong's and Webster's 1828 built in, and Focus Mode to put the Word before the world. Works offline.
```

**Description:** in `store/description.txt`.

**What's New in 1.1.0:**

```
A new Daily KJB.
• A warm new look: parchment by day, lamplight by night
• The Bible turns like a book, a chapter to a page
• Tap any word for Strong's Hebrew and Greek and Webster's 1828, all offline
• Study notes, plain-English meanings and quizzes from Apple Intelligence, on your iPhone
• Focus Mode now closes your chosen apps again each midnight, even if Daily KJB isn't opened
• New Testament plan fixed for passages that cross chapters and books
• The two-year plan now has reading every day
• Many smaller fixes
```

## Screenshots

In `store/screenshots/`, in upload order:

- **iPhone 6.9"** (1320 × 2868): `iphone-6.9/01-today.jpg` to `10-share.jpg`. App Store Connect scales them for smaller iPhones.
- **iPad 13"** (2064 × 2752): `ipad-13/01-today.jpg` to `09-bible-dark.jpg`.

They're generated: `tools/screenshots.sh` opens the simulator at staged screens with demo data, and `tools/frame_screenshots.py` adds the captions.

## App Review notes

No sign-in is needed. Paste into App Review Information > Notes:

```
Daily KJB is a King James Bible reading app. No account or sign-in is needed; all content is built into the app and works offline.

FOCUS MODE (Screen Time / Family Controls)
Focus Mode lets the person using the device choose apps to keep shielded each day until they have completed that day's Bible reading. It uses FamilyControls with .individual authorization, ManagedSettings to shield the chosen apps, and a DeviceActivity schedule (midnight to midnight) whose monitor extension re-applies the shields at the start of each day. The shield's "Read now" button posts a local notification that opens Daily KJB.

To test:
1. Complete the short setup (any name and plan).
2. Settings → Focus Mode → Screen Time access → Allow.
3. "Apps to keep closed" → choose an app (e.g. Safari) → Done.
4. Turn Focus Mode on (you can skip the accountability passcode).
5. Open the chosen app: it is shielded.
6. Return to Daily KJB → Today → Begin reading → swipe to the last chapter → wait for the short reading timer → Mark as read. The chosen app opens again.
To turn Focus Mode off: Settings → Focus Mode → switch off (if a passcode was set, enter it).

APPLE INTELLIGENCE
On devices with Apple Intelligence, the Study page (tap a verse in the Bible tab, then Study) offers "Explain this verse", and tapping any underlined word shows a plain-English meaning. These use the on-device Foundation Models framework; nothing leaves the device. On devices without Apple Intelligence these features are hidden and the app's built-in study tools (Strong's, Webster's 1828, cross references) are used.
```

## Export compliance

`ITSAppUsesNonExemptEncryption` is `NO` in the app's Info.plist, so App Store Connect won't ask.

## Family Controls

Each Screen Time extension is its own bundle ID and needs Apple's **Family Controls (Distribution)** entitlement before App Store profiles for it include Family Controls. Without it, `flutter build ipa` stops at signing: the extensions ask for an entitlement their profiles don't carry. Development builds aren't affected.

| Bundle ID | Distribution entitlement |
| --- | --- |
| `com.dailykjb.dailyKjb` | Approved |
| `com.dailykjb.dailyKjb.ShieldConfiguration` | Request |
| `com.dailykjb.dailyKjb.ShieldAction` | Request |
| `com.dailykjb.dailyKjb.DeviceActivityMonitor` | Request |

1. As the team's Account Holder, open <https://developer.apple.com/contact/request/family-controls-distribution>.
2. Send one request per extension bundle ID, saying:

   > Daily KJB (com.dailykjb.dailyKjb, already approved for Family Controls distribution) is a Bible reading app. Its Focus Mode lets the device's own user choose apps to keep shielded each day until they've done their daily reading, using FamilyControls with .individual authorization. This bundle ID is the app's [Shield Configuration / Shield Action / Device Activity Monitor] extension: [it draws the shield's text and colors / it handles the shield's buttons, posting a local notification that opens Daily KJB / it re-applies the shields at the start of each day from a DeviceActivity schedule]. It reads only the opaque tokens the user chose and sends nothing off the device.

3. Apple answers by email, usually within two weeks. Once approved, signing is automatic: Xcode makes App Store profiles that include it, and nothing in the project changes.
