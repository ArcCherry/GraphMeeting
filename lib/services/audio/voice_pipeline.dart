import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'native_recorder.dart';

/// 转写结果
class TranscriptionResult {
  final String text;
  final double confidence;
  final Duration duration;
  final List<double>? waveform;
  final String? language;

  TranscriptionResult({
    required this.text,
    required this.confidence,
    required this.duration,
    this.waveform,
    this.language,
  });
}

/// 音频录制状态
enum RecordingState { idle, recording, processing, done, error }

/// 语音录制服务
/// 
/// 使用原生平台通道实现真正的音频录制
class VoiceRecordingService extends ChangeNotifier {
  final NativeAudioRecorder _recorder = NativeAudioRecorder();

  RecordingState _state = RecordingState.idle;
  Duration _duration = Duration.zero;
  List<double> _waveform = [];
  String? _currentRecordingPath;
  Timer? _durationTimer;
  Timer? _waveformTimer;

  // Getters
  RecordingState get state => _state;
  Duration get duration => _duration;
  List<double> get waveform => List.unmodifiable(_waveform);
  String? get currentRecordingPath => _currentRecordingPath;
  bool get isRecording => _state == RecordingState.recording;

  /// 检查并请求权限
  Future<bool> checkPermission() async {
    return await _recorder.requestPermission();
  }

  /// 开始录音
  Future<void> startRecording() async {
    if (_state == RecordingState.recording) return;

    // 检查权限
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      _state = RecordingState.error;
      notifyListeners();
      throw Exception('Microphone permission denied');
    }

    // 开始原生录制
    final path = await _recorder.startRecording();
    if (path == null) {
      _state = RecordingState.error;
      notifyListeners();
      throw Exception('Failed to start recording');
    }

    _currentRecordingPath = path;
    _state = RecordingState.recording;
    _duration = Duration.zero;
    _waveform = [];
    notifyListeners();

    // 启动时长计时器
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final time = await _recorder.getCurrentTime();
      _duration = Duration(seconds: time.round());
      notifyListeners();
    });

    // 启动波形采样计时器
    _waveformTimer?.cancel();
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final level = await _recorder.getAudioLevel();
      _waveform.add(level);
      if (_waveform.length > 100) {
        _waveform.removeAt(0);
      }
      notifyListeners();
    });
  }

  /// 停止录音并进行转写
  Future<TranscriptionResult?> stopRecording() async {
    if (_state != RecordingState.recording) return null;

    // 停止计时器
    _durationTimer?.cancel();
    _waveformTimer?.cancel();
    _durationTimer = null;
    _waveformTimer = null;

    _state = RecordingState.processing;
    notifyListeners();

    // 停止原生录制
    final path = await _recorder.stopRecording();
    if (path == null) {
      _state = RecordingState.error;
      notifyListeners();
      return null;
    }

    // 执行转写（模拟）
    final result = await _transcribe(File(path));

    _state = RecordingState.done;
    notifyListeners();

    return result;
  }

  /// 转写音频文件（模拟实现）
  Future<TranscriptionResult> _transcribe(File audioFile) async {
    // TODO: 集成真正的语音识别 API
    // 目前返回模拟文本用于演示
    
    final mockTexts = [
      "我们需要讨论一下这个方案的具体实现",
      "我同意这个决定，可以开始执行",
      "但是这里有个风险需要注意，可能会延期",
      "我们应该在下周完成开发工作",
      "TODO: 需要补充详细的设计文档",
    ];

    final text = mockTexts[DateTime.now().second % mockTexts.length];

    return TranscriptionResult(
      text: text,
      confidence: 0.85 + (DateTime.now().millisecond / 1000) * 0.1,
      duration: _duration,
      waveform: List.from(_waveform),
    );
  }

  /// 取消录音
  Future<void> cancelRecording() async {
    _durationTimer?.cancel();
    _waveformTimer?.cancel();
    _durationTimer = null;
    _waveformTimer = null;

    await _recorder.stopRecording();

    if (_currentRecordingPath != null) {
      await _recorder.deleteRecording(_currentRecordingPath!);
    }

    _state = RecordingState.idle;
    _duration = Duration.zero;
    _waveform = [];
    _currentRecordingPath = null;
    notifyListeners();
  }

  /// 获取录音文件
  Future<File?> getRecordingFile() async {
    if (_currentRecordingPath == null) return null;
    return _recorder.getRecordingFile(_currentRecordingPath!);
  }

  /// 清理
  void clear() {
    _durationTimer?.cancel();
    _waveformTimer?.cancel();

    if (_currentRecordingPath != null) {
      _recorder.deleteRecording(_currentRecordingPath!);
    }

    _state = RecordingState.idle;
    _duration = Duration.zero;
    _waveform = [];
    _currentRecordingPath = null;
    notifyListeners();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}

/// 语音分析结果
class VoiceAnalysisResult {
  final TranscriptionResult transcription;
  final int nodeType; // 0=Message, 1=Milestone, 2=Branch, 3=Merge, 4=AiSummary
  final int sentiment; // -1=Negative, 0=Neutral, 1=Positive
  final double confidence;
  final List<String> keyPoints;
  final List<String> actions;

  VoiceAnalysisResult({
    required this.transcription,
    required this.nodeType,
    required this.sentiment,
    required this.confidence,
    required this.keyPoints,
    required this.actions,
  });

  bool get isMilestone => nodeType == 1;
  bool get isPositive => sentiment == 1;
  bool get hasActions => actions.isNotEmpty;
}

/// AI 分析服务（纯 Dart 实现）
class AIService {
  /// 分析节点内容类型
  /// 返回: 0=Message, 1=Milestone, 2=Branch, 3=Merge, 4=AiSummary
  static int analyzeContentType(String content) {
    final lower = content.toLowerCase();
    
    final decisionKeywords = ['决定', '确定', '同意', '通过', 'decide', 'agree', '结论'];
    if (decisionKeywords.any((kw) => lower.contains(kw))) {
      return 1; // Milestone
    }
    
    return 0; // Message
  }

  /// 分析情感倾向
  /// 返回: -1=Negative, 0=Neutral, 1=Positive
  static int analyzeSentiment(String content) {
    final lower = content.toLowerCase();
    
    final negativeKeywords = ['但是', '不同意', '反对', '问题', '风险', 'but', 'disagree', 'risk'];
    if (negativeKeywords.any((kw) => lower.contains(kw))) {
      return -1;
    }
    
    final positiveKeywords = ['同意', '通过', '好', 'agree', 'good', 'great'];
    if (positiveKeywords.any((kw) => lower.contains(kw))) {
      return 1;
    }
    
    return 0;
  }

  /// 提取关键要点
  static List<String> extractKeyPoints(String content) {
    return content
        .split(RegExp(r'[。\.\!]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 5)
        .take(3)
        .toList();
  }

  /// 提取行动项
  static List<String> extractActions(String content) {
    final actions = <String>[];
    
    for (final sentence in content.split('。')) {
      final s = sentence.trim();
      if (s.contains('需要') || s.contains('应该') || s.contains('TODO') || s.contains('todo')) {
        actions.add(s);
      }
    }
    
    return actions;
  }

  /// 检测共识
  /// 返回: 0=No, 1=Partial, 2=Strong
  static int detectConsensus(List<String> contents) {
    if (contents.length < 2) return 0;
    
    final agreementCount = contents.where((c) {
      final lower = c.toLowerCase();
      return lower.contains('同意') || lower.contains('agree') || lower.contains('+1');
    }).length;
    
    final ratio = agreementCount / contents.length;
    
    if (ratio > 0.7) return 2;
    if (ratio > 0.4) return 1;
    return 0;
  }

  /// 完整分析
  static VoiceAnalysisResult analyze(TranscriptionResult transcription) {
    final content = transcription.text;
    
    return VoiceAnalysisResult(
      transcription: transcription,
      nodeType: analyzeContentType(content),
      sentiment: analyzeSentiment(content),
      confidence: transcription.confidence,
      keyPoints: extractKeyPoints(content),
      actions: extractActions(content),
    );
  }
}

/// 语音处理管道
class VoicePipeline {
  final VoiceRecordingService _recordingService = VoiceRecordingService();

  VoiceRecordingService get recordingService => _recordingService;

  /// 开始录音
  Future<void> start() => _recordingService.startRecording();

  /// 停止录音并获取分析结果
  Future<VoiceAnalysisResult?> stop() async {
    final transcription = await _recordingService.stopRecording();
    if (transcription == null) return null;

    // 使用本地 AI 分析
    return AIService.analyze(transcription);
  }

  void dispose() {
    _recordingService.dispose();
  }
}
