import 'dart:math';

/// 工具函数
class Utils {
  Utils._();

  /// 生成唯一 ID
  static String generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return '${now}_$random';
  }

  /// 生成房间 ID
  static String generateRoomId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final code = StringBuffer();
    for (var i = 0; i < 6; i++) {
      code.write(chars[random.nextInt(chars.length)]);
    }
    return 'gm-${code.toString()}';
  }

  /// 格式化时长
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// 格式化时间戳
  static String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${timestamp.month}月${timestamp.day}日';
    }
  }

  /// 平滑插值
  static double lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  /// 平滑步进函数（ease in-out）
  static double smoothStep(double t) {
    return t * t * (3.0 - 2.0 * t);
  }

  /// 角度转弧度
  static double degToRad(double deg) {
    return deg * pi / 180.0;
  }

  /// 弧度转角度
  static double radToDeg(double rad) {
    return rad * 180.0 / pi;
  }

  /// 限制数值范围
  static T clamp<T extends num>(T value, T min, T max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// 计算两点距离
  static double distance3D(double x1, double y1, double z1, double x2, double y2, double z2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final dz = z2 - z1;
    return sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// 截断文本
  static String truncate(String text, int maxLength, {String suffix = '...'}) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength - suffix.length) + suffix;
  }
}
