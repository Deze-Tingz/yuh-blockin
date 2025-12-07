import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../core/services/simple_alert_service.dart';
import '../../core/services/user_alias_service.dart';

class AlertHistoryScreen extends StatefulWidget {
  final String userId;

  const AlertHistoryScreen({
    super.key,
    required this.userId,
  });

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> with SingleTickerProviderStateMixin {
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
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    // Check both response field and responseAt to ensure accurate status
    final hasResponse = alert.response != null && alert.response!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasResponse ? Colors.grey[100] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasResponse ? Colors.grey[300]! : Colors.orange[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status and timestamp
          Row(
            children: [
              Icon(
                hasResponse ? Icons.check_circle : Icons.circle_outlined,
                color: hasResponse ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                hasResponse ? 'Responded' : 'Needs Response',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: hasResponse ? Colors.green : Colors.orange[800],
                ),
              ),
              const Spacer(),
              Text(
                _formatTimestamp(alert.createdAt),
                style: TextStyle(
                  fontSize: isTablet ? 14 : 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Alert message with sender alias
          FutureBuilder<String>(
            future: _aliasService.getAliasForUser(alert.senderId),
            builder: (context, snapshot) {
              String message;
              if (snapshot.hasData) {
                final alias = _aliasService.formatAliasForDisplay(snapshot.data!);
                message = '$alias needs you to move your car';
              } else {
                message = 'Someone needs you to move your car';
              }

              return Text(
                message,
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),

          if (hasResponse) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.reply, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You responded: ${alert.responseText}',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            // Response buttons for unresponded alerts
            Row(
              children: [
                Expanded(
                  child: _buildResponseButton(
                    alert: alert,
                    label: 'Moving now',
                    response: 'moving_now',
                    color: Colors.green,
                    isPrimary: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildResponseButton(
                    alert: alert,
                    label: '5 minutes',
                    response: '5_minutes',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildResponseButton(
                    alert: alert,
                    label: 'Can\'t move',
                    response: 'cant_move',
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildResponseButton(
                    alert: alert,
                    label: 'Wrong car',
                    response: 'wrong_car',
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResponseButton({
    required Alert alert,
    required String label,
    required String response,
    required Color color,
    bool isPrimary = false,
  }) {
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return ElevatedButton(
      onPressed: () => _respondToAlert(alert, response),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? color : color.withAlpha(25),
        foregroundColor: isPrimary ? Colors.white : color,
        elevation: isPrimary ? 2 : 0,
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 12 : 8,
          horizontal: 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isPrimary ? BorderSide.none : BorderSide(color: color),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: isTablet ? 14 : 12,
          fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSentAlertItem(Alert alert) {
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final hasResponse = alert.hasResponse;

    // Get response emoji and color based on response type
    IconData statusIcon;
    Color statusColor;
    String statusText;

    if (hasResponse) {
      switch (alert.response) {
        case 'moving_now':
          statusIcon = Icons.directions_car;
          statusColor = Colors.green;
          statusText = 'Moving now';
          break;
        case '5_minutes':
          statusIcon = Icons.timer;
          statusColor = Colors.orange;
          statusText = 'In 5 minutes';
          break;
        case 'cant_move':
          statusIcon = Icons.block;
          statusColor = Colors.red;
          statusText = 'Can\'t move';
          break;
        case 'wrong_car':
          statusIcon = Icons.error_outline;
          statusColor = Colors.grey;
          statusText = 'Wrong car';
          break;
        default:
          statusIcon = Icons.check_circle;
          statusColor = Colors.green;
          statusText = alert.responseText;
      }
    } else {
      statusIcon = Icons.access_time;
      statusColor = Colors.blue;
      statusText = 'Awaiting response';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasResponse
              ? [statusColor.withAlpha(20), statusColor.withAlpha(8)]
              : [Colors.blue.withAlpha(13), Colors.grey.withAlpha(5)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withAlpha(64),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main content area
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status indicator circle
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(31),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status and time row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(38),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: isTablet ? 12 : 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,

                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatTimestamp(alert.createdAt),
                            style: TextStyle(
                              fontSize: isTablet ? 13 : 11,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Recipient info with alias
                      FutureBuilder<String>(
                        future: _aliasService.getAliasForUser(alert.receiverId),
                        builder: (context, snapshot) {
                          final alias = snapshot.hasData
                              ? _aliasService.formatAliasForDisplay(snapshot.data!)
                              : 'Driver';
                          return Text(
                            'Alert sent to $alias',
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      if (alert.message != null && alert.message!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          alert.message!,
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Response details footer (only if responded)
          if (hasResponse && alert.responseAt != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(15),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(alert.response == '5_minutes' ? 0 : 16),
                  bottomRight: Radius.circular(alert.response == '5_minutes' ? 0 : 16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: isTablet ? 16 : 14,
                    color: statusColor.withAlpha(178),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Responded ${_formatTimestamp(alert.responseAt!)}',
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          // Follow-up options for "5 minutes" response
          if (alert.response == '5_minutes')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(20),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.orange.withAlpha(51),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Follow up',
                    style: TextStyle(
                      fontSize: isTablet ? 13 : 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFollowUpButton(
                          label: 'Car moved!',
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                          onTap: () => _showResolutionDialog(alert, 'resolved'),
                          isTablet: isTablet,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFollowUpButton(
                          label: 'Send reminder',
                          icon: Icons.notification_important_outlined,
                          color: Colors.orange,
                          onTap: () => _showReminderDialog(alert),
                          isTablet: isTablet,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFollowUpButton(
                          label: 'Still waiting',
                          icon: Icons.hourglass_bottom,
                          color: Colors.blue,
                          onTap: () => _showStillWaitingDialog(alert),
                          isTablet: isTablet,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFollowUpButton(
                          label: 'Give up',
                          icon: Icons.close,
                          color: Colors.grey,
                          onTap: () => _showResolutionDialog(alert, 'gave_up'),
                          isTablet: isTablet,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFollowUpButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 10 : 8,
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withAlpha(77)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: isTablet ? 16 : 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResolutionDialog(Alert alert, String resolution) {
    final isResolved = resolution == 'resolved';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isResolved ? Icons.check_circle : Icons.cancel,
              color: isResolved ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(isResolved ? 'Resolved!' : 'Give up?'),
          ],
        ),
        content: Text(
          isResolved
              ? 'Great! The car has moved and the situation is resolved.'
              : 'Are you sure you want to give up on this alert?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markAlertResolved(alert, resolution);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isResolved ? Colors.green : Colors.grey,
            ),
            child: Text(isResolved ? 'Confirm' : 'Give up'),
          ),
        ],
      ),
    );
  }

  void _showReminderDialog(Alert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.notification_important, color: Colors.orange),
            SizedBox(width: 8),
            Text('Send Reminder'),
          ],
        ),
        content: const Text(
          'Send a gentle reminder that you\'re still waiting for them to move?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendReminder(alert);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Send Reminder'),
          ),
        ],
      ),
    );
  }

  void _showStillWaitingDialog(Alert alert) {
    final timeSinceResponse = alert.responseAt != null
        ? DateTime.now().difference(alert.responseAt!).inMinutes
        : 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_bottom, color: Colors.blue),
            SizedBox(width: 8),
            Text('Still Waiting'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'They said 5 minutes, it\'s been $timeSinceResponse minutes.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'What would you like to do?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep waiting'),
          ),
          if (timeSinceResponse >= 5)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _sendReminder(alert);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('Send Reminder'),
            ),
        ],
      ),
    );
  }

  Future<void> _markAlertResolved(Alert alert, String resolution) async {
    // For now, just show a confirmation - in future could update DB
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resolution == 'resolved'
                ? '✓ Marked as resolved'
                : 'Alert closed',
          ),
          backgroundColor: resolution == 'resolved' ? Colors.green : Colors.grey,
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return CupertinoPageScaffold(
      backgroundColor: Colors.white,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Alert History'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {},
          child: const Icon(CupertinoIcons.ellipsis),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            CupertinoSlidingSegmentedControl<int>(
              groupValue: _selectedSegment,
              onValueChanged: (int? value) {
                if (value != null) {
                  setState(() {
                    _selectedSegment = value;
                  });
                }
              },
              children: {
                0: Text('Received (${_receivedAlerts.length})'),
                1: Text('Sent (${_sentAlerts.length})'),
              },
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CupertinoActivityIndicator(),
                    )
                  : IndexedStack(
                      index: _selectedSegment,
                      children: [
                        // Received alerts tab
                        _receivedAlerts.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.tray,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No received alerts',
                                      style: TextStyle(
                                        fontSize: isTablet ? 18 : 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 16),
                                itemCount: _receivedAlerts.length,
                                itemBuilder: (context, index) {
                                  return _buildReceivedAlertItem(_receivedAlerts[index]);
                                },
                              ),

                        // Sent alerts tab
                        _sentAlerts.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.paperplane,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No sent alerts',
                                      style: TextStyle(
                                        fontSize: isTablet ? 18 : 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 16),
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
}
