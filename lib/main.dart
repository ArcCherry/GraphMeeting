import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_router.dart';
import 'core/theme.dart';
import 'services/database/database_providers.dart';
import 'services/user/user_identity_service.dart';
import 'ui/screens/world_list_screen.dart';
import 'ui/screens/profile/user_setup_screen.dart';
import 'ui/widgets/avatar_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化数据库
  final container = ProviderContainer();
  await container.read(databaseServiceProvider).database;
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const GraphMeetingApp(),
    ),
  );
}

class GraphMeetingApp extends StatelessWidget {
  const GraphMeetingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GraphMeeting',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      onGenerateRoute: AppRouter.generateRoute,
      home: const AppEntryPoint(),
    );
  }
}

/// 应用入口点
class AppEntryPoint extends ConsumerStatefulWidget {
  const AppEntryPoint({super.key});

  @override
  ConsumerState<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends ConsumerState<AppEntryPoint> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(userIdentityServiceProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userIdentityServiceProvider);
    
    if (userState.isLoading) {
      return const _LoadingScreen();
    }
    
    if (userState.error != null) {
      return _ErrorScreen(
        error: userState.error!,
        onRetry: () => ref.read(userIdentityServiceProvider.notifier).initialize(),
      );
    }
    
    if (!userState.isLoggedIn) {
      return const UserSetupScreen(mode: UserSetupMode.firstTime);
    }
    
    return const WorldListScreen();
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackgroundBase,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(AppTheme.accentPrimary),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'GraphMeeting',
              style: AppTheme.textHeading2.copyWith(
                color: AppTheme.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '正在初始化...',
              style: AppTheme.textBody.copyWith(
                color: AppTheme.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  
  const _ErrorScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackgroundBase,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  '出错了',
                  style: AppTheme.textHeading2.copyWith(
                    color: AppTheme.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  error,
                  style: AppTheme.textBody.copyWith(
                    color: AppTheme.darkTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 当前用户头像按钮
class CurrentUserAvatar extends ConsumerWidget {
  final double size;
  
  const CurrentUserAvatar({super.key, this.size = 36});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: AvatarWidget(
        user: user,
        size: size,
        onTap: () => _showUserMenu(context, ref),
      ),
    );
  }
  
  void _showUserMenu(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 200,
        60,
        16,
        0,
      ),
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem(
          enabled: false,
          child: UserChip(user: user),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<dynamic>(
          child: const Row(
            children: [
              Icon(Icons.edit),
              SizedBox(width: 8),
              Text('编辑资料'),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              AppNavigator.toProfile(context);
            });
          },
        ),
        PopupMenuItem<dynamic>(
          child: const Row(
            children: [
              Icon(Icons.settings),
              SizedBox(width: 8),
              Text('设置'),
            ],
          ),
          onTap: () {},
        ),
        const PopupMenuDivider(),
        PopupMenuItem<dynamic>(
          child: Row(
            children: [
              Icon(Icons.logout, color: AppTheme.error),
              const SizedBox(width: 8),
              Text('退出登录', style: TextStyle(color: AppTheme.error)),
            ],
          ),
          onTap: () async {
            await ref.read(userIdentityServiceProvider.notifier).logout();
          },
        ),
      ],
    );
  }
}
