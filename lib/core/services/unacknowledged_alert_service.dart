import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Service for tracking unacknowledged alerts
///
/// Handles local caching of alerts that haven't received responses within
/// the acceptable timeframe (10 minutes). Integrates with the existing
/// SimpleAlertService for real-time syncing.
class UnacknowledgedAlertService {
  static const String _storageKey = 'yuh_unacknowledged_alerts_data';
  static const Duration _acknowledgmentTimeout = Duration(minutes: 10);

  /// Add an alert to the unacknowledged list when sent
  Future<void> trackSentAlert({
    required String alertId,
    required String targetPlateNumber,
    required String urgencyLevel,
    String? message,
  }) async {
    try {
      final now = DateTime.now();
      final timeoutAt = now.add(_acknowledgmentTimeout);

      final alert = UnacknowledgedAlert(
        id: alertId,
        plateNumber: targetPlateNumber,
        urgencyLevel: urgencyLevel,
        message: message,
        sentAt: now,
        timeoutAt: timeoutAt,
        status: UnacknowledgedAlertStatus.pending,
      );

      final alerts = await getUnacknowledgedAlerts();
      alerts.add(alert);
      await _saveAlerts(alerts);

      if (kDebugMode) {
        print('📤 UnacknowledgedAlerts: Added alert $alertId for plate $targetPlateNumber');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ UnacknowledgedAlerts: Error tracking sent alert: $e');
      }
    }
  }

  /// Mark an alert as acknowledged when response is received
  Future<void> markAlertAcknowledged(String alertId) async {
    try {
      final alerts = await getUnacknowledgedAlerts();
      final updatedAlerts = alerts.map((alert) {
        if (alert.id == alertId) {
          return alert.copyWith(
            status: UnacknowledgedAlertStatus.acknowledged,
            acknowledgedAt: DateTime.now(),
          );
        }
        return alert;
      }).toList();

      await _saveAlerts(updatedAlerts);

      if (kDebugMode) {
        print('✅ UnacknowledgedAlerts: Marked alert $alertId as acknowledged');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ UnacknowledgedAlerts: Error marking acknowledged: $e');
      }
    }
  }

  /// Get all unacknowledged alerts (pending + timed out)
  Future<List<UnacknowledgedAlert>> getUnacknowledgedAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);

      if (data == null || data.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(data) as List<dynamic>;
      final alerts = jsonList
          .map((json) => UnacknowledgedAlert.fromJson(json as Map<String, dynamic>))
          .toList();

      // Update status based on current time and clean up old acknowledged alerts
      final now = DateTime.now();
      final updatedAlerts = <UnacknowledgedAlert>[];

      for (final alert in alerts) {
        // Remove acknowledged alerts older than 1 hour
        if (alert.status == UnacknowledgedAlertStatus.acknowledged) {
          if (alert.acknowledgedAt != null &&
              now.difference(alert.acknowledgedAt!).inHours < 1) {
            // Keep recent acknowledged alerts for user reference
            updatedAlerts.add(alert);
          }
          continue;
        }

        // Update timeout status for pending alerts
        if (alert.status == UnacknowledgedAlertStatus.pending) {
          if (now.isAfter(alert.timeoutAt)) {
            updatedAlerts.add(alert.copyWith(status: UnacknowledgedAlertStatus.timedOut));
          } else {
            updatedAlerts.add(alert);
          }
        } else {
          updatedAlerts.add(alert);
        }
      }

      // Save cleaned up list
      if (alerts.length != updatedAlerts.length) {
        await _saveAlerts(updatedAlerts);
      }

      return updatedAlerts;
    } catch (e) {
      if (kDebugMode) {
        print('❌ UnacknowledgedAlerts: Error getting alerts: $e');
      }
      return [];
    }
  }

  /// Get count of alerts that need attention (pending + timed out)
  Future<int> getUnacknowledgedCount() async {
    final alerts = await getUnacknowledgedAlerts();
    return alerts
        .where((alert) =>
            alert.status == UnacknowledgedAlertStatus.pending ||
            alert.status == UnacknowledgedAlertStatus.timedOut)
        .length;
  }

  /// Get alerts grouped by status for UI display
  Future<AlertStatusSummary> getAlertStatusSummary() async {
    final alerts = await getUnacknowledgedAlerts();

    final pending = alerts
        .where((alert) => alert.status == UnacknowledgedAlertStatus.pending)
        .toList();
    final timedOut = alerts
        .where((alert) => alert.status == UnacknowledgedAlertStatus.timedOut)
        .toList();
    final acknowledged = alerts
        .where((alert) => alert.status == UnacknowledgedAlertStatus.acknowledged)
        .toList();

    return AlertStatusSummary(
      pending: pending,
      timedOut: timedOut,
      acknowledged: acknowledged,
    );
  }

  /// Remove an alert from tracking (for cleanup)
  Future<void> removeAlert(String alertId) async {
    try {
      final alerts = await getUnacknowledgedAlerts();
      final filteredAlerts = alerts.where((alert) => alert.id != alertId).toList();
      await _saveAlerts(filteredAlerts);

      if (kDebugMode) {
        print('🗑️ UnacknowledgedAlerts: Removed alert $alertId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ UnacknowledgedAlerts: Error removing alert: $e');
      }
    }
  }

  /// Clear all alerts (for testing or reset)
  Future<void> clearAllAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);

      if (kDebugMode) {
        print('🧹 UnacknowledgedAlerts: Cleared all alerts');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ UnacknowledgedAlerts: Error clearing alerts: $e');
      }
    }
  }

  /// Private helper to save alerts to storage
  Future<void> _saveAlerts(List<UnacknowledgedAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = alerts.map((alert) => alert.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }
}

/// Status of an unacknowledged alert
enum UnacknowledgedAlertStatus {
  pending,      // Waiting for response
  timedOut,     // No response after 10 minutes
  acknowledged, // Response received
}

/// Data model for an unacknowledged alert
class UnacknowledgedAlert {
  final String id;
  final String plateNumber;
  final String urgencyLevel;
  final String? message;
  final DateTime sentAt;
  final DateTime timeoutAt;
  final UnacknowledgedAlertStatus status;
  final DateTime? acknowledgedAt;

  const UnacknowledgedAlert({
    required this.id,
    required this.plateNumber,
    required this.urgencyLevel,
    this.message,
    required this.sentAt,
    required this.timeoutAt,
    required this.status,
    this.acknowledgedAt,
  });

  /// Time until timeout (negative if already timed out)
  Duration get timeUntilTimeout => timeoutAt.difference(DateTime.now());

  /// Seconds until timeout for UI countdown
  int get secondsUntilTimeout => timeUntilTimeout.inSeconds.clamp(0, 600); // Max 10 minutes

  /// Whether this alert has timed out
  bool get isExpired => DateTime.now().isAfter(timeoutAt);

  /// Whether this alert is about to timeout (< 2 minutes)
  bool get isAboutToTimeout => !isExpired && timeUntilTimeout.inMinutes < 2;

  /// Formatted display of time remaining
  String get timeRemainingDisplay {
    if (isExpired) return 'Timed out';

    final duration = timeUntilTimeout;
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Create a copy with updated values
  UnacknowledgedAlert copyWith({
    String? id,
    String? plateNumber,
    String? urgencyLevel,
    String? message,
    DateTime? sentAt,
    DateTime? timeoutAt,
    UnacknowledgedAlertStatus? status,
    DateTime? acknowledgedAt,
  }) {
    return UnacknowledgedAlert(
      id: id ?? this.id,
      plateNumber: plateNumber ?? this.plateNumber,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      message: message ?? this.message,
      sentAt: sentAt ?? this.sentAt,
      timeoutAt: timeoutAt ?? this.timeoutAt,
      status: status ?? this.status,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plateNumber': plateNumber,
      'urgencyLevel': urgencyLevel,
      'message': message,
      'sentAt': sentAt.toIso8601String(),
      'timeoutAt': timeoutAt.toIso8601String(),
      'status': status.index,
      'acknowledgedAt': acknowledgedAt?.toIso8601String(),
    };
  }

  /// Create from JSON stored data
  factory UnacknowledgedAlert.fromJson(Map<String, dynamic> json) {
    return UnacknowledgedAlert(
      id: json['id'] as String,
      plateNumber: json['plateNumber'] as String,
      urgencyLevel: json['urgencyLevel'] as String,
      message: json['message'] as String?,
      sentAt: DateTime.parse(json['sentAt'] as String),
      timeoutAt: DateTime.parse(json['timeoutAt'] as String),
      status: UnacknowledgedAlertStatus.values[json['status'] as int],
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.parse(json['acknowledgedAt'] as String)
          : null,
    );
  }
}

/// Summary of alerts grouped by status
class AlertStatusSummary {
  final List<UnacknowledgedAlert> pending;
  final List<UnacknowledgedAlert> timedOut;
  final List<UnacknowledgedAlert> acknowledged;

  const AlertStatusSummary({
    required this.pending,
    required this.timedOut,
    required this.acknowledged,
  });

  /// Total count of alerts needing attention
  int get needsAttentionCount => pending.length + timedOut.length;

  /// Total count of all tracked alerts
  int get totalCount => pending.length + timedOut.length + acknowledged.length;

  /// Whether there are any alerts about to timeout
  bool get hasAboutToTimeout =>
      pending.any((alert) => alert.isAboutToTimeout);
}