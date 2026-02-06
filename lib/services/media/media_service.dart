/// 媒体服务
/// 
/// 处理图片、文件选择
/// 注意：语音录制功能暂未实现

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

/// 媒体文件信息
class MediaFile {
  final String id;
  final String path;
  final String name;
  final int size;
  final MediaType type;
  final String? mimeType;
  final Duration? duration;

  MediaFile({
    required this.id,
    required this.path,
    required this.name,
    required this.size,
    required this.type,
    this.mimeType,
    this.duration,
  });

  bool get isImage => type == MediaType.image;
  bool get isFile => type == MediaType.file;
  bool get isVoice => type == MediaType.voice;
}

enum MediaType {
  image,
  file,
  voice,
}

/// 媒体服务
class MediaService {
  final ImagePicker _imagePicker = ImagePicker();
  
  /// 选择图片
  Future<MediaFile?> pickImage({bool fromCamera = false}) async {
    try {
      final XFile? file = fromCamera
          ? await _imagePicker.pickImage(source: ImageSource.camera)
          : await _imagePicker.pickImage(source: ImageSource.gallery);
      
      if (file == null) return null;
      
      final fileObj = File(file.path);
      final bytes = await fileObj.length();
      
      return MediaFile(
        id: const Uuid().v4(),
        path: file.path,
        name: path.basename(file.path),
        size: bytes,
        type: MediaType.image,
        mimeType: 'image/${path.extension(file.path).replaceAll('.', '')}',
      );
    } catch (e) {
      debugPrint('选择图片失败: $e');
      return null;
    }
  }
  
  /// 选择多个图片
  Future<List<MediaFile>> pickMultipleImages() async {
    try {
      final List<XFile> files = await _imagePicker.pickMultiImage();
      
      final List<MediaFile> result = [];
      for (final file in files) {
        final fileObj = File(file.path);
        final bytes = await fileObj.length();
        
        result.add(MediaFile(
          id: const Uuid().v4(),
          path: file.path,
          name: path.basename(file.path),
          size: bytes,
          type: MediaType.image,
          mimeType: 'image/${path.extension(file.path).replaceAll('.', '')}',
        ));
      }
      
      return result;
    } catch (e) {
      debugPrint('选择多张图片失败: $e');
      return [];
    }
  }
  
  /// 选择文件
  Future<MediaFile?> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      
      if (result == null || result.files.isEmpty) return null;
      
      final file = result.files.first;
      final filePath = file.path;
      
      if (filePath == null) return null;
      
      return MediaFile(
        id: const Uuid().v4(),
        path: filePath,
        name: file.name,
        size: file.size,
        type: MediaType.file,
        mimeType: file.extension != null 
            ? 'application/${file.extension}' 
            : 'application/octet-stream',
      );
    } catch (e) {
      debugPrint('选择文件失败: $e');
      return null;
    }
  }
  
  // ========== 录音功能（暂未实现）==========
  
  /// 是否正在录音
  bool get isRecording => false;
  
  /// 开始录音（暂未实现）
  Future<bool> startRecording() async {
    debugPrint('录音功能暂未实现');
    return false;
  }
  
  /// 停止录音（暂未实现）
  Future<MediaFile?> stopRecording() async {
    debugPrint('录音功能暂未实现');
    return null;
  }
  
  /// 获取录音时长
  Duration? get recordingDuration => null;
  
  /// 取消录音（暂未实现，保留API兼容性）
  Future<void> cancelRecording() async {
    debugPrint('录音功能暂未实现');
  }
  
  /// 删除媒体文件
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('删除文件失败: $e');
      return false;
    }
  }
  
  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  /// 格式化时长
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
