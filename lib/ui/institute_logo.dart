import 'package:flutter/material.dart';

/// The institute's round logo (assets/brand/istaps_logo.png); nothing when
/// the file is missing.
class InstituteLogo extends StatelessWidget {
  const InstituteLogo({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'معهد علوم وتقنيات النشاطات البدنية والرياضية – جامعة العربي التبسي، تبسة',
        child: ClipOval(
          child: Image.asset(
            'assets/brand/istaps_logo.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      );
}
