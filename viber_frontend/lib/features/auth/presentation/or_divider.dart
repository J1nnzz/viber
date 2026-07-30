import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: appDivider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: spacingMd),
          child: Text(
            'o',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: appDivider)),
      ],
    );
  }
}
