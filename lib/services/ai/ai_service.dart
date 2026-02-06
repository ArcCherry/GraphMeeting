/// AI服务
/// 
/// 提供：
/// - 消息内容分析
/// - 节点总结生成
/// - 争议检测
/// - 行动项提取

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/chrono_vine/chrono_vine_data.dart';

/// AI配置
class AIConfig {
  final String apiKey;
  final String baseUrl;
  final String model;
  final double temperature;
  final int maxTokens;
  
  AIConfig({
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-4',
    this.temperature = 0.7,
    this.maxTokens = 2000,
  });
  
  factory AIConfig.fromJson(Map<String, dynamic> json) => AIConfig(
    apiKey: json['apiKey'] as String,
    baseUrl: json['baseUrl'] as String? ?? 'https://api.openai.com/v1',
    model: json['model'] as String? ?? 'gpt-4',
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
    maxTokens: (json['maxTokens'] as num?)?.toInt() ?? 2000,
  );
  
  Map<String, dynamic> toJson() => {
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'temperature': temperature,
    'maxTokens': maxTokens,
  };
}

/// AI服务
class AIService {
  AIConfig config;
  
  AIService({required this.config});
  
  void updateConfig(AIConfig newConfig) => config = newConfig;
  
  /// 分析节点内容并生成AI叶子
  Future<List<AILeaf>> analyzeNode(VineNode node) async {
    try {
      final prompt = _buildAnalysisPrompt(node);
      final response = await _callLLM(prompt);
      return _parseAnalysisResponse(response, node);
    } catch (e) {
      debugPrint('AI分析失败: $e');
      return [_generateDefaultLeaf(node)];
    }
  }
  
  /// 检测争议
  Future<ContentionDetectionResult?> detectContention(List<VineNode> nodes) async {
    if (nodes.length < 2) return null;
    try {
      final prompt = _buildContentionPrompt(nodes);
      final response = await _callLLM(prompt);
      return _parseContentionResponse(response, nodes);
    } catch (e) {
      debugPrint('争议检测失败: $e');
      return null;
    }
  }
  
  /// 调用LLM API
  Future<String> _callLLM(String prompt) async {
    final url = Uri.parse('${config.baseUrl}/chat/completions');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      },
      body: jsonEncode({
        'model': config.model,
        'messages': [
          {'role': 'system', 'content': '你是一个专业的会议助手，擅长分析讨论内容并提取关键信息。'},
          {'role': 'user', 'content': prompt},
        ],
        'temperature': config.temperature,
        'max_tokens': config.maxTokens,
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception('API调用失败: ${response.statusCode}');
    }
    
    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }
  
  String _buildAnalysisPrompt(VineNode node) => '''
分析以下会议内容，生成结构化摘要：

${node.content}

识别：1.类型(decision/idea/question/action) 2.一句话总结 3.关键要点 4.行动项 5.风险

以JSON格式输出：
{
  "type": "类型",
  "summary": "一句话总结",
  "keyPoints": ["要点"],
  "actionItems": [{"task": "", "assignee": "", "deadline": ""}],
  "risks": ["风险"]
}
''';
  
  String _buildContentionPrompt(List<VineNode> nodes) {
    final contents = nodes.map((n) => '[${n.authorId}]: ${n.content}').join('\n\n');
    return '''
分析以下讨论，检测观点分歧：

$contents

以JSON输出：
{
  "hasContention": true/false,
  "severity": "low/medium/high",
  "viewpoints": [{"participant": "", "stance": ""}],
  "focus": "争议焦点",
  "suggestedResolution": "建议方案"
}
''';
  }
  
  List<AILeaf> _parseAnalysisResponse(String response, VineNode parent) {
    try {
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch == null) return [_generateDefaultLeaf(parent)];
      
      final data = jsonDecode(jsonMatch.group(0)!);
      final leaves = <AILeaf>[];
      
      // 总结叶子
      if (data['summary'] != null) {
        leaves.add(AILeaf.generate(
          parentNode: parent,
          type: _mapType(data['type'] as String? ?? 'other'),
          title: '摘要',
          content: data['summary'] as String,
        ));
      }
      
      // 行动项叶子
      final actions = data['actionItems'] as List<dynamic>?;
      if (actions != null && actions.isNotEmpty) {
        leaves.add(AILeaf.generate(
          parentNode: parent,
          type: AILeafType.actionItems,
          title: '行动项',
          content: '${actions.length}个待办',
          todos: actions.map((a) => TodoItem(
            id: 'todo_${math.Random().nextInt(10000)}',
            description: a['task'] as String? ?? '',
            assigneeId: a['assignee'] as String?,
          )).toList(),
        ));
      }
      
      return leaves;
    } catch (e) {
      return [_generateDefaultLeaf(parent)];
    }
  }
  
  ContentionDetectionResult? _parseContentionResponse(String response, List<VineNode> nodes) {
    try {
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch == null) return null;
      
      final data = jsonDecode(jsonMatch.group(0)!);
      if (data['hasContention'] != true) return null;
      
      return ContentionDetectionResult(
        severity: data['severity'] as String? ?? 'medium',
        focus: data['focus'] as String? ?? '',
        suggestedResolution: data['suggestedResolution'] as String?,
      );
    } catch (e) {
      return null;
    }
  }
  
  AILeaf _generateDefaultLeaf(VineNode parent) => AILeaf.generate(
    parentNode: parent,
    type: AILeafType.summary,
    title: '摘要',
    content: parent.contentPreview,
  );
  
  AILeafType _mapType(String type) => switch (type) {
    'decision' => AILeafType.decision,
    'action' => AILeafType.actionItems,
    'question' => AILeafType.insight,
    _ => AILeafType.summary,
  };
}

class ContentionDetectionResult {
  final String severity;
  final String focus;
  final String? suggestedResolution;
  ContentionDetectionResult({required this.severity, required this.focus, this.suggestedResolution});
}
