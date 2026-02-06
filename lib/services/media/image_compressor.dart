/// 图片压缩服务
/// 
/// 提供图片压缩和格式转换功能

import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// 压缩配置
class CompressionConfig {
  final int maxSize;
  final int quality;
  final ImageFormat format;

  const CompressionConfig({
    this.maxSize = 256,
    this.quality = 85,
    this.format = ImageFormat.jpeg,
  });

  /// 头像压缩配置
  static const avatar = CompressionConfig(
    maxSize: 256,
    quality: 85,
    format: ImageFormat.jpeg,
  );

  /// 缩略图压缩配置
  static const thumbnail = CompressionConfig(
    maxSize: 128,
    quality: 70,
    format: ImageFormat.jpeg,
  );

  /// 高清压缩配置
  static const highQuality = CompressionConfig(
    maxSize: 512,
    quality: 90,
    format: ImageFormat.png,
  );
}

/// 图片格式
enum ImageFormat { jpeg, png, webp }

/// 图片压缩器
class ImageCompressor {
  const ImageCompressor();

  /// 压缩图片
  /// 
  /// [data] - 原始图片数据
  /// [config] - 压缩配置
  Future<Uint8List> compress(
    Uint8List data, {
    CompressionConfig config = CompressionConfig.avatar,
  }) async {
    try {
      final original = img.decodeImage(data);
      if (original == null) {
        throw ImageCompressionException('无法解码图片');
      }

      // 调整大小
      final resized = _resize(original, config.maxSize);

      // 编码
      return _encode(resized, config);
    } catch (e) {
      if (e is ImageCompressionException) rethrow;
      throw ImageCompressionException('压缩失败: $e');
    }
  }

  /// 调整图片大小（保持比例）
  img.Image _resize(img.Image original, int maxSize) {
    if (original.width <= maxSize && original.height <= maxSize) {
      return original;
    }

    if (original.width > original.height) {
      return img.copyResize(original, width: maxSize);
    } else {
      return img.copyResize(original, height: maxSize);
    }
  }

  /// 编码图片
  Uint8List _encode(img.Image image, CompressionConfig config) {
    switch (config.format) {
      case ImageFormat.jpeg:
        return Uint8List.fromList(
          img.encodeJpg(image, quality: config.quality),
        );
      case ImageFormat.png:
        return Uint8List.fromList(img.encodePng(image));
      case ImageFormat.webp:
        // WebP 支持需要额外配置，fallback 到 JPEG
        return Uint8List.fromList(
          img.encodeJpg(image, quality: config.quality),
        );
    }
  }

  /// 获取图片信息
  Future<ImageInfo> getInfo(Uint8List data) async {
    final image = img.decodeImage(data);
    if (image == null) {
      throw ImageCompressionException('无法解码图片');
    }

    return ImageInfo(
      width: image.width,
      height: image.height,
      sizeInBytes: data.length,
    );
  }
}

/// 图片信息
class ImageInfo {
  final int width;
  final int height;
  final int sizeInBytes;

  const ImageInfo({
    required this.width,
    required this.height,
    required this.sizeInBytes,
  });

  double get aspectRatio => width / height;
  String get resolution => '${width}x$height';
  String get sizeInKB => '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
}

/// 图片压缩异常
class ImageCompressionException implements Exception {
  final String message;

  const ImageCompressionException(this.message);

  @override
  String toString() => 'ImageCompressionException: $message';
}
