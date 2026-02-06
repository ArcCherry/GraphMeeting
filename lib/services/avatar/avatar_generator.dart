/// 头像生成服务
/// 
/// 负责生成各种类型的头像：
/// - Identicon（基于哈希的图案）
/// - 预设头像
/// 
/// 纯函数，无状态，易于测试

import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../models/user/user_profile.dart';

/// 头像生成器
class AvatarGenerator {
  const AvatarGenerator();

  /// 生成 Identicon 头像（类似 GitHub）
  /// 
  /// [seed] - 种子字符串（通常是用户昵称）
  /// [color] - 主题色（ARGB 格式）
  /// [size] - 输出图片尺寸（默认 256x256）
  /// [cells] - 网格数量（默认 5x5）
  Future<Uint8List> generateIdenticon(
    String seed,
    int color, {
    int size = 256,
    int cells = 5,
  }) async {
    final cellSize = size ~/ cells;
    final padding = cellSize ~/ 2;

    // 使用种子创建可重复的随机
    final random = Random(seed.hashCode);

    // 创建图像
    final image = img.Image(width: size, height: size);

    // 背景色
    final bgColor = img.ColorRgb8(240, 240, 240);
    img.fill(image, color: bgColor);

    // 主色调
    final mainColor = img.ColorRgb8(
      (color >> 16) & 0xFF,
      (color >> 8) & 0xFF,
      color & 0xFF,
    );

    // 生成对称图案（5x5 网格，左右对称）
    for (var y = 0; y < cells; y++) {
      for (var x = 0; x < (cells + 1) ~/ 2; x++) {
        if (random.nextBool()) {
          // 左半部分
          img.fillRect(
            image,
            x1: padding + x * cellSize,
            y1: padding + y * cellSize,
            x2: padding + (x + 1) * cellSize,
            y2: padding + (y + 1) * cellSize,
            color: mainColor,
          );

          // 右半部分（镜像）
          if (x < cells ~/ 2) {
            img.fillRect(
              image,
              x1: padding + (cells - 1 - x) * cellSize,
              y1: padding + y * cellSize,
              x2: padding + (cells - x) * cellSize,
              y2: padding + (y + 1) * cellSize,
              color: mainColor,
            );
          }
        }
      }
    }

    // 添加圆角效果（简化：添加边框）
    final borderColor = img.ColorRgb8(200, 200, 200);
    img.drawRect(
      image,
      x1: 0,
      y1: 0,
      x2: size - 1,
      y2: size - 1,
      color: borderColor,
    );

    return Uint8List.fromList(img.encodePng(image));
  }

  /// 生成预设头像（基于样式）
  /// 
  /// 实际上使用不同的种子生成 Identicon
  Future<Uint8List> generatePresetAvatar(
    PresetAvatarStyle style,
    int color,
  ) async {
    final seed = '${style.value}_${DateTime.now().millisecondsSinceEpoch}';
    return generateIdenticon(seed, color);
  }

  /// 获取可用颜色列表
  static List<int> get availableColors => [
        0xFF0078D4, // WinUI 蓝
        0xFF107C10, // 绿色
        0xFFD83B01, // 橙色
        0xFFB4009E, // 紫色
        0xFF038387, // 青色
        0xFF737373, // 灰色
        0xFFD13438, // 红色
        0xFF881798, // 深紫
        0xFF00B294, // 薄荷
        0xFFFFB900, // 黄色
      ];

  /// 获取预设头像选项列表
  static List<PresetAvatarOption> get presetOptions => [
        const PresetAvatarOption(
          style: PresetAvatarStyle.modern,
          label: '现代',
          icon: 'face',
        ),
        const PresetAvatarOption(
          style: PresetAvatarStyle.classic,
          label: '经典',
          icon: 'person',
        ),
        const PresetAvatarOption(
          style: PresetAvatarStyle.pixel,
          label: '像素',
          icon: 'grid_on',
        ),
        const PresetAvatarOption(
          style: PresetAvatarStyle.minimal,
          label: '极简',
          icon: 'circle',
        ),
        const PresetAvatarOption(
          style: PresetAvatarStyle.vibrant,
          label: '鲜艳',
          icon: 'palette',
        ),
      ];
}

/// 预设头像选项
class PresetAvatarOption {
  final PresetAvatarStyle style;
  final String label;
  final String icon;

  const PresetAvatarOption({
    required this.style,
    required this.label,
    required this.icon,
  });
}
