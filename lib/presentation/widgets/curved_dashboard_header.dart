import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'page_header.dart';

/// Introductory header with layered curves for the initial dashboard.
class CurvedDashboardHeader extends StatelessWidget {
  const CurvedDashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 192,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: _HeaderCurveClipper(),
              child: ColoredBox(
                color: AppColors.primarySoft,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: const BoxDecoration(
                      color: Color(0x335557E8),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: PageHeader(
              eyebrow: 'Resumen local',
              title: 'Tus facturas, bajo control',
              subtitle:
                  'Revisa capturas pendientes y entiende tus gastos sin enviar datos a la nube.',
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 34)
      ..quadraticBezierTo(
        size.width * .34,
        size.height + 8,
        size.width * .64,
        size.height - 20,
      )
      ..quadraticBezierTo(
        size.width * .86,
        size.height - 42,
        size.width,
        size.height - 26,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(_HeaderCurveClipper oldClipper) => false;
}
