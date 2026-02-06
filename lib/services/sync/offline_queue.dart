import 'dart:convert';

import 'package:hive/hive.dart';

import '../network/connection_manager.dart';

// 扩展方法导入
extension ClientPingFromJson on ClientPing {
  static ClientPing fromJson(Map<String, dynamic> json) {
    return ClientPing(
      clientTimestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

extension ClientSubmitMessageFromJson on ClientSubmitMessage {
  static ClientSubmitMessage fromJson(Map<String, dynamic> json) {
    return ClientSubmitMessage(
      messageId: json['messageId'] as String,
      content: json['content'] as String,
      replyTo: json['replyTo'] as String?,
      attachments: (json['attachments'] as List<dynamic>?)?.cast<String>(),
    );
  }
}

/// 离线队列
/// 
/// 管理离线时的消息，待网络恢复后自动同步
class OfflineQueue {
  static const String _boxName = 'offline_queue';
  Box<String>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  /// 添加消息到队列
  Future<void> enqueue(ClientMessage message) async {
    if (_box == null) await init();
    
    final key = '${message.timestamp.millisecondsSinceEpoch}_${message.hashCode}';
    final value = jsonEncode({
      'type': message.type,
      'timestamp': message.timestamp.toIso8601String(),
      'data': message.toJson(),
    });
    
    await _box!.put(key, value);
  }

  /// 获取所有待同步的消息
  Future<List<ClientMessage>> getPending() async {
    if (_box == null) await init();
    
    final messages = <ClientMessage>[];
    
    for (final entry in _box!.toMap().entries) {
      try {
        final json = jsonDecode(entry.value);
        final type = json['type'] as String;
        final data = json['data'] as Map<String, dynamic>;
        
        ClientMessage? message;
        switch (type) {
          case 'ping':
            message = ClientPingFromJson.fromJson(data);
            break;
          case 'submit_message':
            message = ClientSubmitMessageFromJson.fromJson(data);
            break;
          // 添加更多消息类型
        }
        
        if (message != null) {
          messages.add(message);
        }
      } catch (e) {
        // 解析失败，删除该条目
        await _box!.delete(entry.key);
      }
    }
    
    // 按时间排序
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  /// 清空队列
  Future<void> clear() async {
    if (_box == null) await init();
    await _box!.clear();
  }

  /// 删除指定消息
  Future<void> remove(String key) async {
    if (_box == null) await init();
    await _box!.delete(key);
  }

  /// 获取队列长度
  Future<int> get length async {
    if (_box == null) await init();
    return _box!.length;
  }
}

// 扩展方法，用于解析消息
extension ClientPingExtension on ClientPing {
  static ClientPing fromJson(Map<String, dynamic> json) {
    return ClientPing(
      clientTimestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

extension ClientSubmitMessageExtension on ClientSubmitMessage {
  static ClientSubmitMessage fromJson(Map<String, dynamic> json) {
    return ClientSubmitMessage(
      messageId: json['messageId'] as String,
      content: json['content'] as String,
      replyTo: json['replyTo'] as String?,
      attachments: (json['attachments'] as List<dynamic>?)?.cast<String>(),
    );
  }
}
