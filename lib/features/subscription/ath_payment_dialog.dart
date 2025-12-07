import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/ath_movil_service.dart';

/// Dialog that shows ATH Móvil payment progress in real-time.
///
/// Usage:
/// ```dart
/// final result = await AthPaymentDialog.show(
///   context: context,
///   transactionId: 'txn_123',
///   amount: 2.99,
///   productType: AthProductType.monthly,
/// );
///
/// if (result == true) {
///   // Payment was successful
/// }
/// ```
class AthPaymentDialog extends StatefulWidget {
  final String transactionId;
  final double amount;
  final AthProductType productType;

  const AthPaymentDialog({
    super.key,
    required this.transactionId,
    required this.amount,
    required this.productType,
  });

  /// Show the payment dialog and return true if payment was successful
  static Future<bool?> show({
    required BuildContext context,
    required String transactionId,
    required double amount,
    required AthProductType productType,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must cancel explicitly
      builder: (context) => AthPaymentDialog(
        transactionId: transactionId,
        amount: amount,
        productType: productType,
      ),
    );
  }

  @override
  State<AthPaymentDialog> createState() => _AthPaymentDialogState();
}

class _AthPaymentDialogState extends State<AthPaymentDialog>
    with SingleTickerProviderStateMixin {
  final AthMovilService _athService = AthMovilService();
  StreamSubscription<AthPaymentStatus>? _statusSubscription;

  AthPaymentStatus _currentStatus = AthPaymentStatus(
    status: AthStatus.pending,
    message: 'Connecting to ATH Móvil...',
  );

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startWatching();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  void _startWatching() {
    _statusSubscription = _athService
        .watchPaymentStatus(widget.transactionId)
        .listen((status) {
      setState(() => _currentStatus = status);

      if (status.isSuccess) {
        _pulseController.stop();
        // Delay to show success state, then close
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });
      } else if (status.status == AthStatus.failed ||
          status.status == AthStatus.expired ||
          status.status == AthStatus.error) {
        _pulseController.stop();
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleCancel() {
    _athService.cancelPayment();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1E1E1E), const Color(0xFF121212)]
                : [Colors.white, const Color(0xFFF5F5F5)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ATH Móvil branding
            _buildHeader(),
            const SizedBox(height: 24),

            // Status indicator
            _buildStatusIndicator(),
            const SizedBox(height: 20),

            // Status message
            Text(
              _currentStatus.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // Amount and product
            _buildAmountDisplay(),
            const SizedBox(height: 24),

            // Instructions (only when waiting for user)
            if (_currentStatus.status == AthStatus.pending ||
                _currentStatus.status == AthStatus.open)
              _buildInstructions(),

            // Reference number (on success)
            if (_currentStatus.isSuccess &&
                _currentStatus.referenceNumber != null)
              _buildReferenceNumber(),

            // Action button
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // ATH Móvil logo/icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFE31837), // ATH Móvil red
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE31837).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'ATH',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,

              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'ATH Móvil',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    switch (_currentStatus.status) {
      case AthStatus.pending:
      case AthStatus.open:
      case AthStatus.authorizing:
        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE31837).withValues(alpha: 0.1),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFE31837),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );

      case AthStatus.confirmed:
        return _buildStatusIcon(
          Icons.check_circle,
          const Color(0xFF4CAF50),
        );

      case AthStatus.completed:
        return _buildStatusIcon(
          Icons.celebration,
          const Color(0xFF4CAF50),
        );

      case AthStatus.failed:
      case AthStatus.error:
        return _buildStatusIcon(
          Icons.error,
          Colors.red,
        );

      case AthStatus.expired:
        return _buildStatusIcon(
          Icons.timer_off,
          Colors.orange,
        );

      case AthStatus.cancelled:
        return _buildStatusIcon(
          Icons.cancel,
          Colors.grey,
        );
    }
  }

  Widget _buildStatusIcon(IconData icon, Color color) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),
      ),
      child: Icon(
        icon,
        size: 48,
        color: color,
      ),
    );
  }

  Widget _buildAmountDisplay() {
    final productName = widget.productType == AthProductType.lifetime
        ? 'Lifetime Premium'
        : 'Monthly Premium';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '\$${widget.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE31837).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              productName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE31837),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'How to complete payment:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Check your ATH Móvil app\n'
            '2. Tap the payment from Yuh Blockin\n'
            '3. Confirm to complete',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceNumber() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text(
            'Ref: ${_currentStatus.referenceNumber}',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    // Show different buttons based on status
    if (_currentStatus.isSuccess) {
      return FilledButton.icon(
        onPressed: () => Navigator.of(context).pop(true),
        icon: const Icon(Icons.check),
        label: const Text('Done'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          minimumSize: const Size(double.infinity, 48),
        ),
      );
    }

    if (_currentStatus.status == AthStatus.failed ||
        _currentStatus.status == AthStatus.error ||
        _currentStatus.status == AthStatus.expired) {
      return Column(
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Close'),
          ),
        ],
      );
    }

    // Cancel button for in-progress states
    return TextButton(
      onPressed: _handleCancel,
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey[600],
      ),
      child: const Text('Cancel Payment'),
    );
  }
}

