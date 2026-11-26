import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'profile/profile_avatar.dart';
import 'registration/profile_details.dart';
import 'shared/food_style.dart';

class HomeGreeting extends StatefulWidget {
  const HomeGreeting({
    super.key,
    required this.profile,
    required this.now,
    required this.active,
  });

  final Future<AccountProfile?> profile;
  final DateTime Function() now;
  final bool active;

  @override
  State<HomeGreeting> createState() => _HomeGreetingState();
}

class _HomeGreetingState extends State<HomeGreeting> {
  static const _greetings = [
    (hour: 5, text: 'Good morning'),
    (hour: 12, text: 'Good afternoon'),
    (hour: 18, text: 'Good evening'),
    (hour: 22, text: 'Good night'),
  ];
  static const _headingStyle = TextStyle(
    color: FoodStyle.ink,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.15,
  );

  late final AppLifecycleListener _lifecycle;
  Timer? _nextGreeting;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _scheduleRefresh();
  }

  @override
  void didUpdateWidget(HomeGreeting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active || widget.now != oldWidget.now) {
      _scheduleRefresh();
    }
  }

  @override
  void dispose() {
    _nextGreeting?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!widget.active) return;
    setState(() {});
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    _nextGreeting?.cancel();
    if (!widget.active) return;

    final now = widget.now().toLocal();
    final nextHour = _greetings
        .firstWhere(
          (greeting) => greeting.hour > now.hour,
          orElse: () => _greetings.first,
        )
        .hour;
    final day = nextHour <= now.hour ? now.day + 1 : now.day;
    final next = DateTime(now.year, now.month, day, nextHour);
    _nextGreeting = Timer(next.difference(now), _refresh);
  }

  @override
  Widget build(BuildContext context) {
    final hour = widget.now().toLocal().hour;
    final greeting = _greetings
        .lastWhere(
          (greeting) => greeting.hour <= hour,
          orElse: () => _greetings.last,
        )
        .text;
    return FutureBuilder<AccountProfile?>(
      future: widget.profile,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?.name.trim() ?? '';
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? greeting : '$greeting,',
                    style: _headingStyle,
                  ),
                  if (name.isNotEmpty)
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _headingStyle,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ProfileAvatar(photo: profile?.photo, size: 70),
          ],
        );
      },
    );
  }
}
