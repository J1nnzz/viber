import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';

/// Avatar de un grupo: la foto si existe, o un icono de grupo sobre el glow del acento.
class GroupAvatar extends StatelessWidget {
  final String  name;
  final String? photoUrl;
  final double  radius;

  const GroupAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: appAccentGlow,
      backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      child: hasPhoto
          ? null
          : Icon(Icons.groups_rounded, color: appAccent, size: radius * 1.1),
    );
  }
}
