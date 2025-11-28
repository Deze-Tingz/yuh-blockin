import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Premium Backend Service for Yuh Blockin'
///
/// Handles secure license plate management, real-time alerts,
/// reputation system, and premium features with enterprise-grade security
class PremiumBackendService {
  static final PremiumBackendService _instance = PremiumBackendService._internal();
  factory PremiumBackendService() => _instance;
  PremiumBackendService._internal();

  // Simulated database for development
  final Map<String, UserProfile> _userDatabase = {};
  final Map<String, Alert> _alertDatabase = {};
  final Map<String, PlateRegistration> _plateDatabase = {};
  final List<StreamController<Alert>> _alertStreams = [];

  bool _isInitialized = false;
  String? _currentUserId;

  /// Initialize the premium backend service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Simulate initialization delay
      await Future.delayed(const Duration(seconds: 1));

      // Initialize with demo data for premium experience
      await _seedDemoData();

      _isInitialized = true;
      debugPrint('✅ Premium Backend Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize Premium Backend Service: $e');
      throw const PremiumBackendException('Initialization failed', code: 'INIT_ERROR');
    }
  }

  /// Create user account with premium features
  Future<UserProfile> createAccount({
    required String email,
    required String username,
    required List<String> licensePlates,
  }) async {
    _ensureInitialized();

    try {
      final userId = _generateUserId();

      // Hash license plates for privacy
      final hashedPlates = <String, String>{};
      for (final plate in licensePlates) {
        final hashedPlate = _hashLicensePlate(plate);
        hashedPlates[hashedPlate] = plate;

        // Register plate in database
        _plateDatabase[hashedPlate] = PlateRegistration(
          hashedPlate: hashedPlate,
          userId: userId,
          registeredAt: DateTime.now(),
          isVerified: true, // Auto-verify for premium experience
        );
      }

      // Create user profile
      final profile = UserProfile(
        userId: userId,
        email: email,
        username: username,
        hashedPlates: hashedPlates.keys.toList(),
        reputationScore: 1000, // Premium starting score
        isPremium: true,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      _userDatabase[userId] = profile;
      _currentUserId = userId;

      return profile;
    } catch (e) {
      throw const PremiumBackendException('Account creation failed', code: 'CREATE_ACCOUNT_ERROR');
    }
  }

  /// Send premium alert with real-time delivery
  Future<AlertResponse> sendAlert({
    required String targetPlateNumber,
    required AlertUrgency urgency,
    String? customMessage,
  }) async {
    _ensureInitialized();

    if (_currentUserId == null) {
      throw const PremiumBackendException('User not authenticated', code: 'AUTH_ERROR');
    }

    try {
      final hashedPlate = _hashLicensePlate(targetPlateNumber);
      final plateRegistration = _plateDatabase[hashedPlate];

      if (plateRegistration == null) {
        throw const PremiumBackendException('License plate not registered', code: 'PLATE_NOT_FOUND');
      }

      final alertId = _generateAlertId();
      final alert = Alert(
        alertId: alertId,
        senderId: _currentUserId!,
        receiverId: plateRegistration.userId,
        targetPlate: hashedPlate,
        urgencyLevel: urgency,
        customMessage: customMessage,
        status: AlertStatus.sent,
        sentAt: DateTime.now(),
        expiresAt: DateTime.now().add(_getExpirationDuration(urgency)),
      );

      _alertDatabase[alertId] = alert;

      // Simulate real-time delivery with premium timing
      _scheduleAlertDelivery(alert);

      return AlertResponse(
        alertId: alertId,
        estimatedDeliveryTime: const Duration(seconds: 2),
        targetUserId: plateRegistration.userId,
        success: true,
      );
    } catch (e) {
      if (e is PremiumBackendException) rethrow;
      throw const PremiumBackendException('Failed to send alert', code: 'SEND_ALERT_ERROR');
    }
  }

  /// Stream real-time alerts for user
  Stream<Alert> getAlertStream(String userId) {
    final controller = StreamController<Alert>.broadcast();
    _alertStreams.add(controller);

    // Filter alerts for this user
    _alertDatabase.values
        .where((alert) => alert.receiverId == userId || alert.senderId == userId)
        .forEach(controller.add);

    return controller.stream;
  }

  /// Update alert status (acknowledge, resolve, etc.)
  Future<void> updateAlertStatus({
    required String alertId,
    required AlertStatus newStatus,
    String? response,
  }) async {
    _ensureInitialized();

    final alert = _alertDatabase[alertId];
    if (alert == null) {
      throw const PremiumBackendException('Alert not found', code: 'ALERT_NOT_FOUND');
    }

    final updatedAlert = alert.copyWith(
      status: newStatus,
      respondedAt: newStatus == AlertStatus.acknowledged ? DateTime.now() : alert.respondedAt,
      resolvedAt: newStatus == AlertStatus.resolved ? DateTime.now() : alert.resolvedAt,
      response: response ?? alert.response,
    );

    _alertDatabase[alertId] = updatedAlert;

    // Update reputation scores based on resolution
    if (newStatus == AlertStatus.resolved) {
      await _updateReputationScores(updatedAlert);
    }

    // Broadcast update to streams
    for (final controller in _alertStreams) {
      controller.add(updatedAlert);
    }
  }

  /// Get user reputation and statistics
  Future<UserReputation> getUserReputation(String userId) async {
    _ensureInitialized();

    final user = _userDatabase[userId];
    if (user == null) {
      throw const PremiumBackendException('User not found', code: 'USER_NOT_FOUND');
    }

    final alertsAsReceiver = _alertDatabase.values
        .where((alert) => alert.receiverId == userId)
        .toList();

    final alertsAsSender = _alertDatabase.values
        .where((alert) => alert.senderId == userId)
        .toList();

    final totalReceived = alertsAsReceiver.length;
    final acknowledgedCount = alertsAsReceiver
        .where((alert) => alert.status == AlertStatus.acknowledged || alert.status == AlertStatus.resolved)
        .length;

    final totalSent = alertsAsSender.length;
    final resolvedCount = alertsAsSender
        .where((alert) => alert.status == AlertStatus.resolved)
        .length;

    final responseRate = totalReceived > 0 ? (acknowledgedCount / totalReceived) * 100 : 100.0;
    final resolutionRate = totalSent > 0 ? (resolvedCount / totalSent) * 100 : 100.0;

    return UserReputation(
      userId: userId,
      currentScore: user.reputationScore,
      responseRate: responseRate,
      resolutionRate: resolutionRate,
      totalAlertsReceived: totalReceived,
      totalAlertsSent: totalSent,
      averageResponseTime: _calculateAverageResponseTime(alertsAsReceiver),
      rank: _calculateUserRank(user.reputationScore),
      badges: _calculateBadges(user, alertsAsReceiver, alertsAsSender),
    );
  }

  /// Hash license plate for privacy
  String _hashLicensePlate(String plateNumber) {
    final normalizedPlate = plateNumber.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    const salt = 'YUH_BLOCKIN_PREMIUM_SALT_2025';
    final bytes = utf8.encode('$normalizedPlate$salt');
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16); // First 16 characters for efficiency
  }

  String _generateUserId() {
    return 'user_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  String _generateAlertId() {
    return 'alert_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  Duration _getExpirationDuration(AlertUrgency urgency) {
    switch (urgency) {
      case AlertUrgency.low:
        return const Duration(hours: 2);
      case AlertUrgency.normal:
        return const Duration(hours: 1);
      case AlertUrgency.high:
        return const Duration(minutes: 30);
      case AlertUrgency.urgent:
        return const Duration(minutes: 15);
    }
  }

  void _scheduleAlertDelivery(Alert alert) {
    // Simulate realistic delivery timing based on urgency
    Duration deliveryDelay;
    switch (alert.urgencyLevel) {
      case AlertUrgency.urgent:
        deliveryDelay = const Duration(seconds: 1);
        break;
      case AlertUrgency.high:
        deliveryDelay = const Duration(seconds: 2);
        break;
      case AlertUrgency.normal:
        deliveryDelay = const Duration(seconds: 3);
        break;
      case AlertUrgency.low:
        deliveryDelay = const Duration(seconds: 5);
        break;
    }

    Timer(deliveryDelay, () {
      final updatedAlert = alert.copyWith(
        status: AlertStatus.delivered,
        deliveredAt: DateTime.now(),
      );
      _alertDatabase[alert.alertId] = updatedAlert;

      // Broadcast to streams
      for (final controller in _alertStreams) {
        controller.add(updatedAlert);
      }

      // Schedule auto-acknowledgment for demo purposes
      _scheduleAutoAcknowledgment(updatedAlert);
    });
  }

  void _scheduleAutoAcknowledgment(Alert alert) {
    // Auto-acknowledge after realistic delay for demo
    Timer(const Duration(seconds: 8), () {
      final acknowledgedAlert = alert.copyWith(
        status: AlertStatus.acknowledged,
        respondedAt: DateTime.now(),
        response: 'Moving now, thanks for the respectful alert!',
      );
      _alertDatabase[alert.alertId] = acknowledgedAlert;

      // Broadcast update
      for (final controller in _alertStreams) {
        controller.add(acknowledgedAlert);
      }

      // Schedule resolution
      Timer(const Duration(seconds: 12), () {
        final resolvedAlert = acknowledgedAlert.copyWith(
          status: AlertStatus.resolved,
          resolvedAt: DateTime.now(),
        );
        _alertDatabase[alert.alertId] = resolvedAlert;

        // Update reputation
        _updateReputationScores(resolvedAlert);

        // Broadcast final update
        for (final controller in _alertStreams) {
          controller.add(resolvedAlert);
        }
      });
    });
  }

  Future<void> _updateReputationScores(Alert alert) async {
    // Update sender score (positive for resolved alerts)
    final sender = _userDatabase[alert.senderId];
    if (sender != null) {
      final newSenderScore = sender.reputationScore + 10;
      _userDatabase[alert.senderId] = sender.copyWith(reputationScore: newSenderScore);
    }

    // Update receiver score (positive for quick responses)
    final receiver = _userDatabase[alert.receiverId];
    if (receiver != null && alert.respondedAt != null) {
      final responseTime = alert.respondedAt!.difference(alert.sentAt);
      final bonus = responseTime.inMinutes < 5 ? 15 : 5; // Quick response bonus
      final newReceiverScore = receiver.reputationScore + bonus;
      _userDatabase[alert.receiverId] = receiver.copyWith(reputationScore: newReceiverScore);
    }
  }

  Duration _calculateAverageResponseTime(List<Alert> alerts) {
    final respondedAlerts = alerts.where((alert) => alert.respondedAt != null).toList();
    if (respondedAlerts.isEmpty) return Duration.zero;

    final totalMinutes = respondedAlerts
        .map((alert) => alert.respondedAt!.difference(alert.sentAt).inMinutes)
        .reduce((a, b) => a + b);

    return Duration(minutes: (totalMinutes / respondedAlerts.length).round());
  }

  String _calculateUserRank(int score) {
    if (score >= 2000) return 'Platinum Blocker';
    if (score >= 1500) return 'Gold Blocker';
    if (score >= 1000) return 'Silver Blocker';
    if (score >= 500) return 'Bronze Blocker';
    return 'New Blocker';
  }

  List<String> _calculateBadges(UserProfile user, List<Alert> received, List<Alert> sent) {
    final badges = <String>[];

    if (user.reputationScore >= 1500) badges.add('Respectful Champion');
    if (received.where((a) => a.status == AlertStatus.resolved).length >= 10) {
      badges.add('Quick Resolver');
    }
    if (sent.where((a) => a.status == AlertStatus.resolved).length >= 5) {
      badges.add('Polite Alerter');
    }
    if (user.isPremium) badges.add('Premium Member');

    return badges;
  }

  Future<void> _seedDemoData() async {
    // Create demo user for testing
    await createAccount(
      email: 'demo@yuhblockin.com',
      username: 'DemoUser',
      licensePlates: ['ABC123', 'XYZ789'],
    );
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw const PremiumBackendException('Service not initialized', code: 'NOT_INITIALIZED');
    }
  }

  void dispose() {
    for (final controller in _alertStreams) {
      controller.close();
    }
    _alertStreams.clear();
  }
}

// Data Models

enum AlertUrgency { low, normal, high, urgent }
enum AlertStatus { sent, delivered, acknowledged, resolved, expired, cancelled }

class Alert {
  final String alertId;
  final String senderId;
  final String receiverId;
  final String targetPlate;
  final AlertUrgency urgencyLevel;
  final String? customMessage;
  final AlertStatus status;
  final DateTime sentAt;
  final DateTime? deliveredAt;
  final DateTime? respondedAt;
  final DateTime? resolvedAt;
  final DateTime expiresAt;
  final String? response;

  const Alert({
    required this.alertId,
    required this.senderId,
    required this.receiverId,
    required this.targetPlate,
    required this.urgencyLevel,
    this.customMessage,
    required this.status,
    required this.sentAt,
    this.deliveredAt,
    this.respondedAt,
    this.resolvedAt,
    required this.expiresAt,
    this.response,
  });

  Alert copyWith({
    String? alertId,
    String? senderId,
    String? receiverId,
    String? targetPlate,
    AlertUrgency? urgencyLevel,
    String? customMessage,
    AlertStatus? status,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? respondedAt,
    DateTime? resolvedAt,
    DateTime? expiresAt,
    String? response,
  }) {
    return Alert(
      alertId: alertId ?? this.alertId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      targetPlate: targetPlate ?? this.targetPlate,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      customMessage: customMessage ?? this.customMessage,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      respondedAt: respondedAt ?? this.respondedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      response: response ?? this.response,
    );
  }
}

class UserProfile {
  final String userId;
  final String email;
  final String username;
  final List<String> hashedPlates;
  final int reputationScore;
  final bool isPremium;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  const UserProfile({
    required this.userId,
    required this.email,
    required this.username,
    required this.hashedPlates,
    required this.reputationScore,
    required this.isPremium,
    required this.createdAt,
    required this.lastActiveAt,
  });

  UserProfile copyWith({
    String? userId,
    String? email,
    String? username,
    List<String>? hashedPlates,
    int? reputationScore,
    bool? isPremium,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      username: username ?? this.username,
      hashedPlates: hashedPlates ?? this.hashedPlates,
      reputationScore: reputationScore ?? this.reputationScore,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
}

class PlateRegistration {
  final String hashedPlate;
  final String userId;
  final DateTime registeredAt;
  final bool isVerified;

  const PlateRegistration({
    required this.hashedPlate,
    required this.userId,
    required this.registeredAt,
    required this.isVerified,
  });
}

class AlertResponse {
  final String alertId;
  final Duration estimatedDeliveryTime;
  final String targetUserId;
  final bool success;

  const AlertResponse({
    required this.alertId,
    required this.estimatedDeliveryTime,
    required this.targetUserId,
    required this.success,
  });
}

class UserReputation {
  final String userId;
  final int currentScore;
  final double responseRate;
  final double resolutionRate;
  final int totalAlertsReceived;
  final int totalAlertsSent;
  final Duration averageResponseTime;
  final String rank;
  final List<String> badges;

  const UserReputation({
    required this.userId,
    required this.currentScore,
    required this.responseRate,
    required this.resolutionRate,
    required this.totalAlertsReceived,
    required this.totalAlertsSent,
    required this.averageResponseTime,
    required this.rank,
    required this.badges,
  });
}

class PremiumBackendException implements Exception {
  final String message;
  final String code;

  const PremiumBackendException(this.message, {required this.code});

  @override
  String toString() => 'PremiumBackendException($code): $message';
}