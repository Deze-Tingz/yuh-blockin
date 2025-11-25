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
    if (kDebugMode) {
      print('🔍 getOrCreateUser() called');
    }

    _ensureInitialized();

    final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';

    if (kDebugMode) {
      print('🔍 Generated userId: $userId');
      print('🔍 About to insert into users table...');
    }

    try {
      final result = await _supabase.from('users').insert({'id': userId});

      if (kDebugMode) {
        print('🔍 Insert result: $result');
        print('👤 ✅ Created user: $userId');
      }

      return userId;
    } catch (e) {
      if (kDebugMode) {
        print('❌ User creation failed: $e');
        print('❌ Error type: ${e.runtimeType}');
        print('❌ Error details: $e');
      }
      rethrow; // Re-throw so calling code knows it failed
    }
  }

  /// Check if a user exists in the database
  Future<bool> userExists(String userId) async {
    try {
      _ensureInitialized();

      final result = await _supabase
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      return result != null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking user existence: $e');
      }
      return false;
    }
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
          alertId: result['alert_id']?.toString(),
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
        .expand((data) => data) // Flatten the list of alerts
        .map((item) => Alert.fromJson(item)); // Convert each item to Alert
  }

  /// Mark alert as read
  Future<void> markAlertRead(String alertId) async {
    _ensureInitialized();

    await _supabase
        .from('alerts')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', alertId);
  }

  /// Send response to an alert
  Future<bool> sendResponse({
    required String alertId,
    required String response,
    String? responseMessage,
  }) async {
    _ensureInitialized();

    try {
      await _supabase
          .from('alerts')
          .update({
            'response': response,
            'response_message': responseMessage,
            'response_at': DateTime.now().toIso8601String(),
            'read_at': DateTime.now().toIso8601String(), // Also mark as read
          })
          .eq('id', alertId);

      if (kDebugMode) {
        print('✅ Response sent: $response for alert: $alertId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to send response: $e');
      }
      return false;
    }
  }

  /// Get real-time stream of alerts I've sent (to see responses)
  Stream<List<Alert>> getSentAlertsStream(String userId) {
    _ensureInitialized();

    return _supabase
        .from('alerts')
        .stream(primaryKey: ['id'])
        .eq('sender_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((item) => Alert.fromJson(item)).toList());
  }

  /// Get snapshot of alerts I've sent (useful for syncing acknowledgments)
  Future<List<Alert>> getSentAlerts(String userId) async {
    _ensureInitialized();

    try {
      final response = await _supabase
          .from('alerts')
          .select()
          .eq('sender_id', userId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((item) => Alert.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting sent alerts: $e');
      }
      return [];
    }
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
  final String? alertId; // Added for unacknowledged alert tracking

  AlertResult({
    required this.success,
    required this.recipients,
    this.error,
    this.alertId,
  });
}

class Alert {
  final String id;
  final String senderId;
  final String receiverId;
  final String plateHash;
  final String? message;
  final String? response; // moving_now, 5_minutes, cant_move, wrong_car
  final String? responseMessage; // optional custom response
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? responseAt;

  Alert({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.plateHash,
    this.message,
    this.response,
    this.responseMessage,
    required this.createdAt,
    this.readAt,
    this.responseAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      plateHash: json['plate_hash'],
      message: json['message'],
      response: json['response'],
      responseMessage: json['response_message'],
      createdAt: DateTime.parse(json['created_at']),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      responseAt: json['response_at'] != null ? DateTime.parse(json['response_at']) : null,
    );
  }

  /// Check if alert has been responded to
  bool get hasResponse => response != null;

  /// Get human-readable response text
  String get responseText {
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
        return 'No response';
    }
  }
}