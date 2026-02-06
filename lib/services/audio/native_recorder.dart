import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 原生音频录制服务
/// 通过平台通道调用 macOS/iOS 原生 AVAudioRecorder
class NativeAudioRecorder {
  static const MethodChannel _channel = MethodChannel('graphmeeting/audio_recorder');
  static const EventChannel _levelChannel = EventChannel('graphmeeting/audio_level');
  
  static final NativeAudioRecorder _instance = NativeAudioRecorder._internal();
  factory NativeAudioRecorder() => _instance;
  NativeAudioRecorder._internal();
  
  Stream<double>? _audioLevelStream;
  String? _currentRecordingPath;
  
  /// 获取音频电平流（实时波形数据）
  Stream<double> get audioLevelStream {
    _audioLevelStream ??= _levelChannel
        .receiveBroadcastStream()
        .map((level) => (level as num).toDouble())
        .asBroadcastStream();
    return _audioLevelStream!;
  }
  
  /// 请求录音权限
  Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } catch (e) {
      print('Error requesting permission: $e');
      return false;
    }
  }
  
  /// 开始录音
  /// 返回录音文件的完整路径
  Future<String?> startRecording() async {
    try {
      // 创建临时文件路径
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${tempDir.path}/recording_$timestamp.m4a';
      
      final result = await _channel.invokeMethod<String>('startRecording', {
        'path': path,
      });
      
      if (result != null) {
        _currentRecordingPath = result;
        return result;
      }
      return null;
    } catch (e) {
      print('Error starting recording: $e');
      return null;
    }
  }
  
  /// 停止录音
  /// 返回录音文件的完整路径
  Future<String?> stopRecording() async {
    try {
      final result = await _channel.invokeMethod<String>('stopRecording');
      return result;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }
  
  /// 检查是否正在录音
  Future<bool> isRecording() async {
    try {
      final result = await _channel.invokeMethod<bool>('isRecording');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// 获取当前录音时长（秒）
  Future<double> getCurrentTime() async {
    try {
      final result = await _channel.invokeMethod<double>('getCurrentTime');
      return result ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }
  
  /// 获取当前音频电平（0.0 - 1.0）
  Future<double> getAudioLevel() async {
    try {
      final result = await _channel.invokeMethod<double>('getAudioLevel');
      return result ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }
  
  /// 删除录音文件
  Future<void> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting recording: $e');
    }
  }
  
  /// 获取录音文件
  Future<File?> getRecordingFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return file;
    }
    return null;
  }
}
