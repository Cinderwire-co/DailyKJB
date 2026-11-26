#!/bin/zsh
# App Store screenshots from the simulator. Each scene is opened with demo data
# (lib/screenshots.dart) by putting "scene theme" in the app's Documents/screenshot.txt.
#
#   (cd dailykjb && flutter build ios --simulator --debug)
#   tools/screenshots.sh <simulator-udid> <iphone|ipad> <raw-dir>
#   tools/.venv/bin/python tools/frame_screenshots.py <raw-dir> <iphone|iphone-6.3|ipad> store/screenshots/<iphone-6.9|iphone-6.3|ipad-13>
#
# Simulators: iPhone 18 Pro Max (6.9", 1320x2868), iPhone 18 Pro (6.3", 1206x2622) and
# iPad Pro 13-inch (2064x2752). App Store Connect requires the 6.3" and iPad 13" sets.
# The locked-app shield can't be captured (Screen Time doesn't run in the simulator): tools/shield_shot.swift draws it,
# and its shield-<size>.png goes into the raw folder as shield.png.
# frame_screenshots.py needs Pillow and numpy:
#   python3 -m venv tools/.venv && tools/.venv/bin/pip install pillow numpy
set -e
cd "$(dirname "$0")/.."
SIM=$1; KIND=$2; OUT=$3
APP=dailykjb/build/ios/iphonesimulator/Runner.app
mkdir -p $OUT
xcrun simctl boot $SIM 2>/dev/null || true
xcrun simctl bootstatus $SIM -b >/dev/null
xcrun simctl status_bar $SIM override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 \
  --cellularMode active --cellularBars 4 --dataNetwork wifi --operatorName ""
xcrun simctl install $SIM $APP
shot() { # scene theme name wait
  xcrun simctl terminate $SIM com.dailykjb.dailyKjb >/dev/null 2>&1 || true
  DATA=$(xcrun simctl get_app_container $SIM com.dailykjb.dailyKjb data)
  mkdir -p "$DATA/Documents" && echo "$1 $2" > "$DATA/Documents/screenshot.txt"
  xcrun simctl launch $SIM com.dailykjb.dailyKjb >/dev/null
  sleep $4
  xcrun simctl io $SIM screenshot $OUT/$3.png >/dev/null && echo $OUT/$3.png
}
shot today light 01-today 12
shot bible light 02-bible 12
shot word light 03-word 22        # waits for Apple Intelligence, where the Mac has it
[[ $KIND == iphone ]] && shot notes light 04-notes 45
shot reading light 05-reading 9
shot journal light 06-journal 9
shot progress light 07-progress 9
shot focus light 08-focus 9
shot bible dark 09-bible-dark 12
[[ $KIND == iphone ]] && shot share light 10-share 9
# Leave the app as it was: no scene next launch
rm -f "$(xcrun simctl get_app_container $SIM com.dailykjb.dailyKjb data)/Documents/screenshot.txt"
