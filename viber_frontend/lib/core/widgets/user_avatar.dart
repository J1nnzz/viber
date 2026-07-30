import 'package:flutter/material.dart';
import 'app_image.dart';

/// Avatar circular de usuario. Muestra la foto de perfil si [avatarUrl] tiene valor;
/// si no, muestra la inicial del [username] sobre un color de identidad estable.
///
/// El color se deriva del nombre de usuario, así cada persona tiene siempre el
/// mismo color y el conjunto aporta variedad (en vez de un único acento repetido).
/// Son tonos profundos para que la inicial en blanco contraste en claro y oscuro.
class UserAvatar extends StatelessWidget {
  final String  username;
  final String? avatarUrl;
  final double  radius;

  const UserAvatar({
    super.key,
    required this.username,
    this.avatarUrl,
    this.radius = 22,
  });

  static const _palette = <Color>[
    Color(0xFF6B3A94), // morado
    Color(0xFFB23B79), // magenta
    Color(0xFF1F7A6B), // teal
    Color(0xFF2563C9), // azul
    Color(0xFFC2502A), // terracota
    Color(0xFF9A6212), // ámbar
  ];

  Color get _identityColor =>
      _palette[username.isEmpty ? 0 : username.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final initialChild = Text(
      initial,
      style: TextStyle(
        color:      Colors.white,
        fontSize:   radius * 0.7,
        fontWeight: FontWeight.w700,
      ),
    );

    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return CircleAvatar(
        radius:          radius,
        backgroundColor: _identityColor,
        child:           initialChild,
      );
    }

    return CircleAvatar(
      radius:          radius,
      backgroundColor: _identityColor,
      child: ClipOval(
        child: AppImage(
          url:          avatarUrl!,
          width:        radius * 2,
          height:       radius * 2,
          errorBuilder: (_) => initialChild,
        ),
      ),
    );
  }
}
