/// 用户设置界面 - 首次使用或修改资料
/// 
/// 像 Minecraft 一样允许用户自定义身份

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme.dart';
import '../../../models/user/user_profile.dart';
import '../../../services/user/user_identity_service.dart';
import '../../../services/avatar/avatar_generator.dart';

/// 用户设置模式
enum UserSetupMode {
  firstTime,  // 首次使用
  edit,       // 编辑现有资料
}

class UserSetupScreen extends ConsumerStatefulWidget {
  final UserSetupMode mode;
  
  const UserSetupScreen({
    super.key,
    this.mode = UserSetupMode.firstTime,
  });

  @override
  ConsumerState<UserSetupScreen> createState() => _UserSetupScreenState();
}

class _UserSetupScreenState extends ConsumerState<UserSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _statusController = TextEditingController();
  
  int _selectedColor = 0xFF0078D4;
  PresetAvatarStyle _selectedStyle = PresetAvatarStyle.modern;
  AvatarType _avatarType = AvatarType.generated;
  Uint8List? _customAvatar;
  
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    
    // 如果是编辑模式，加载现有数据
    if (widget.mode == UserSetupMode.edit) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        _nicknameController.text = user.nickname;
        _statusController.text = user.statusMessage ?? '';
        _selectedColor = user.accentColor;
        _selectedStyle = user.avatarStyle;
        _avatarType = user.avatarType;
        if (user.avatarData != null) {
          _customAvatar = user.avatarData;
        }
      }
    }
  }
  
  @override
  void dispose() {
    _nicknameController.dispose();
    _statusController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _customAvatar = bytes;
        _avatarType = AvatarType.custom;
      });
    }
  }
  
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    final service = ref.read(userIdentityServiceProvider.notifier);
    
    if (widget.mode == UserSetupMode.firstTime) {
      await service.createUser(
        nickname: _nicknameController.text.trim(),
        avatarType: _avatarType,
        avatarData: _customAvatar,
        accentColor: _selectedColor,
        statusMessage: _statusController.text.trim().isEmpty 
            ? null 
            : _statusController.text.trim(),
        avatarStyle: _selectedStyle,
      );
    } else {
      await service.updateProfile(
        nickname: _nicknameController.text.trim(),
        accentColor: _selectedColor,
        statusMessage: _statusController.text.trim().isEmpty 
            ? null 
            : _statusController.text.trim(),
        avatarStyle: _selectedStyle,
      );
      
      if (_avatarType == AvatarType.custom && _customAvatar != null) {
        await service.updateAvatar(_customAvatar!);
      }
    }
    
    if (!mounted) return;
    
    setState(() => _isLoading = false);
    
    if (widget.mode == UserSetupMode.firstTime) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pop();
    }
  }
  
  Future<void> _regenerateAvatar() async {
    final service = ref.read(userIdentityServiceProvider.notifier);
    await service.regenerateAvatar();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.mode == UserSetupMode.edit;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceXl),
            child: FluentCard(
              padding: const EdgeInsets.all(AppTheme.spaceXl),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      isEditing ? '编辑资料' : '创建你的身份',
                      style: AppTheme.textHeading1.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      isEditing 
                          ? '更新你的个人信息和头像'
                          : '像 Minecraft 一样，设计你独特的身份',
                      style: AppTheme.textBody.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXl),
                    
                    // 头像区域
                    _buildAvatarSection(),
                    const SizedBox(height: AppTheme.spaceXl),
                    
                    // 昵称输入
                    _buildNicknameField(),
                    const SizedBox(height: AppTheme.spaceLg),
                    
                    // 状态消息
                    _buildStatusField(),
                    const SizedBox(height: AppTheme.spaceLg),
                    
                    // 颜色选择
                    _buildColorPicker(),
                    const SizedBox(height: AppTheme.spaceXl),
                    
                    // 操作按钮
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          // 头像预览
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(_selectedColor).withValues(alpha: 0.1),
              border: Border.all(
                color: Color(_selectedColor),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(_selectedColor).withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: _buildAvatarContent(),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          
          // 头像选项
          Wrap(
            spacing: AppTheme.spaceMd,
            runSpacing: AppTheme.spaceMd,
            alignment: WrapAlignment.center,
            children: [
              _buildAvatarOption(
                icon: Icons.auto_fix_high,
                label: '生成',
                isSelected: _avatarType == AvatarType.generated,
                onTap: () {
                  setState(() {
                    _avatarType = AvatarType.generated;
                  });
                  _regenerateAvatar();
                },
              ),
              _buildAvatarOption(
                icon: Icons.upload,
                label: '上传',
                isSelected: _avatarType == AvatarType.custom,
                onTap: _pickImage,
              ),
              _buildAvatarOption(
                icon: Icons.style,
                label: '预设',
                isSelected: _avatarType == AvatarType.preset,
                onTap: () => _showStylePicker(),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildAvatarContent() {
    if (_avatarType == AvatarType.custom && _customAvatar != null) {
      return Image.memory(
        _customAvatar!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
      );
    }
    
    // 生成头像预览
    return FutureBuilder<Uint8List>(
      future: const AvatarGenerator().generateIdenticon(
        _nicknameController.text.isEmpty ? 'User' : _nicknameController.text,
        _selectedColor,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            width: 120,
            height: 120,
          );
        }
        return Icon(
          Icons.person,
          size: 60,
          color: Color(_selectedColor),
        );
      },
    );
  }
  
  Widget _buildAvatarOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FluentButton(
      onPressed: onTap,
      style: isSelected ? FluentButtonStyle.accent : FluentButtonStyle.standard,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: AppTheme.spaceXs),
          Text(label),
        ],
      ),
    );
  }
  
  void _showStylePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          color: AppTheme.backgroundLayer,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLg),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '选择头像风格',
              style: AppTheme.textHeading3,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Wrap(
              spacing: AppTheme.spaceMd,
              runSpacing: AppTheme.spaceMd,
              children: PresetAvatarStyle.values.map((style) {
                return _buildStyleCard(style);
              }).toList(),
            ),
            const SizedBox(height: AppTheme.spaceLg),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStyleCard(PresetAvatarStyle style) {
    final isSelected = _selectedStyle == style;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStyle = style;
          _avatarType = AvatarType.preset;
        });
        Navigator.pop(context);
      },
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.accentLight 
              : AppTheme.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected ? AppTheme.accentPrimary : AppTheme.borderPrimary,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _getStyleIcon(style),
              color: isSelected ? AppTheme.accentPrimary : AppTheme.textSecondary,
            ),
            const SizedBox(height: AppTheme.spaceXs),
            Text(
              style.label,
              style: AppTheme.textCaption.copyWith(
                color: isSelected ? AppTheme.accentPrimary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getStyleIcon(PresetAvatarStyle style) {
    return switch (style) {
      PresetAvatarStyle.modern => Icons.face,
      PresetAvatarStyle.classic => Icons.person,
      PresetAvatarStyle.pixel => Icons.grid_on,
      PresetAvatarStyle.minimal => Icons.circle,
      PresetAvatarStyle.vibrant => Icons.palette,
    };
  }
  
  Widget _buildNicknameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '昵称',
          style: AppTheme.textLabel.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spaceXs),
        TextFormField(
          controller: _nicknameController,
          decoration: InputDecoration(
            hintText: '输入你的昵称（如：建筑师小王）',
            prefixIcon: const Icon(Icons.person_outline),
            filled: true,
            fillColor: AppTheme.backgroundSecondary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.accentPrimary),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入昵称';
            }
            if (value.trim().length < 2) {
              return '昵称至少需要2个字符';
            }
            if (value.trim().length > 20) {
              return '昵称不能超过20个字符';
            }
            return null;
          },
          onChanged: (_) => setState(() {}), // 刷新头像预览
        ),
      ],
    );
  }
  
  Widget _buildStatusField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '状态消息（可选）',
          style: AppTheme.textLabel.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spaceXs),
        TextFormField(
          controller: _statusController,
          decoration: InputDecoration(
            hintText: '一句话介绍自己...',
            prefixIcon: const Icon(Icons.edit_note),
            filled: true,
            fillColor: AppTheme.backgroundSecondary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.accentPrimary),
            ),
          ),
          maxLength: 50,
        ),
      ],
    );
  }
  
  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '个性颜色',
          style: AppTheme.textLabel.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        Wrap(
          spacing: AppTheme.spaceMd,
          runSpacing: AppTheme.spaceMd,
          children: AvatarGenerator.availableColors.map((color) {
            final isSelected = _selectedColor == color;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(color),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppTheme.textPrimary : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: Color(color).withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ] : null,
                ),
                child: isSelected 
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (widget.mode == UserSetupMode.edit)
          FluentButton(
            onPressed: () => Navigator.pop(context),
            style: FluentButtonStyle.standard,
            child: const Text('取消'),
          ),
        if (widget.mode == UserSetupMode.edit)
          const SizedBox(width: AppTheme.spaceMd),
        FluentButton(
          onPressed: _isLoading ? null : _save,
          style: FluentButtonStyle.accent,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(widget.mode == UserSetupMode.firstTime ? '开始' : '保存'),
        ),
      ],
    );
  }
}
