import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.photo, this.size = 54});

  final Uint8List? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = photo;
    final placeholder = ColoredBox(
      color: const Color(0xFFE9F0E2),
      child: Icon(
        CupertinoIcons.person_fill,
        color: const Color(0xFF526854),
        size: size * .48,
      ),
    );

    return Semantics(
      image: true,
      label: 'Profile photo',
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: bytes == null
              ? placeholder
              : Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
      ),
    );
  }
}
