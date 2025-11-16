import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Simple and secure alert service
/// - Privacy-first: Only stores SHA256 hashes of license plates
/// - Real-time alerts between users
/// - Minimal complexity, maximum security
class SimpleAlertService {
  static final SimpleAlertService _instance = SimpleAlertService._internal();
  factory SimpleAlertService() => _instance;
  SimpleAlertService._internal();

  late SupabaseClient _supabase;
  bool _isInitialized = false;

  /// Initialize Supabase connection
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Supabase.initialize(
        url: 'https://oazxwglbvzgpehsckmfb.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9henh3Z2xidnpncGVoc2NrbWZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMxNzkzMjEsImV4cCI6MjA3ODc1NTMyMX0.Ia6ccZ1zp4r1mi5mgvQk9wfK5MGp0S3TDhyWngz8Z54',
      );

      _supabase = Supabase.instance.client;
      _isInitialized = true;

      if (kDebugMode) {
        print('✅ Simple Alert Service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize service: $e');
      }
      rethrow;
    }
  }

  /// Create or get user ID
  Future<String> getOrCreateUser() async {
    _ensureInitialized();

    final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';

    await _supabase.from('users').insert({'id': userId});

    if (kDebugMode) {
      print('👤 Created user: $userId');
    }

    return userId;
  }

  /// Register a license plate
  Future<void> registerPlate({
    required String plateNumber,
    required String userId,
  }) async {
    _ensureInitialized();

    final plateHash = _hashPlate(plateNumber);

    try {
      await _supabase.from('plates').insert({
        'user_id': userId,
        'plate_hash': plateHash,
      });

      if (kDebugMode) {
        print('✅ Registered plate: $plateNumber -> $plateHash');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Registration failed: $e');
      }
      rethrow;
    }
  }

  /// Send alert to all users registered for a plate
  Future<AlertResult> sendAlert({
    required String targetPlateNumber,
    required String senderUserId,
    String? message,
  }) async {
    _ensureInitialized();

    final plateHash = _hashPlate(targetPlateNumber);

    try {
      final response = await _supabase.rpc('send_alert', params: {
        'sender_user_id': senderUserId,
        'target_plate_hash': plateHash,
        'alert_message': message,
      });

      final result = response as Map<String, dynamic>;

      if (result['success'] == true) {
        if (kDebugMode) {
          print('📢 Alert sent to ${result['recipients']} users');
        }
        return AlertResult(
          success: true,
          recipients: result['recipients'] ?? 0,
          error: null,
        );
      } else {
        return AlertResult(
          success: false,
          recipients: 0,
          error: result['error']?.toString() ?? 'Unknown error',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Alert failed: $e');
      }
      return AlertResult(
        success: false,
        recipients: 0,
        error: e.toString(),
      );
    }
  }

  /// Get my registered plates
  Future<List<String>> getMyPlates(String userId) async {
    _ensureInitialized();

    try {
      final response = await _supabase
          .from('plates')
          .select('plate_hash')
          .eq('user_id', userId);

      return (response as List)
          .map((row) => row['plate_hash'] as String)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to get plates: $e');
      }
      return [];
    }
  }

  /// Get real-time alerts stream for user
  Stream<Alert> getAlertsStream(String userId) {
    _ensureInitialized();

    return _supabase
        .from('alerts')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .map((data) => Alert.fromJson(data.first));
  }

  /// Mark alert as read
  Future<void> markAlertRead(String alertId) async {
    _ensureInitialized();

    await _supabase
        .from('alerts')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', alertId);
  }

  /// Delete a registered plate
  Future<void> deletePlate({
    required String plateNumber,
    required String userId,
  }) async {
    _ensureInitialized();

    final plateHash = _hashPlate(plateNumber);

    await _supabase
        .from('plates')
        .delete()
        .eq('user_id', userId)
        .eq('plate_hash', plateHash);

    if (kDebugMode) {
      print('🗑️ Deleted plate: $plateNumber');
    }
  }

  // Private helpers

  String _hashPlate(String plateNumber) {
    final normalized = plateNumber.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    final bytes = utf8.encode(normalized);
    return sha256.convert(bytes).toString();
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }
  }
}

// Simple data models

class AlertResult {
  final bool success;
  final int recipients;
  final String? error;

  AlertResult({
    required this.success,
    required this.recipients,
    this.error,
  });
}

class Alert {
  final String id;
  final String senderId;
  final String receiverId;
  final String plateHash;
  final String? message;
  final DateTime createdAt;
  final DateTime? readAt;

  Alert({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.plateHash,
    this.message,
    required this.createdAt,
    this.readAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      plateHash: json['plate_hash'],
      message: json['message'],
      createdAt: DateTime.parse(json['created_at']),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
    );
  }
}