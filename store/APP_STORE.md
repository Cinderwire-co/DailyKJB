# App Store listing: Daily KJB 1.1

Everything to enter in App Store Connect, field by field. Character counts are checked against Apple's limits.

## Before you submit

1. **Signing.** Put your Apple Developer Team ID in `dailykjb/ios/Flutter/Signing.xcconfig` (copy the `.example` next to it). The file is git-ignored.
2. **Family Controls.** Focus Mode uses Apple's Screen Time. The app and its three extensions each need Family Controls (Distribution) ticked on their identifiers; all four are. See [Family Controls](#family-controls) below.
3. **Build numbers.** Every upload needs a higher build number: `version: 1.1.0+24` in `dailykjb/pubspec.yaml` means 1.1.0 (24), the latest uploaded (22 had no widgets; 23 has the widgets but clips the verse of the day's buttons on 6.3" iPhones). Every new upload needs a higher number. The extensions take their version and build number from it.
4. **Upload a build:**
   ```bash
   cd dailykjb && flutter build ipa --release && cd ..
   tools/upload_ios.sh
   ```
   `flutter build ipa` may end with "exportArchive Copy failed": that's a Homebrew `rsync` on the PATH, the archive is fine, and the upload script exports with the system tools. The script uploads with the Apple ID signed in to Xcode. If it says "Failed to Use Accounts", sign in again in Xcode > Settings > Accounts, or drag the `.ipa` from `dailykjb/build/ios/ipa/` into Transporter and choose Deliver. The build appears under TestFlight after processing (usually 10 to 30 minutes).

## App information

| Field | Value |
| --- | --- |
| Name (30) | `Daily KJB: King James Bible` (27) |
| Subtitle (30) | `Accountability Bible reading` (28) |
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
kjv,king james,bible,accountability,screen time,focus,reading plan,devotional,strongs,webster 1828
```

**Promotional text (170):**

```
An accountability Bible reading app: your chosen apps stay locked each day until you've read. The King James Bible, reading plans and word study, all offline.
```

**Description:** in `store/description.txt`.

**What's New in 1.1.0:**

```
A new Daily KJB.
• A warm new look: parchment by day, lamplight by night
• The Bible turns like a book, a chapter to a page
• Tap any word for Strong's Hebrew and Greek and Webster's 1828, all offline
• Study notes, plain-English meanings and quizzes from Apple Intelligence, on your iPhone
• Widgets for your home screen and lock screen: today's reading and the verse for today
• Focus Mode now closes your chosen apps again each midnight, even if Daily KJB isn't opened
• New Testament plan fixed for passages that cross chapters and books
• The two-year plan now has reading every day
• Many smaller fixes
```

## Version number

The builds are `1.1.0`. If the version page in App Store Connect says `1.0`, the builds won't appear under Build: change the version on that page to `1.1.0`.

## Header and search results (Product Page Information)

Made by `tools/make_banners.py` into `store/marketing/`. They lead with what Daily KJB is: an accountability Bible reading app, with the locked-app shield in front.

| Tab | File | Spec |
| --- | --- | --- |
| Header | `header-3840x1646.png` | 21:9, 3840 × 1646 |
| Search Results | `search-3840x2560.png` | 3:2, 3840 × 2560 |
| Either | `universal-5244x2950.png` | 16:9, 5244 × 2950; accepted for both |

In App Store Connect: the version page > Product Page Information > Header and Search Results. Pick Header or Search Results, then Upload.

## Screenshots

Required: **iPhone 6.3"** and **iPad 13"**. The 6.9" set is optional; App Store Connect doesn't fill the 6.3" slot from it. Upload in this order: the first three show in search results, so they lead with accountability.

| Order | Caption | iPhone 6.3" (1206 × 2622) | iPhone 6.9" (1320 × 2868) | iPad 13" (2064 × 2752) |
| --- | --- | --- | --- | --- |
| 1 | An accountability Bible reading app | `iphone-6.3/01-focus.jpg` | `iphone-6.9/01-focus.jpg` | `ipad-13/01-focus.jpg` |
| 2 | Your Bible before your apps | `iphone-6.3/02-shield.jpg` | `iphone-6.9/02-shield.jpg` | `ipad-13/02-shield.jpg` |
| 3 | A little of the Word, every day | `iphone-6.3/03-today.jpg` | `iphone-6.9/03-today.jpg` | `ipad-13/03-today.jpg` |
| 4 | Read it, or prove it | `iphone-6.3/04-reading.jpg` | `iphone-6.9/04-reading.jpg` | `ipad-13/04-reading.jpg` |
| 5 | Turn the page, chapter to chapter | `iphone-6.3/05-bible.jpg` | `iphone-6.9/05-bible.jpg` | `ipad-13/05-bible.jpg` |
| 6 | Back to the Hebrew and Greek | `iphone-6.3/06-word.jpg` | `iphone-6.9/06-word.jpg` | `ipad-13/06-word.jpg` |
| 7 | Study notes, written on your iPhone | `iphone-6.3/07-notes.jpg` | `iphone-6.9/07-notes.jpg` | |
| 8 | Watch the year take shape | `iphone-6.3/08-progress.jpg` | `iphone-6.9/08-progress.jpg` | `ipad-13/08-progress.jpg` |
| 9 | Parchment by day, lamplight by night | `iphone-6.3/09-bible-dark.jpg` | `iphone-6.9/09-bible-dark.jpg` | `ipad-13/09-bible-dark.jpg` |
| 10 | Everything you noted, in one place | `iphone-6.3/10-journal.jpg` | `iphone-6.9/10-journal.jpg` | `ipad-13/10-journal.jpg` |

They're generated: `tools/screenshots.sh` opens the simulator at staged screens with demo data, `tools/shield_shot.swift` draws the locked-app shield (Screen Time doesn't run in the simulator; its words and colors are the app's own), and `tools/frame_screenshots.py` puts each in its device, Dynamic Island and all, with its caption.

## App Review notes

No sign-in is needed. Paste into App Review Information > Notes:

```
Daily KJB is a King James Bible reading app. No account or sign-in is needed; all content is built into the app and works offline.

FOCUS MODE (Screen Time / Family Controls)
Focus Mode lets the person using the device choose apps to keep shielded each day until they have completed that day's Bible reading. It uses FamilyControls with .individual authorization, ManagedSettings to shield the chosen apps, and a DeviceActivity schedule (midnight to midnight) whose monitor extension re-applies the shields at the start of each day. The shield's "Read now" button opens Daily KJB at the day's reading (on iOS earlier than 26.5, it posts a notification that does).

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

Focus Mode uses Apple's Screen Time, and every bundle that touches it needs Apple's **Family Controls (Distribution)** entitlement for App Store builds. The team is approved. Each identifier must also have the capability ticked, or its App Store profile leaves Family Controls out and `flutter build ipa` stops at signing ("Provisioning profile … doesn't include the com.apple.developer.family-controls entitlement"). Development builds aren't affected.

| Bundle ID | Family Controls (Distribution) |
| --- | --- |
| `com.dailykjb.dailyKjb` | Ticked |
| `com.dailykjb.dailyKjb.ShieldConfiguration` | Ticked |
| `com.dailykjb.dailyKjb.ShieldAction` | Ticked |
| `com.dailykjb.dailyKjb.DeviceActivityMonitor` | Ticked |

To check or add one: developer.apple.com > Certificates, Identifiers & Profiles > Identifiers > the bundle ID > Capabilities (or Additional Capabilities) > Family Controls (Distribution) > Save. A new extension needs the same before its first App Store build.

If an export still says the entitlement is missing after ticking, Xcode is using an App Store profile made before the change. Move the `iOS Team Store Provisioning Profile: com.dailykjb…` files out of `~/Library/Developer/Xcode/UserData/Provisioning Profiles` and export again; Xcode fetches new ones.
