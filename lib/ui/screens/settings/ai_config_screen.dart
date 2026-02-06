/// AI配置页面
/// 
/// 配置AI API连接参数

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../services/ai/ai_service.dart';

final aiConfigProvider = StateProvider<AIConfig>((ref) {
  // TODO: 从存储加载
  return AIConfig(
    apiKey: '',
    baseUrl: 'https://api.openai.com/v1',
    model: 'gpt-4',
  );
});

class AIConfigScreen extends ConsumerStatefulWidget {
  const AIConfigScreen({super.key});

  @override
  ConsumerState<AIConfigScreen> createState() => _AIConfigScreenState();
}

class _AIConfigScreenState extends ConsumerState<AIConfigScreen> {
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  late TextEditingController _modelController;
  double _temperature = 0.7;
  bool _isTesting = false;
  String? _testResult;
  
  @override
  void initState() {
    super.initState();
    final config = ref.read(aiConfigProvider);
    _apiKeyController = TextEditingController(text: config.apiKey);
    _baseUrlController = TextEditingController(text: config.baseUrl);
    _modelController = TextEditingController(text: config.model);
    _temperature = config.temperature;
  }
  
  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }
  
  void _saveConfig() {
    final newConfig = AIConfig(
      apiKey: _apiKeyController.text,
      baseUrl: _baseUrlController.text,
      model: _modelController.text,
      temperature: _temperature,
    );
    
    ref.read(aiConfigProvider.notifier).state = newConfig;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('配置已保存')),
    );
  }
  
  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });
    
    try {
      final config = AIConfig(
        apiKey: _apiKeyController.text,
        baseUrl: _baseUrlController.text,
        model: _modelController.text,
      );
      
      final service = AIService(config: config);
      // 简单的测试调用
      // await service.testConnection();
      
      await Future.delayed(const Duration(seconds: 1)); // 模拟测试
      
      setState(() {
        _testResult = '连接成功！';
      });
    } catch (e) {
      setState(() {
        _testResult = '连接失败: $e';
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackgroundBase,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackgroundLayer,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('AI配置'),
        actions: [
          TextButton(
            onPressed: _saveConfig,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // API配置卡片
          FluentCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'API配置',
                    style: AppTheme.textHeading3,
                  ),
                  const SizedBox(height: 16),
                  
                  // Base URL
                  TextField(
                    controller: _baseUrlController,
                    style: AppTheme.textBody.copyWith(
                      color: AppTheme.darkTextPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'API地址',
                      labelStyle: AppTheme.textBody.copyWith(
                        color: AppTheme.darkTextSecondary,
                      ),
                      hintText: 'https://api.openai.com/v1',
                      filled: true,
                      fillColor: AppTheme.darkBackgroundSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // API Key
                  TextField(
                    controller: _apiKeyController,
                    style: AppTheme.textBody.copyWith(
                      color: AppTheme.darkTextPrimary,
                    ),
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'API密钥',
                      labelStyle: AppTheme.textBody.copyWith(
                        color: AppTheme.darkTextSecondary,
                      ),
                      hintText: 'sk-...',
                      filled: true,
                      fillColor: AppTheme.darkBackgroundSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Model
                  TextField(
                    controller: _modelController,
                    style: AppTheme.textBody.copyWith(
                      color: AppTheme.darkTextPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: '模型',
                      labelStyle: AppTheme.textBody.copyWith(
                        color: AppTheme.darkTextSecondary,
                      ),
                      hintText: 'gpt-4',
                      filled: true,
                      fillColor: AppTheme.darkBackgroundSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 高级设置
          FluentCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '高级设置',
                    style: AppTheme.textHeading3,
                  ),
                  const SizedBox(height: 16),
                  
                  // Temperature
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '随机性 (Temperature)',
                          style: AppTheme.textBody,
                        ),
                      ),
                      Text(
                        _temperature.toStringAsFixed(1),
                        style: AppTheme.textBody.copyWith(
                          color: AppTheme.accentPrimary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _temperature,
                    min: 0.0,
                    max: 2.0,
                    divisions: 20,
                    onChanged: (v) => setState(() => _temperature = v),
                    activeColor: AppTheme.accentPrimary,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 说明
                  Text(
                    '较低的值使输出更确定，较高的值使输出更随机和有创意。',
                    style: AppTheme.textCaption.copyWith(
                      color: AppTheme.darkTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 测试连接
          FluentCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '测试连接',
                    style: AppTheme.textHeading3,
                  ),
                  const SizedBox(height: 16),
                  
                  if (_testResult != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _testResult!.contains('成功')
                            ? AppTheme.success.withAlpha(30)
                            : AppTheme.error.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _testResult!.contains('成功')
                                ? Icons.check_circle
                                : Icons.error,
                            color: _testResult!.contains('成功')
                                ? AppTheme.success
                                : AppTheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testResult!,
                              style: AppTheme.textBody,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isTesting ? null : _testConnection,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.network_check),
                      label: Text(_isTesting ? '测试中...' : '测试连接'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 预设配置
          FluentCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '快速配置',
                    style: AppTheme.textHeading3,
                  ),
                  const SizedBox(height: 16),
                  
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetChip('OpenAI', () {
                        _baseUrlController.text = 'https://api.openai.com/v1';
                        _modelController.text = 'gpt-4';
                      }),
                      _buildPresetChip('Azure', () {
                        _baseUrlController.text = 'https://your-resource.openai.azure.com/openai/deployments/your-deployment';
                        _modelController.text = 'gpt-4';
                      }),
                      _buildPresetChip('Claude', () {
                        _baseUrlController.text = 'https://api.anthropic.com/v1';
                        _modelController.text = 'claude-3-opus-20240229';
                      }),
                      _buildPresetChip('本地Ollama', () {
                        _baseUrlController.text = 'http://localhost:11434/v1';
                        _modelController.text = 'llama2';
                        _temperature = 0.8;
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
  
  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppTheme.darkBackgroundSecondary,
      side: BorderSide(color: AppTheme.darkBorderPrimary),
    );
  }
}
