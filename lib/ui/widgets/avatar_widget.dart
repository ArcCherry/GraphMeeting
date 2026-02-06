/// 头像显示组件
/// 
/// 支持多种头像类型：预设、自定义、生成、网络

import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/user/user_profile.dart';
import '../../services/avatar/avatar_generator.dart';

/// 头像组件
class AvatarWidget extends StatelessWidget {
  final UserProfile? user;
  final double size;
  final bool showBorder;
  final VoidCallback? onTap;
  final bool isOnline;
  
  const AvatarWidget({
    super.key,
    this.user,
    this.size = 40,
    this.showBorder = true,
    this.onTap,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar = _buildAvatarContent();
    
    if (showBorder) {
      avatar = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: user != null 
                ? Color(user!.accentColor) 
                : AppTheme.borderPrimary,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (user != null ? Color(user!.accentColor) : Colors.black)
                  .withValues(alpha: 0.1),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipOval(child: avatar),
      );
    } else {
      avatar = ClipOval(
        child: SizedBox(width: size, height: size, child: avatar),
      );
    }
    
    // 在线状态指示器
    if (isOnline) {
      avatar = Stack(
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.25,
              height: size * 0.25,
              decoration: BoxDecoration(
                color: AppTheme.success,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    if (onTap != null) {
      avatar = GestureDetector(onTap: onTap, child: avatar);
    }
    
    return avatar;
  }
  
  Widget _buildAvatarContent() {
    if (user == null) {
      return _buildPlaceholder();
    }
    
    switch (user!.avatarType) {
      case AvatarType.custom:
        if (user!.avatarData != null) {
          return Image.memory(
            user!.avatarData!,
            fit: BoxFit.cover,
            width: size,
            height: size,
          );
        }
        return _buildGeneratedAvatar();
        
      case AvatarType.network:
        if (user!.avatarUrl != null) {
          return Image.network(
            user!.avatarUrl!,
            fit: BoxFit.cover,
            width: size,
            height: size,
            errorBuilder: (_, __, ___) => _buildGeneratedAvatar(),
          );
        }
        return _buildGeneratedAvatar();
        
      case AvatarType.preset:
      case AvatarType.generated:
        return _buildGeneratedAvatar();
    }
  }
  
  Widget _buildGeneratedAvatar() {
    return FutureBuilder<Uint8List>(
      future: const AvatarGenerator().generateIdenticon(
        user?.nickname ?? 'User',
        user?.accentColor ?? 0xFF0078D4,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            width: size,
            height: size,
          );
        }
        return _buildPlaceholder();
      },
    );
  }
  
  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.backgroundSecondary,
      child: Icon(
        Icons.person,
        size: size * 0.5,
        color: AppTheme.textTertiary,
      ),
    );
  }
}

/// 头像组（用于显示多个用户）
class AvatarGroup extends StatelessWidget {
  final List<UserProfile> users;
  final double avatarSize;
  final double overlap;
  final int maxDisplay;
  final VoidCallback? onOverflowTap;
  
  const AvatarGroup({
    super.key,
    required this.users,
    this.avatarSize = 32,
    this.overlap = 8,
    this.maxDisplay = 4,
    this.onOverflowTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayUsers = users.take(maxDisplay).toList();
    final remaining = users.length - maxDisplay;
    
    return SizedBox(
      height: avatarSize,
      child: Stack(
        children: [
          for (var i = 0; i < displayUsers.length; i++)
            Positioned(
              left: i * (avatarSize - overlap),
              child: AvatarWidget(
                user: displayUsers[i],
                size: avatarSize,
              ),
            ),
          if (remaining > 0)
            Positioned(
              left: displayUsers.length * (avatarSize - overlap),
              child: GestureDetector(
                onTap: onOverflowTap,
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundSecondary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '+$remaining',
                      style: AppTheme.textCaption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 带名称的头像
class UserChip extends StatelessWidget {
  final UserProfile user;
  final VoidCallback? onTap;
  final bool showStatus;
  final bool isCompact;
  
  const UserChip({
    super.key,
    required this.user,
    this.onTap,
    this.showStatus = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AvatarWidget(
          user: user,
          size: isCompact ? 24 : 32,
          showBorder: false,
        ),
        if (!isCompact) ...[
          const SizedBox(width: AppTheme.spaceSm),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.nickname,
                  style: AppTheme.textBody.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (showStatus && user.statusMessage != null)
                  Text(
                    user.statusMessage!,
                    style: AppTheme.textCaption.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
    
    if (isCompact) {
      return content;
    }
    
    return FluentCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSm,
        vertical: AppTheme.spaceXs,
      ),
      onTap: onTap,
      child: content,
    );
  }
}
