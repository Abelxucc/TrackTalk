import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable;

import '../shared/food_chrome.dart' show VoiceInputStatus;
import '../shared/food_style.dart';
import 'food_chat.dart' show FoodChatAppearance;

class VoiceRecordingOverlay extends StatelessWidget {
  const VoiceRecordingOverlay({
    super.key,
    required this.status,
    required this.level,
    required this.canceling,
    this.onCancel,
    this.onTranscribe,
  });

  final VoiceInputStatus status;
  final ValueListenable<double> level;
  final bool canceling;
  final VoidCallback? onCancel;
  final VoidCallback? onTranscribe;

  @override
  Widget build(BuildContext context) {
    final opening = status == VoiceInputStatus.opening;
    final limitReached = status == VoiceInputStatus.limitReached;
    final swipe = onCancel == null;
    final accent = canceling ? const Color(0xFF9B3337) : FoodStyle.forest;
    final title = switch (status) {
      _ when canceling => 'Release to cancel',
      VoiceInputStatus.opening || VoiceInputStatus.limitReached => status.label,
      _ => swipe ? 'Release to transcribe' : 'Recording…',
    };
    final hint = canceling
        ? (limitReached
              ? 'Slide down to keep the clip'
              : 'Slide down to keep recording')
        : (limitReached
              ? 'Release to transcribe or slide up to cancel'
              : 'Slide up to cancel');

    return Stack(
      fit: StackFit.expand,
      children: [
        const ModalBarrier(color: Color(0x7116201A), dismissible: false),
        SafeArea(
          minimum: const EdgeInsets.all(22),
          child: Align(
            alignment: const Alignment(0, .26),
            child: SingleChildScrollView(
              child: FoodChatAppearance(
                distance: 12,
                child: SizedBox(
                  width: 284,
                  child: FoodStyle.card(
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _VoiceSignal(
                          level: level,
                          accent: accent,
                          canceling: canceling,
                        ),
                        const SizedBox(height: 14),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: canceling ? accent : FoodStyle.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (swipe) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                canceling
                                    ? CupertinoIcons.arrow_down
                                    : CupertinoIcons.arrow_up,
                                size: 14,
                                color: accent,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  hint,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: accent, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            children: [
                              CupertinoButton(
                                onPressed: onCancel,
                                child: const Text('Cancel'),
                              ),
                              FoodStyle.primary(
                                onPressed: opening ? null : onTranscribe,
                                child: const Text('Transcribe'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VoiceSignal extends StatelessWidget {
  const _VoiceSignal({
    required this.level,
    required this.accent,
    required this.canceling,
  });

  final ValueListenable<double> level;
  final Color accent;
  final bool canceling;

  static const _heights = [
    7.0,
    11.0,
    20.0,
    14.0,
    24.0,
    19.0,
    27.0,
    17.0,
    22.0,
    14.0,
    18.0,
    10.0,
    7.0,
  ];

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120);
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: duration,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 50,
        decoration: BoxDecoration(
          color: canceling ? const Color(0xFFF7E5E1) : FoodStyle.pale,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              canceling ? CupertinoIcons.xmark : CupertinoIcons.mic_fill,
              color: accent,
              size: 18,
            ),
            const SizedBox(width: 12),
            ValueListenableBuilder<double>(
              valueListenable: level,
              builder: (context, value, _) => TweenAnimationBuilder<double>(
                tween: Tween(end: value),
                duration: duration,
                builder: (context, level, _) => Row(
                  children: [
                    for (final height in _heights)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.4),
                        width: 3,
                        height: 4 + height * (.18 + .82 * level),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
