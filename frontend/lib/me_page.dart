import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

import 'profile/profile_avatar.dart';
import 'registration/profile_details.dart';
import 'shared/food_style.dart';

class MePage extends StatelessWidget {
  const MePage({
    super.key,
    required this.onEditProfile,
    required this.onSettings,
    required this.onAbout,
    required this.onSignOut,
    this.profile,
    this.signingOut = false,
    this.error,
  });

  final VoidCallback onEditProfile;
  final VoidCallback onSettings;
  final VoidCallback onAbout;
  final VoidCallback onSignOut;
  final AccountProfile? profile;
  final bool signingOut;
  final String? error;

  static const _cardRadius = BorderRadius.all(Radius.circular(18));
  static const _avatarSize = 66.0;
  static const _labelInset = 87.0;
  static const _rowGap = SizedBox(height: 10);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, 0),
        child: Text(
          'Me',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          children: [
            _profileCard(),
            _rowGap,
            _menuItem(
              'Settings',
              CupertinoIcons.gear_alt,
              onPressed: onSettings,
            ),
            _rowGap,
            _menuItem('About us', CupertinoIcons.info, onPressed: onAbout),
            _rowGap,
            _menuItem(
              'Sign out',
              Icons.logout_rounded,
              key: const Key('sign-out'),
              onPressed: onSignOut,
              busy: signingOut,
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  key: const Key('sign-out-error'),
                  style: const TextStyle(
                    color: CupertinoColors.destructiveRed,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );

  Widget _profileCard() {
    final name = profile?.name.trim() ?? '';
    return Semantics(
      hint: 'Opens the profile editor',
      child: _card(
        CupertinoButton(
          key: const Key('edit-my-profile'),
          onPressed: signingOut ? null : onEditProfile,
          borderRadius: _cardRadius,
          padding: EdgeInsets.zero,
          child: _row(
            leading: ExcludeSemantics(
              child: ProfileAvatar(photo: profile?.photo, size: _avatarSize),
            ),
            label: name.isEmpty ? 'Your profile' : name,
            fontSize: 22,
            padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 16, 9),
          ),
        ),
      ),
    );
  }

  Widget _menuItem(
    String label,
    IconData icon, {
    Key? key,
    required VoidCallback onPressed,
    bool busy = false,
  }) {
    final row = _row(
      leading: SizedBox.square(
        dimension: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: FoodStyle.pale,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 26, color: FoodStyle.forest),
        ),
      ),
      label: label,
      trailing: busy ? const CupertinoActivityIndicator(radius: 8) : null,
    );
    return _card(
      CupertinoButton(
        key: key,
        padding: EdgeInsets.zero,
        borderRadius: _cardRadius,
        onPressed: signingOut ? null : onPressed,
        child: row,
      ),
    );
  }

  Widget _row({
    required Widget leading,
    required String label,
    double fontSize = 17,
    EdgeInsetsDirectional padding = const EdgeInsetsDirectional.fromSTEB(
      16,
      11,
      16,
      11,
    ),
    Widget? trailing,
  }) => Padding(
    padding: padding,
    child: Row(
      children: [
        SizedBox(
          width: _labelInset - padding.start,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: leading,
          ),
        ),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: FoodStyle.ink,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 18,
          child: Center(
            child:
                trailing ??
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: FoodStyle.muted,
                ),
          ),
        ),
      ],
    ),
  );

  Widget _card(Widget child) => DecoratedBox(
    decoration: const BoxDecoration(
      color: FoodStyle.surface,
      borderRadius: _cardRadius,
      boxShadow: [
        BoxShadow(
          color: Color(0x102C4431),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}
