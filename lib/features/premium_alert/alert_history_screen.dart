import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../core/services/simple_alert_service.dart';
import '../../core/services/user_alias_service.dart';
import '../../core/theme/premium_theme.dart';

class AlertHistoryScreen extends StatefulWidget {
  final String userId;

  const AlertHistoryScreen({
    super.key,
    required this.userId,
  });

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  final SimpleAlertService _alertService = SimpleAlertService();
  final UserAliasService _aliasService = UserAliasService();
  List<Alert> _receivedAlerts = [];
  List<Alert> _sentAlerts = [];
  bool _isLoading = true;
  int _selectedSegment = 0;

  // Stream subscriptions for real-time updates
  StreamSubscription<Alert>? _receivedAlertsSubscription;
  StreamSubscription<List<Alert>>? _sentAlertsSubscription;

  // Track seen alert IDs to prevent duplicates
  final Set<String> _seenReceivedAlertIds = {};

  // Premium colors for status
  static const Color _successColor = Color(0xFF34C759);
  static const Color _warningColor = Color(0xFFFF9500);
  static const Color _pendingColor = Color(0xFF007AFF);

  @override
  void initState() {
    super.initState();
    _loadAlertHistory();
  }

  @override
  void dispose() {
    _receivedAlertsSubscription?.cancel();
    _sentAlertsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAlertHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Listen to received alerts stream - handle each alert individually
      _receivedAlertsSubscription?.cancel();
      _receivedAlertsSubscription = _alertService.getAlertsStream(widget.userId).listen(
        (alert) {
          if (mounted) {
            setState(() {
              // Check if we've already seen this alert
              if (!_seenReceivedAlertIds.contains(alert.id)) {
                _seenReceivedAlertIds.add(alert.id);
                _receivedAlerts.add(alert);
                // Sort by newest first
                _receivedAlerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              } else {
                // Update existing alert (e.g., when response is added)
                final index = _receivedAlerts.indexWhere((a) => a.id == alert.id);
                if (index != -1) {
                  _receivedAlerts[index] = alert;
                }
              }
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          debugPrint('❌ Received alerts stream error: $error');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
      );

      // Listen to sent alerts stream - receives full list each time
      _sentAlertsSubscription?.cancel();
      _sentAlertsSubscription = _alertService.getSentAlertsStream(widget.userId).listen(
        (alertList) {
          if (mounted) {
            setState(() {
              // Deduplicate by ID and sort by newest first
              final uniqueAlerts = <String, Alert>{};
              for (final alert in alertList) {
                uniqueAlerts[alert.id] = alert;
              }
              _sentAlerts = uniqueAlerts.values.toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          debugPrint('❌ Sent alerts stream error: $error');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
      );

      // Set loading to false after a timeout if streams don't emit
      Timer(const Duration(seconds: 3), () {
        if (mounted && _isLoading) {
          setState(() => _isLoading = false);
        }
      });
    } catch (e) {
      debugPrint('❌ Error loading alert history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _respondToAlert(Alert alert, String response) async {
    try {
      debugPrint('📤 Sending response: $response for alert: ${alert.id}');

      final success = await _alertService.sendResponse(
        alertId: alert.id,
        response: response,
      );

      if (success && mounted) {
        HapticFeedback.lightImpact();

        // Update local list immediately for responsive UI
        // (Stream may take a moment to update)
        setState(() {
          final index = _receivedAlerts.indexWhere((a) => a.id == alert.id);
          if (index != -1) {
            // Create updated alert with response
            final updatedAlert = Alert(
              id: alert.id,
              senderId: alert.senderId,
              receiverId: alert.receiverId,
              plateHash: alert.plateHash,
              message: alert.message,
              response: response,
              responseMessage: null,
              createdAt: alert.createdAt,
              readAt: DateTime.now(),
              responseAt: DateTime.now(),
            );
            _receivedAlerts[index] = updatedAlert;
          }
        });

        // Show success message - clear any existing snackbars first
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Response sent: ${_getResponseDisplayText(response)}'),
            backgroundColor: Colors.green,
            duration: const Duration(milliseconds: 500),
          ),
        );

        debugPrint('✅ Response sent successfully');
      } else {
        throw Exception('Failed to send response');
      }
    } catch (e) {
      debugPrint('❌ Error responding to alert: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send response'),
            backgroundColor: Colors.red,
            duration: Duration(milliseconds: 500),
          ),
        );
      }
    }
  }

  String _getResponseDisplayText(String response) {
    switch (response) {
      case 'moving_now':
        return 'Moving now';
      case '5_minutes':
        return 'Give me 5 minutes';
      case 'cant_move':
        return 'Can\'t move right now';
      case 'wrong_car':
        return 'Wrong car';
      default:
        return 'Unknown response';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  Widget _buildReceivedAlertItem(Alert alert) {
    final hasResponse = alert.response != null && alert.response!.isNotEmpty;
    final statusColor = hasResponse ? _successColor : _warningColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: hasResponse ? null : () => _showQuickResponseSheet(alert),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasResponse ? Icons.check_rounded : Icons.notifications_active_rounded,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<String>(
                        future: _aliasService.getAliasForUser(alert.senderId),
                        builder: (context, snapshot) {
                          final alias = snapshot.hasData
                              ? _aliasService.formatAliasForDisplay(snapshot.data!)
                              : 'Someone';
                          return Text(
                            '$alias needs you to move',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: PremiumTheme.primaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasResponse ? 'Responded: ${alert.responseText}' : 'Tap to respond',
                        style: TextStyle(
                          fontSize: 13,
                          color: hasResponse
                              ? _successColor
                              : PremiumTheme.secondaryTextColor,
                          fontWeight: hasResponse ? FontWeight.w500 : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Timestamp and chevron
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTimestamp(alert.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: PremiumTheme.tertiaryTextColor,
                      ),
                    ),
                    if (!hasResponse) ...[
                      const SizedBox(height: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: PremiumTheme.tertiaryTextColor,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQuickResponseSheet(Alert alert) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: PremiumTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: PremiumTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Quick Response',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: PremiumTheme.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildQuickResponseOption(
              alert: alert,
              label: 'Moving now',
              response: 'moving_now',
              icon: Icons.directions_car_rounded,
              color: _successColor,
            ),
            _buildQuickResponseOption(
              alert: alert,
              label: 'Give me 5 minutes',
              response: '5_minutes',
              icon: Icons.timer_rounded,
              color: _warningColor,
            ),
            _buildQuickResponseOption(
              alert: alert,
              label: 'Can\'t move right now',
              response: 'cant_move',
              icon: Icons.block_rounded,
              color: const Color(0xFFFF3B30),
            ),
            _buildQuickResponseOption(
              alert: alert,
              label: 'Wrong car',
              response: 'wrong_car',
              icon: Icons.help_outline_rounded,
              color: PremiumTheme.secondaryTextColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickResponseOption({
    required Alert alert,
    required String label,
    required String response,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pop(context);
            _respondToAlert(alert, response);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: PremiumTheme.primaryTextColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: color.withValues(alpha: 0.6),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSentAlertItem(Alert alert) {
    final hasResponse = alert.hasResponse;

    // Determine status color and icon
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (hasResponse) {
      switch (alert.response) {
        case 'moving_now':
          statusColor = _successColor;
          statusIcon = Icons.directions_car_rounded;
          statusText = 'Moving now';
          break;
        case '5_minutes':
          statusColor = _warningColor;
          statusIcon = Icons.timer_rounded;
          statusText = 'In 5 minutes';
          break;
        case 'cant_move':
          statusColor = const Color(0xFFFF3B30);
          statusIcon = Icons.block_rounded;
          statusText = 'Can\'t move';
          break;
        case 'wrong_car':
          statusColor = PremiumTheme.secondaryTextColor;
          statusIcon = Icons.help_outline_rounded;
          statusText = 'Wrong car';
          break;
        default:
          statusColor = _successColor;
          statusIcon = Icons.check_rounded;
          statusText = alert.responseText;
      }
    } else {
      statusColor = _pendingColor;
      statusIcon = Icons.schedule_rounded;
      statusText = 'Waiting';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: PremiumTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<String>(
                    future: _aliasService.getAliasForUser(alert.receiverId),
                    builder: (context, snapshot) {
                      final alias = snapshot.hasData
                          ? _aliasService.formatAliasForDisplay(snapshot.data!)
                          : 'Driver';
                      return Text(
                        'Sent to $alias',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: PremiumTheme.primaryTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      if (alert.message != null && alert.message!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            alert.message!,
                            style: TextStyle(
                              fontSize: 12,
                              color: PremiumTheme.secondaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Timestamp
            Text(
              _formatTimestamp(alert.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: PremiumTheme.tertiaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleClearOption(String option) {
    switch (option) {
      case 'clear_received':
        _showClearConfirmationDialog(
          title: 'Clear Received Alerts',
          message: 'Are you sure you want to delete all ${_receivedAlerts.length} received alerts? This cannot be undone.',
          onConfirm: () => _clearReceivedAlerts(),
        );
        break;
      case 'clear_sent':
        _showClearConfirmationDialog(
          title: 'Clear Sent Alerts',
          message: 'Are you sure you want to delete all ${_sentAlerts.length} sent alerts? This cannot be undone.',
          onConfirm: () => _clearSentAlerts(),
        );
        break;
      case 'clear_all':
        _showClearConfirmationDialog(
          title: 'Clear All Alerts',
          message: 'Are you sure you want to delete all ${_receivedAlerts.length + _sentAlerts.length} alerts? This cannot be undone.',
          onConfirm: () => _clearAllAlerts(),
        );
        break;
    }
  }

  void _showClearConfirmationDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
            const SizedBox(width: 8),
            Flexible(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearReceivedAlerts() async {
    try {
      final count = await _alertService.deleteReceivedAlerts(widget.userId);
      if (mounted) {
        setState(() {
          _receivedAlerts.clear();
          _seenReceivedAlertIds.clear();
        });
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $count received alerts'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error clearing received alerts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to clear alerts'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearSentAlerts() async {
    try {
      final count = await _alertService.deleteSentAlerts(widget.userId);
      if (mounted) {
        setState(() {
          _sentAlerts.clear();
        });
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $count sent alerts'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error clearing sent alerts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to clear alerts'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearAllAlerts() async {
    try {
      final count = await _alertService.deleteAllAlerts(widget.userId);
      if (mounted) {
        setState(() {
          _receivedAlerts.clear();
          _sentAlerts.clear();
          _seenReceivedAlertIds.clear();
        });
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $count alerts'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error clearing all alerts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to clear alerts'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendReminder(Alert alert) async {
    try {
      // Send a reminder directly to the receiver using their ID
      final result = await _alertService.sendReminderAlert(
        receiverUserId: alert.receiverId,
        senderUserId: widget.userId,
        plateHash: alert.plateHash,
        message: '⏰ Reminder: Still waiting for you to move',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reminder sent!'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not send reminder: ${result.error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error sending reminder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send reminder'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAlerts = _receivedAlerts.isNotEmpty || _sentAlerts.isNotEmpty;

    return Scaffold(
      backgroundColor: PremiumTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back,
            color: PremiumTheme.primaryTextColor,
          ),
        ),
        title: Text(
          'Alert History',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: PremiumTheme.primaryTextColor,
          ),
        ),
        backgroundColor: PremiumTheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (hasAlerts)
            PopupMenuButton<String>(
              onSelected: _handleClearOption,
              icon: Icon(
                Icons.more_horiz,
                color: PremiumTheme.primaryTextColor,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: PremiumTheme.surfaceColor,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      const SizedBox(width: 12),
                      Text(
                        'Clear All',
                        style: TextStyle(color: PremiumTheme.primaryTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Segment control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: PremiumTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _selectedSegment,
                  backgroundColor: PremiumTheme.surfaceColor,
                  thumbColor: PremiumTheme.backgroundColor,
                  onValueChanged: (int? value) {
                    if (value != null) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedSegment = value;
                      });
                    }
                  },
                  children: {
                    0: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Received (${_receivedAlerts.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: PremiumTheme.primaryTextColor,
                        ),
                      ),
                    ),
                    1: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Sent (${_sentAlerts.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: PremiumTheme.primaryTextColor,
                        ),
                      ),
                    ),
                  },
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CupertinoActivityIndicator(
                        color: PremiumTheme.accentColor,
                      ),
                    )
                  : IndexedStack(
                      index: _selectedSegment,
                      children: [
                        // Received alerts tab
                        _receivedAlerts.isEmpty
                            ? _buildEmptyState(
                                icon: CupertinoIcons.tray,
                                title: 'No alerts received',
                                subtitle: 'When someone sends you an alert, it will appear here',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 24),
                                itemCount: _receivedAlerts.length,
                                itemBuilder: (context, index) {
                                  return _buildReceivedAlertItem(_receivedAlerts[index]);
                                },
                              ),

                        // Sent alerts tab
                        _sentAlerts.isEmpty
                            ? _buildEmptyState(
                                icon: CupertinoIcons.paperplane,
                                title: 'No alerts sent',
                                subtitle: 'Alerts you send will appear here',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 24),
                                itemCount: _sentAlerts.length,
                                itemBuilder: (context, index) {
                                  return _buildSentAlertItem(_sentAlerts[index]);
                                },
                              ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: PremiumTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 32,
                color: PremiumTheme.tertiaryTextColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: PremiumTheme.primaryTextColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: PremiumTheme.secondaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
