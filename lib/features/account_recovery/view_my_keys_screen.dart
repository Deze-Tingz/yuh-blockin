import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/premium_theme.dart';
import '../../core/services/account_recovery_service.dart';

/// Screen to view and copy ownership keys for all registered plates
/// Helps users backup their keys for device recovery
class ViewMyKeysScreen extends StatefulWidget {
  const ViewMyKeysScreen({super.key});

  @override
  State<ViewMyKeysScreen> createState() => _ViewMyKeysScreenState();
}

class _ViewMyKeysScreenState extends State<ViewMyKeysScreen> {
  final AccountRecoveryService _recoveryService = AccountRecoveryService();

  Map<String, String?> _plateKeys = {};
  bool _isLoading = true;
  final Set<String> _copiedPlates = {};

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    setState(() => _isLoading = true);

    try {
      final keys = await _recoveryService.getAllOwnershipKeys();
      setState(() {
        _plateKeys = keys;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _copyKey(String plate, String key) async {
    await Clipboard.setData(ClipboardData(text: key));
    HapticFeedback.mediumImpact();

    setState(() {
      _copiedPlates.add(plate);
    });

    // Reset copied state after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copiedPlates.remove(plate);
        });
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Key copied for $plate'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _copyAllKeys() async {
    final buffer = StringBuffer();
    buffer.writeln('=== Yuh Blockin\' Ownership Keys ===');
    buffer.writeln('Keep these keys safe!\n');

    for (final entry in _plateKeys.entries) {
      if (entry.value != null) {
        buffer.writeln('Plate: ${entry.key}');
        buffer.writeln('Key: ${entry.value}');
        buffer.writeln('');
      }
    }

    buffer.writeln('---');
    buffer.writeln('Generated: ${DateTime.now().toString().substring(0, 16)}');

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    HapticFeedback.heavyImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All keys copied to clipboard!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isCompact = screenSize.height < 700;

    return Scaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: PremiumTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: PremiumTheme.subtleShadow,
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: PremiumTheme.primaryTextColor,
              size: 18,
            ),
          ),
        ),
        title: Text(
          'My Secret Keys',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: PremiumTheme.primaryTextColor,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_plateKeys.isNotEmpty && _plateKeys.values.any((v) => v != null))
            IconButton(
              onPressed: _copyAllKeys,
              icon: Icon(
                Icons.copy_all_rounded,
                color: PremiumTheme.accentColor,
              ),
              tooltip: 'Copy all keys',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(isCompact),
    );
  }

  Widget _buildContent(bool isCompact) {
    if (_plateKeys.isEmpty) {
      return _buildEmptyState(isCompact);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: isCompact ? 12 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning banner
          _buildWarningBanner(isCompact),

          SizedBox(height: isCompact ? 20 : 28),

          // Plates list
          ..._plateKeys.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildKeyCard(entry.key, entry.value, isCompact),
            );
          }),

          SizedBox(height: isCompact ? 12 : 20),

          // Help text
          _buildHelpText(isCompact),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.15),
            Colors.orange.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shield_rounded,
              color: Colors.amber.shade700,
              size: isCompact ? 20 : 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save These Keys',
                  style: TextStyle(
                    fontSize: isCompact ? 14 : 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'These keys are the ONLY way to recover your plates if you change devices.',
                  style: TextStyle(
                    fontSize: isCompact ? 12 : 13,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyCard(String plate, String? key, bool isCompact) {
    final hasCopied = _copiedPlates.contains(plate);
    final hasKey = key != null && key.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasKey
              ? PremiumTheme.accentColor.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plate header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 14 : 16,
              vertical: isCompact ? 12 : 14,
            ),
            decoration: BoxDecoration(
              color: PremiumTheme.accentColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PremiumTheme.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.directions_car_rounded,
                    color: PremiumTheme.accentColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    plate,
                    style: TextStyle(
                      fontSize: isCompact ? 17 : 18,
                      fontWeight: FontWeight.w600,
                      color: PremiumTheme.primaryTextColor,
                    ),
                  ),
                ),
                if (hasKey)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Secure',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Key section
          Padding(
            padding: EdgeInsets.all(isCompact ? 14 : 16),
            child: hasKey
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Secret Ownership Key',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: PremiumTheme.secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: PremiumTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: PremiumTheme.dividerColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: SelectableText(
                          key,
                          style: TextStyle(
                            fontSize: isCompact ? 14 : 15,
                            fontWeight: FontWeight.w600,
                            color: PremiumTheme.primaryTextColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _copyKey(plate, key),
                          icon: Icon(
                            hasCopied ? Icons.check : Icons.copy_rounded,
                            size: 18,
                          ),
                          label: Text(hasCopied ? 'Copied!' : 'Copy Key'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasCopied
                                ? Colors.green
                                : PremiumTheme.accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Key not found. This plate cannot be recovered on a new device.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isCompact) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: PremiumTheme.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.key_off_rounded,
                size: 40,
                color: PremiumTheme.tertiaryTextColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Plates Registered',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: PremiumTheme.primaryTextColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Register a license plate to receive your secret ownership key.',
              style: TextStyle(
                fontSize: 15,
                color: PremiumTheme.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpText(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 16),
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: PremiumTheme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 18,
                color: PremiumTheme.accentColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Pro Tip',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PremiumTheme.primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Save your keys to a password manager or notes app. '
            'If you lose your device, you can recover your plates on any new device using these keys.',
            style: TextStyle(
              fontSize: 13,
              color: PremiumTheme.secondaryTextColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
