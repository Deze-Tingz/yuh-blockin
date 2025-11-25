import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../core/services/simple_alert_service.dart';
import '../../core/services/user_alias_service.dart';

class AlertHistoryScreen extends StatefulWidget {
  final String userId;

  const AlertHistoryScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> with SingleTickerProviderStateMixin {
  final SimpleAlertService _alertService = SimpleAlertService();
  final UserAliasService _aliasService = UserAliasService();
  List<Alert> _receivedAlerts = [];
  List<Alert> _sentAlerts = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0 = Received, 1 = Sent
  late TabController _tabController;

  // Stream subscriptions for real-time updates
  StreamSubscription<Alert>? _receivedAlertsSubscription;
  StreamSubscription<List<Alert>>? _sentAlertsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAlertHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _receivedAlertsSubscription?.cancel();
    _sentAlertsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAlertHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Listen to received alerts stream continuously for real-time updates
      _receivedAlertsSubscription?.cancel(); // Cancel previous subscription if any
      _receivedAlertsSubscription = _alertService.getAlertsStream(widget.userId).listen(
        (alert) {
          if (mounted) {
            setState(() {
              // Update or add the alert in the list
              final index = _receivedAlerts.indexWhere((a) => a.id == alert.id);
              if (index != -1) {
                // Update existing alert with latest data
                _receivedAlerts[index] = alert;
                print('🔄 Updated received alert: ${alert.id}, response: ${alert.response}');
              } else {
                // Add new alert
                _receivedAlerts.add(alert);
                print('➕ Added new received alert: ${alert.id}');
              }
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          print('❌ Received alerts stream error: $error');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
      );

      // Listen to sent alerts stream continuously for real-time updates
      _sentAlertsSubscription?.cancel(); // Cancel previous subscription if any
      _sentAlertsSubscription = _alertService.getSentAlertsStream(widget.userId).listen(
        (alertList) {
          if (mounted) {
            setState(() {
              _sentAlerts = List.from(alertList);
              _isLoading = false;
              print('🔄 Updated sent alerts: ${alertList.length} alerts');
            });
          }
        },
        onError: (error) {
          print('❌ Sent alerts stream error: $error');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      print('❌ Error loading alert history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _respondToAlert(Alert alert, String response) async {
    try {
      print('📤 Sending response: $response for alert: ${alert.id}');

      final success = await _alertService.sendResponse(
        alertId: alert.id,
        response: response,
      );

      if (success && mounted) {
        HapticFeedback.lightImpact();

        // No need to manually update local list - the stream listener will
        // automatically receive the updated alert from the database and update the UI

        // Show success message - clear any existing snackbars first
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Response sent: ${_getResponseDisplayText(response)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );

        print('✅ Response sent successfully - waiting for stream update');
      } else {
        throw Exception('Failed to send response');
      }
    } catch (e) {
      print('❌ Error responding to alert: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send response'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
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
                  Text(
                    'You responded: ${alert.responseText}',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
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
        backgroundColor: isPrimary ? color : color.withOpacity(0.1),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasResponse ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasResponse ? Colors.green[200]! : Colors.grey[300]!,
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
                hasResponse ? Icons.check_circle : Icons.access_time,
                color: hasResponse ? Colors.green : Colors.grey[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                hasResponse ? 'Response received' : 'Waiting for response',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: hasResponse ? Colors.green : Colors.grey[600],
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

          // Alert message
          Text(
            alert.message ?? 'You asked someone to move their car',
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),

          if (hasResponse) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.reply, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text(
                    'They responded: ${alert.responseText}',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Alert History',
          style: TextStyle(
            fontSize: isTablet ? 24 : 20,
            fontWeight: FontWeight.w700,
            color: Colors.grey[800],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[800]),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            setState(() {
              _selectedTab = index;
            });
          },
          tabs: [
            Tab(
              icon: Icon(Icons.inbox),
              text: 'Received (${_receivedAlerts.length})',
            ),
            Tab(
              icon: Icon(Icons.send),
              text: 'Sent (${_sentAlerts.length})',
            ),
          ],
          labelColor: Colors.blue[600],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blue[600],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Received alerts tab
                _receivedAlerts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox,
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
                              Icons.send,
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
    );
  }
}

