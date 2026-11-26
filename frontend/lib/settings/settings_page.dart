import 'package:flutter/cupertino.dart';

import '../auth/ReSetPage.dart';
import '../shared/food_style.dart';
import 'me_detail_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final signInEmail = email?.trim() ?? '';
    return MeDetailPage(
      title: 'Settings',
      children: [
        Semantics(
          header: true,
          child: const Text(
            'Account',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        MeDetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row(
                icon: CupertinoIcons.envelope,
                label: 'Sign-in email',
                detail: signInEmail.isEmpty ? 'Unavailable' : signInEmail,
              ),
              _divider,
              CupertinoButton(
                key: const Key('settings-reset-password'),
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).push<void>(
                  CupertinoPageRoute(
                    builder: (_) => ResetPage(
                      initialEmail: signInEmail,
                      fromSettings: true,
                    ),
                  ),
                ),
                child: _row(
                  icon: CupertinoIcons.lock,
                  label: 'Reset password',
                  trailing: _chevron,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const _chevron = Icon(
    CupertinoIcons.chevron_right,
    size: 16,
    color: FoodStyle.forest,
  );
  static const _divider = Padding(
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: SizedBox(height: 1, child: ColoredBox(color: Color(0xFFE2E8DF))),
  );

  Widget _row({
    required IconData icon,
    required String label,
    String? detail,
    Widget? trailing,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: FoodStyle.pale,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 24, color: FoodStyle.forest),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  color: FoodStyle.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 15, color: FoodStyle.forest),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing],
      ],
    ),
  );
}
