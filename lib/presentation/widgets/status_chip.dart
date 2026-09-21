import 'package:flutter/material.dart';

import '../../domain/entities/invoice.dart';
import '../core/app_theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final verified = status == InvoiceStatus.verified;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: verified ? AppColors.successSurface : AppColors.reviewSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: verified
              ? AppColors.success.withValues(alpha: .18)
              : AppColors.review.withValues(alpha: .2),
        ),
      ),
      child: Text(
        verified ? 'Verificada' : 'Por revisar',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: verified ? AppColors.success : AppColors.review,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
