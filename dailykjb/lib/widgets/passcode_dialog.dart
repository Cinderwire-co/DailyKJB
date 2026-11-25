import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../ui/kit.dart';
import '../ui/theme.dart';

/// Dialog modes for the passcode entry
enum PasscodeMode {
  setup, // Setting up a new passcode (enter + confirm)
  verify, // Verifying an existing passcode
}

/// Shows a passcode dialog and returns the entered passcode on success, or
/// null on cancel.
Future<String?> showPasscodeDialog({
  required BuildContext context,
  required PasscodeMode mode,
  String? title,
  String? subtitle,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _PasscodeDialog(mode: mode, title: title, subtitle: subtitle),
  );
}

class _PasscodeDialog extends StatefulWidget {
  final PasscodeMode mode;
  final String? title;
  final String? subtitle;

  const _PasscodeDialog({required this.mode, this.title, this.subtitle});

  @override
  State<_PasscodeDialog> createState() => _PasscodeDialogState();
}

class _PasscodeDialogState extends State<_PasscodeDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _firstEntry;
  bool _isConfirming = false;
  String? _errorText;

  String get _title {
    if (widget.title != null && !_isConfirming) return widget.title!;
    if (widget.mode == PasscodeMode.setup) {
      return _isConfirming
          ? 'Confirm the passcode'
          : 'An accountability passcode';
    }
    return 'Enter the passcode';
  }

  String get _subtitle {
    if (widget.subtitle != null && !_isConfirming) return widget.subtitle!;
    if (widget.mode == PasscodeMode.setup) {
      return _isConfirming
          ? 'Enter the same four digits again.'
          : 'Have someone who keeps you accountable enter four digits. Focus Mode can\'t be turned off without them.';
    }
    return 'Enter the four-digit accountability passcode.';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSubmit(String value) {
    if (value.length != 4) {
      setState(() => _errorText = 'Four digits, please');
      return;
    }
    if (widget.mode == PasscodeMode.verify) {
      Navigator.of(context).pop(value);
      return;
    }
    if (!_isConfirming) {
      setState(() {
        _firstEntry = value;
        _isConfirming = true;
        _errorText = null;
        _controller.clear();
      });
      _focusNode.requestFocus();
    } else if (value == _firstEntry) {
      Navigator.of(context).pop(value);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorText = 'Those didn\'t match. Start again.';
        _isConfirming = false;
        _firstEntry = null;
        _controller.clear();
      });
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    return Dialog(
      backgroundColor: p.leaf,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: p.rule),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.lock_fill, size: 34, color: p.accent),
            const SizedBox(height: 14),
            Text(_title, textAlign: TextAlign.center, style: p.title(18)),
            const SizedBox(height: 8),
            Text(_subtitle, textAlign: TextAlign.center, style: p.small),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () => _focusNode.requestFocus(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _controller.text.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.symmetric(horizontal: 9),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? p.accent : Colors.transparent,
                      border: Border.all(
                        color: filled ? p.accent : p.rule,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),
            // The field itself, out of sight: the dots show it
            SizedBox(
              width: 1,
              height: 1,
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    setState(() => _errorText = null);
                    if (v.length == 4) _onSubmit(v);
                  },
                ),
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(_errorText!, style: p.small.copyWith(color: p.danger)),
            ],
            const SizedBox(height: 14),
            ParchButton(
              'Cancel',
              kind: Btn.quiet,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
