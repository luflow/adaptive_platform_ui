import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:interval_time_picker/interval_time_picker.dart';
// The main library imports but doesn't re-export the VisibleStep enum, so pull
// it in directly to name the dial-label density.
import 'package:interval_time_picker/models/visible_step.dart';
import '../platform/platform_info.dart';
import 'minute_interval.dart';

/// An adaptive time picker that renders platform-specific styles
///
/// On iOS: Shows CupertinoTimerPicker in a modal bottom sheet
/// On Android: Shows Material TimePickerDialog
class AdaptiveTimePicker {
  AdaptiveTimePicker._();

  /// Shows a platform-adaptive time picker
  ///
  /// Returns the selected [TimeOfDay] or null if cancelled
  static Future<TimeOfDay?> show({
    required BuildContext context,
    required TimeOfDay initialTime,
    bool use24HourFormat = false,
    int minuteInterval = 1,
  }) async {
    if (PlatformInfo.isIOS) {
      return _showCupertinoTimePicker(
        context: context,
        initialTime: initialTime,
        use24HourFormat: use24HourFormat,
        minuteInterval: minuteInterval,
      );
    }

    // Android - Use Material TimePicker
    return _showMaterialTimePicker(
      context: context,
      initialTime: initialTime,
      use24HourFormat: use24HourFormat,
      minuteInterval: minuteInterval,
    );
  }

  static Future<TimeOfDay?> _showCupertinoTimePicker({
    required BuildContext context,
    required TimeOfDay initialTime,
    required bool use24HourFormat,
    required int minuteInterval,
  }) async {
    // Convert TimeOfDay to DateTime for CupertinoDatePicker; align onto the
    // grid first, as the picker asserts the initial value is a valid interval.
    final now = DateTime.now();
    DateTime selectedDateTime = alignDateTimeToInterval(
      DateTime(now.year, now.month, now.day, initialTime.hour, initialTime.minute),
      minuteInterval,
    );

    final result = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return _CupertinoTimePickerContent(
          initialDateTime: selectedDateTime,
          use24HourFormat: use24HourFormat,
          minuteInterval: minuteInterval,
          onTimeSelected: (dateTime) => selectedDateTime = dateTime,
        );
      },
    );

    if (result != null) {
      return TimeOfDay(
        hour: selectedDateTime.hour,
        minute: selectedDateTime.minute,
      );
    }
    return null;
  }

  static Future<TimeOfDay?> _showMaterialTimePicker({
    required BuildContext context,
    required TimeOfDay initialTime,
    required bool use24HourFormat,
    required int minuteInterval,
  }) async {
    final builder = use24HourFormat
        ? (BuildContext ctx, Widget? child) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            )
        : null;

    // No stepping requested → the plain Material picker (every minute).
    if (minuteInterval <= 1) {
      return showTimePicker(
        context: context,
        initialTime: initialTime,
        builder: builder,
      );
    }

    // Genuine stepped Material dial: only the interval minutes are selectable
    // while picking — no post-hoc rounding. showIntervalTimePicker is a fork of
    // Flutter's own time picker, so it inherits Material 3 theming and the
    // keyboard input mode. It keeps an off-grid initial minute as-is, so align
    // the initial value first.
    return showIntervalTimePicker(
      context: context,
      initialTime: alignTimeOfDayToInterval(initialTime, minuteInterval),
      interval: minuteInterval,
      visibleStep: _visibleStepForInterval(minuteInterval),
      builder: builder,
    );
  }

  /// Map a minute interval to the matching dial-label density. Falls back to
  /// 5-minute labels for intervals without a dedicated step.
  static VisibleStep _visibleStepForInterval(int interval) {
    switch (interval) {
      case 6:
        return VisibleStep.sixths;
      case 10:
        return VisibleStep.tenths;
      case 12:
        return VisibleStep.twelfths;
      case 15:
        return VisibleStep.fifteenths;
      case 20:
        return VisibleStep.twentieths;
      case 30:
        return VisibleStep.thirtieths;
      case 60:
        return VisibleStep.sixtieth;
      case 5:
      default:
        return VisibleStep.fifths;
    }
  }
}

/// Internal widget that properly updates when theme changes
class _CupertinoTimePickerContent extends StatefulWidget {
  const _CupertinoTimePickerContent({
    required this.initialDateTime,
    required this.use24HourFormat,
    required this.minuteInterval,
    required this.onTimeSelected,
  });

  final DateTime initialDateTime;
  final bool use24HourFormat;
  final int minuteInterval;
  final ValueChanged<DateTime> onTimeSelected;

  @override
  State<_CupertinoTimePickerContent> createState() =>
      _CupertinoTimePickerContentState();
}

class _CupertinoTimePickerContentState
    extends State<_CupertinoTimePickerContent> {
  late DateTime selectedDateTime;

  @override
  void initState() {
    super.initState();
    selectedDateTime = widget.initialDateTime;
  }

  @override
  Widget build(BuildContext context) {
    // Use CupertinoTheme to get dynamic colors that update with theme changes
    final backgroundColor = CupertinoTheme.of(context).scaffoldBackgroundColor;
    final separatorColor = CupertinoDynamicColor.resolve(
      CupertinoColors.separator,
      context,
    );

    return Container(
      height: 280,
      color: backgroundColor,
      child: Column(
        children: [
          // Header with Done button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: separatorColor, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    PlatformInfo.isIOS
                        ? CupertinoLocalizations.of(context).cancelButtonLabel
                        : MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(context).pop(selectedDateTime),
                  child: Text(
                    MaterialLocalizations.of(context).okButtonLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          // Time picker
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: widget.use24HourFormat,
              minuteInterval: widget.minuteInterval,
              initialDateTime: widget.initialDateTime,
              onDateTimeChanged: (DateTime newDateTime) {
                setState(() {
                  selectedDateTime = newDateTime;
                });
                widget.onTimeSelected(newDateTime);
              },
            ),
          ),
        ],
      ),
    );
  }
}
