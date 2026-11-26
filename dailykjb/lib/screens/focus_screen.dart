import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../screenshots.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import '../widgets/passcode_dialog.dart';

/// Focus Mode: apps the reader chooses stay closed each day until the day's
/// reading is done. On iPhone this is Apple's Screen Time (the app never
/// learns which apps were chosen); on Android, usage access and an overlay.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  bool _supported = true, _authorized = false;
  int _apps = 0;
  bool _loaded = false;
  // Back from Android's Settings, where the permissions are given
  late final AppLifecycleListener _resume;

  @override
  void initState() {
    super.initState();
    _resume = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  @override
  void dispose() {
    _resume.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final s = context.read<AppProvider>().appBlockingService;
    final supported = await s.isSupported();
    final authorized = supported && await s.isAuthorized();
    final apps = supported ? await s.selectedAppCount() : 0;
    if (!mounted) return;
    // Screenshots: the simulator can't grant Screen Time; show it set up
    final shot = Screenshots.scene == 'focus';
    setState(() {
      _supported = supported || shot;
      _authorized = authorized || shot;
      _apps = shot ? 7 : apps;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    final prov = context.watch<AppProvider>();
    final on = prov.userData?.appBlockingEnabled ?? false;
    return Leaf(
      title: 'Focus Mode',
      body: !_loaded
          ? const Waiting()
          : ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                22,
                20,
                MediaQuery.paddingOf(context).bottom + 40,
              ),
              children: [
                Center(
                  child: Icon(
                    CupertinoIcons.lock_shield_fill,
                    size: 52,
                    color: p.accent,
                  ),
                ),
                const SizedBox(height: 12),
                Center(child: Text('The Word first', style: p.title(22))),
                const SizedBox(height: 8),
                Text(
                  'Choose the apps that pull you away. Each day they stay closed until you\'ve read, then open the moment your reading is marked read. At midnight they close again.',
                  textAlign: TextAlign.center,
                  style: p.body.copyWith(color: p.faded),
                ),
                const SizedBox(height: 22),
                if (!_supported)
                  Panel(
                    child: Text(
                      Platform.isIOS
                          ? 'Focus Mode needs iOS 16 or later.'
                          : 'Focus Mode isn\'t available on this device.',
                      style: p.body,
                    ),
                  )
                else ...[
                  Panel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        RowLink(
                          icon: _authorized
                              ? CupertinoIcons.checkmark_shield_fill
                              : CupertinoIcons.shield,
                          title: Platform.isIOS
                              ? 'Screen Time access'
                              : 'Permissions',
                          subtitle: _authorized
                              ? 'Allowed'
                              : 'Needed to keep apps closed',
                          onTap: _authorized ? null : () => _authorize(context),
                        ),
                        const Hairline(),
                        RowLink(
                          icon: CupertinoIcons.square_grid_2x2,
                          title: 'Apps to keep closed',
                          subtitle: _apps == 0
                              ? 'None chosen yet'
                              : Platform.isIOS
                              ? (_apps == 1
                                    ? '1 app or category'
                                    : '$_apps apps and categories')
                              : (_apps == 1 ? '1 app' : '$_apps apps'),
                          onTap: () => _choose(context),
                        ),
                        const Hairline(),
                        SwitchLine(
                          icon: CupertinoIcons.lock_fill,
                          title: 'Focus Mode',
                          subtitle: on
                              ? (prov.isTodayComplete()
                                    ? 'On · today\'s apps are open'
                                    : 'On · closed until you read')
                              : 'Off',
                          value: on,
                          onChanged: (v) => _toggle(context, v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Panel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        RowLink(
                          icon: CupertinoIcons.person_2_fill,
                          title: prov.hasAccountabilityPasscode
                              ? 'Change the passcode'
                              : 'Set an accountability passcode',
                          subtitle: 'Someone you trust keeps it; Focus Mode can\'t be turned off without it',
                          onTap: () => _setPasscode(context),
                        ),
                        if (prov.hasAccountabilityPasscode) ...[
                          const Hairline(),
                          RowLink(
                            icon: CupertinoIcons.lock_open,
                            title: 'Remove the passcode',
                            onTap: () => _removePasscode(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Label('How it works'),
                  const SizedBox(height: 8),
                  for (final (icon, text) in [
                    (
                      CupertinoIcons.sunrise,
                      'At midnight, the apps you chose close.',
                    ),
                    (
                      CupertinoIcons.book,
                      'Open DailyKJB and read the day\'s chapters. With Focus Mode on, the reading asks for a little time before it can be marked read.',
                    ),
                    (
                      CupertinoIcons.checkmark_seal,
                      'Mark it read, or pass the quiz, and the apps open at once.',
                    ),
                    (
                      CupertinoIcons.hand_raised,
                      Platform.isIOS
                          ? 'Apple\'s Screen Time keeps your choices private: DailyKJB never sees which apps they are.'
                          : 'Usage access only tells DailyKJB which app is open, to cover the ones you chose. It stays on this phone.',
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, size: 19, color: p.accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              text,
                              style: p.body.copyWith(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Future<bool> _authorize(BuildContext context) async {
    final ok = await requestFocusAccess(context);
    await _refresh();
    if (!ok && context.mounted) {
      toast(
        context,
        Platform.isIOS
            ? 'Screen Time access is needed for Focus Mode.'
            : 'Allow Usage Access and Display Over Other Apps, then try again.',
        error: true,
      );
    }
    return ok;
  }

  Future<void> _choose(BuildContext context) async {
    if (!_authorized && !await _authorize(context)) return;
    if (!context.mounted) return;
    await chooseBlockedApps(context);
    await _refresh();
  }

  Future<void> _toggle(BuildContext context, bool value) async {
    final prov = context.read<AppProvider>();
    if (value) {
      if (!_authorized && !await _authorize(context)) return;
      if (!context.mounted) return;
      if (_apps == 0) {
        await chooseBlockedApps(context);
        await _refresh();
        if (_apps == 0) return;
      }
      if (!context.mounted) return;
      if (!prov.hasAccountabilityPasscode) {
        final code = await showPasscodeDialog(
          context: context,
          mode: PasscodeMode.setup,
        );
        if (code != null) await prov.setAccountabilityPasscode(code);
      }
    } else if (prov.hasAccountabilityPasscode) {
      final code = await showPasscodeDialog(
        context: context,
        mode: PasscodeMode.verify,
        title: 'Accountability check',
        subtitle: 'Enter the passcode to turn Focus Mode off.',
      );
      if (code == null) return;
      if (!prov.verifyAccountabilityPasscode(code)) {
        if (context.mounted) {
          toast(context, 'That isn\'t the passcode', error: true);
        }
        return;
      }
      await prov.clearAccountabilityPasscode();
    }
    await prov.toggleAppBlocking(value);
  }

  Future<void> _setPasscode(BuildContext context) async {
    final prov = context.read<AppProvider>();
    if (prov.hasAccountabilityPasscode) {
      final code = await showPasscodeDialog(
        context: context,
        mode: PasscodeMode.verify,
        title: 'The current passcode',
        subtitle: 'Enter it before setting a new one.',
      );
      if (code == null) return;
      if (!prov.verifyAccountabilityPasscode(code)) {
        if (context.mounted) {
          toast(context, 'That isn\'t the passcode', error: true);
        }
        return;
      }
    }
    if (!context.mounted) return;
    final code = await showPasscodeDialog(
      context: context,
      mode: PasscodeMode.setup,
    );
    if (code != null) {
      await prov.setAccountabilityPasscode(code);
      if (context.mounted) toast(context, 'Passcode set');
    }
  }

  Future<void> _removePasscode(BuildContext context) async {
    final prov = context.read<AppProvider>();
    final code = await showPasscodeDialog(
      context: context,
      mode: PasscodeMode.verify,
      title: 'Remove the passcode',
      subtitle: 'Enter it to remove it.',
    );
    if (code == null) return;
    if (!prov.verifyAccountabilityPasscode(code)) {
      if (context.mounted) {
        toast(context, 'That isn\'t the passcode', error: true);
      }
      return;
    }
    await prov.clearAccountabilityPasscode();
    if (context.mounted) toast(context, 'Passcode removed');
  }
}

/// What Focus Mode needs: Screen Time on iPhone; on Android, usage access and
/// display over other apps, each said plainly before Settings opens.
Future<bool> requestFocusAccess(BuildContext context) async {
  final service = context.read<AppProvider>().appBlockingService;
  if (Platform.isAndroid && !await service.isAuthorized()) {
    if (!context.mounted) return false;
    final go = await sure(
      context,
      'Two permissions',
      ok: 'Open Settings',
      text:
          'Usage access lets DailyKJB see which app is open, so it can cover the apps you chose until you\'ve read. '
          'Display over other apps lets it show that cover. Nothing it sees is kept, and nothing leaves this phone.',
    );
    if (!go) return false;
  }
  return service.requestAuthorization();
}

/// The apps to keep closed: Apple's own picker on iPhone; a list on Android.
/// Returns how many are chosen.
Future<int> chooseBlockedApps(BuildContext context) async {
  final prov = context.read<AppProvider>();
  final service = prov.appBlockingService;
  var count = 0;
  if (Platform.isIOS) {
    final r = await service.showAppPicker();
    count = r is int ? r : 0;
  } else if (Platform.isAndroid) {
    final apps = await service.showAppPicker();
    if (apps is! List || !context.mounted) return 0;
    final picked = await _androidPicker(
      context,
      apps.cast<Map<String, String>>(),
    );
    if (picked == null) return service.selectedAppCount();
    count = await service.setBlockedPackages(picked);
  }
  // Already on and today not read: close the new choices now
  if (count > 0 &&
      (prov.userData?.appBlockingEnabled ?? false) &&
      !prov.isTodayComplete()) {
    await service.enableBlocking();
  }
  return count;
}

Future<List<String>?> _androidPicker(
  BuildContext context,
  List<Map<String, String>> apps,
) {
  final selected = <String>{
    for (final a in apps)
      if (a['isBlocked'] == 'true') a['packageName']!,
  };
  return sheet<List<String>>(
    context,
    title: 'Apps to keep closed',
    actions: [
      Builder(
        builder: (ctx) => ParchButton(
          'Done',
          small: true,
          kind: Btn.solid,
          onTap: () => Navigator.pop(ctx, selected.toList()),
        ),
      ),
    ],
    body: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final p = ctx.parch;
        return Column(
          children: [
            for (final a in apps)
              Tap(
                onTap: () => set(() {
                  final id = a['packageName']!;
                  if (!selected.remove(id)) selected.add(id);
                }),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      selected.contains(a['packageName'])
                          ? CupertinoIcons.checkmark_square_fill
                          : CupertinoIcons.square,
                      color: selected.contains(a['packageName'])
                          ? p.accent
                          : p.faded,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(a['appName'] ?? '', style: p.body)),
                    if (a['isSuggested'] == 'true')
                      Text(
                        'Suggested',
                        style: p.small.copyWith(color: p.accent),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}
