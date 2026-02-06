/// GraphMeeting 应用路由系统
/// 
/// 定义所有页面路由和导航逻辑

import 'package:flutter/material.dart';
import '../models/room.dart';
import '../ui/screens/world_list_screen.dart';
import '../ui/screens/room_detail_screen.dart';
import '../ui/screens/profile/user_setup_screen.dart';
import '../ui/screens/settings/settings_screen.dart';
import '../ui/screens/settings/room_settings_screen.dart';
import '../ui/screens/settings/ai_config_screen.dart';

/// 路由名称常量
class AppRoutes {
  static const String home = '/';
  static const String worlds = '/worlds';
  static const String room = '/room';
  static const String profile = '/profile';
  static const String settings = '/settings';
}

/// 路由生成器
class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
      case AppRoutes.worlds:
        return MaterialPageRoute(
          builder: (_) => const WorldListScreen(),
          settings: settings,
        );
        
      case AppRoutes.room:
        final room = settings.arguments as Room?;
        if (room == null) {
          return _errorRoute('房间数据缺失');
        }
        return MaterialPageRoute(
          builder: (_) => RoomDetailScreen(room: room),
          settings: settings,
        );
        
      case AppRoutes.profile:
        return MaterialPageRoute(
          builder: (_) => const UserSetupScreen(mode: UserSetupMode.edit),
          settings: settings,
        );
        
      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );
        
      case '/ai_config':
        return MaterialPageRoute(
          builder: (_) => const AIConfigScreen(),
          settings: settings,
        );
        
      case '/room_settings':
        final room = settings.arguments as Room?;
        if (room == null) {
          return _errorRoute('房间数据缺失');
        }
        return MaterialPageRoute(
          builder: (_) => RoomSettingsScreen(room: room),
          settings: settings,
        );
        
      default:
        return _errorRoute('页面不存在: ${settings.name}');
    }
  }
  
  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(message),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {},
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 导航帮助类
class AppNavigator {
  static void toWorldList(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.worlds,
      (route) => false,
    );
  }
  
  static void toRoom(BuildContext context, Room room) {
    Navigator.pushNamed(
      context,
      AppRoutes.room,
      arguments: room,
    );
  }
  
  static void toProfile(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.profile);
  }
}
