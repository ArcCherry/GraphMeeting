/// 应用常量
class AppConstants {
  AppConstants._();

  /// 应用名称
  static const String appName = 'GraphMeeting';

  /// 应用版本
  static const String appVersion = '0.1.0';

  /// 默认房间 ID 前缀
  static const String roomIdPrefix = 'gm-';

  /// 默认端口
  static const int defaultPort = 0; // 随机端口

  /// 时间轴缩放因子
  static const double defaultTimeScale = 0.001;

  /// 螺旋柱半径
  static const double defaultSpiralRadius = 50.0;

  /// 参与者轨道间距（度）
  static const double defaultLaneSpacing = 30.0;

  /// Z 轴深度间距
  static const double defaultDepthSpacing = 10.0;

  /// 最小分叉时间差（毫秒）
  static const int defaultBranchThresholdMs = 60000;

  /// 最大轨迹长度
  static const int maxTrailLength = 100;

  /// 默认回放速度
  static const double defaultReplaySpeed = 1.0;

  /// 最大回放速度
  static const double maxReplaySpeed = 100.0;

  /// 默认相机高度
  static const double defaultCameraHeight = 100.0;

  /// 默认相机 FOV
  static const double defaultCameraFov = 60.0;
}
