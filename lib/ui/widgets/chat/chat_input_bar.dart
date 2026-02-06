import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../models/world_settings.dart';
import '../../../services/audio/voice_pipeline.dart';
import '../../../services/network/connection_manager.dart';

/// 独白消息模型
class SoliloquyMessage {
  final String id;
  final String content;
  final String authorId;
  final DateTime timestamp;
  final MessageType type;
  final String? replyTo;  // 引用的节点ID
  final List<File>? attachments;
  final File? voiceFile;
  final Duration? voiceDuration;
  final List<double>? waveform;

  SoliloquyMessage({
    required this.id,
    required this.content,
    required this.authorId,
    required this.timestamp,
    this.type = MessageType.text,
    this.replyTo,
    this.attachments,
    this.voiceFile,
    this.voiceDuration,
    this.waveform,
  });
}

enum MessageType {
  text,
  voice,
  image,
  file,
}

/// 独白输入栏
/// 
/// 用户通过此组件提交独白内容
class SoliloquyInputBar extends StatefulWidget {
  final String currentUserId;
  final WorldSettings settings;
  final Function(SoliloquyMessage) onSubmit;
  final Function(String)? onReplyTo;  // 引用某节点
  final VoidCallback? onShowFullHistory;

  const SoliloquyInputBar({
    super.key,
    required this.currentUserId,
    required this.settings,
    required this.onSubmit,
    this.onReplyTo,
    this.onShowFullHistory,
  });

  @override
  State<SoliloquyInputBar> createState() => _SoliloquyInputBarState();
}

class _SoliloquyInputBarState extends State<SoliloquyInputBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  // 状态
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  List<double> _waveform = [];
  Timer? _recordingTimer;
  
  String? _replyingTo;  // 正在回复的节点ID
  final List<File> _attachments = [];

  // 语音服务
  final VoiceRecordingService _voiceService = VoiceRecordingService();

  @override
  void initState() {
    super.initState();
    _voiceService.addListener(_onVoiceStateChanged);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _recordingTimer?.cancel();
    _voiceService.removeListener(_onVoiceStateChanged);
    _voiceService.dispose();
    super.dispose();
  }

  void _onVoiceStateChanged() {
    setState(() {
      _recordingDuration = _voiceService.duration;
      _waveform = _voiceService.waveform;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 引用指示器
            if (_replyingTo != null)
              _buildReplyIndicator(),
            
            // 附件预览
            if (_attachments.isNotEmpty)
              _buildAttachmentPreview(),
            
            // 录制中显示波形
            if (_isRecording)
              _buildRecordingWaveform(),
            
            // 输入区域
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 更多按钮（附件等）
                  _buildAttachmentButton(),
                  
                  const SizedBox(width: 8),
                  
                  // 语音按钮（长按录制）
                  if (widget.settings.allowVoiceMessage)
                    _buildVoiceButton(),
                  
                  const SizedBox(width: 8),
                  
                  // 文字输入
                  Expanded(
                    child: _buildTextField(),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // 发送按钮
                  _buildSendButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: 16,
            color: Colors.blue.withOpacity(0.8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '引用节点: ${_replyingTo!.substring(0, _replyingTo!.length > 20 ? 20 : _replyingTo!.length)}...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 16,
              color: Colors.white.withOpacity(0.5),
            ),
            onPressed: () => setState(() => _replyingTo = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _attachments.length,
        itemBuilder: (context, index) {
          final file = _attachments[index];
          return Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    _getFileIcon(file),
                    color: Colors.white.withOpacity(0.7),
                    size: 24,
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => setState(() => _attachments.removeAt(index)),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecordingWaveform() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.mic,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 40),
              painter: WaveformPainter(
                waveform: _waveform,
                color: Colors.red,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_recordingDuration.inSeconds}.${(_recordingDuration.inMilliseconds % 1000) ~/ 100}"',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentButton() {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.add_circle,
        color: Colors.white.withOpacity(0.7),
      ),
      color: Colors.grey[900],
      onSelected: (value) {
        switch (value) {
          case 'image':
            _pickImage();
            break;
          case 'file':
            _pickFile();
            break;
          case 'history':
            widget.onShowFullHistory?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        if (widget.settings.allowImageUpload)
          PopupMenuItem(
            value: 'image',
            child: Row(
              children: [
                const Icon(Icons.image, color: Colors.white70, size: 20),
                const SizedBox(width: 12),
                Text(
                  '图片',
                  style: TextStyle(color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        if (widget.settings.allowFileUpload)
          PopupMenuItem(
            value: 'file',
            child: Row(
              children: [
                const Icon(Icons.attach_file, color: Colors.white70, size: 20),
                const SizedBox(width: 12),
                Text(
                  '文件',
                  style: TextStyle(color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'history',
          child: Row(
            children: [
              const Icon(Icons.history, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              Text(
                '历史记录',
                style: TextStyle(color: Colors.white.withOpacity(0.9)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceButton() {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _isRecording ? Colors.red : Colors.blue,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _isRecording ? Icons.mic : Icons.mic_none,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 44,
        maxHeight: 120,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: _isRecording 
            ? '正在录音... 松开发送'
            : '说出你的想法（${_getTranscriptionModeLabel()}）...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: InputBorder.none,
        ),
        maxLines: null,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _submit(),
      ),
    );
  }

  Widget _buildSendButton() {
    final canSend = _textController.text.isNotEmpty || 
                    _attachments.isNotEmpty ||
                    _isRecording;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: IconButton(
        icon: Icon(
          Icons.send,
          color: canSend ? Colors.blue : Colors.white.withOpacity(0.3),
        ),
        onPressed: canSend ? _submit : null,
      ),
    );
  }

  String _getTranscriptionModeLabel() {
    switch (widget.settings.transcriptionMode) {
      case TranscriptionMode.localWhisper:
        return '本地处理';
      case TranscriptionMode.cloudApi:
        return '云端处理';
      case TranscriptionMode.hybrid:
        return '混合处理';
    }
  }

  IconData _getFileIcon(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  // 开始录音
  Future<void> _startRecording() async {
    setState(() => _isRecording = true);
    await _voiceService.startRecording();
    
    // 模拟波形数据（实际应从录音服务获取）
    _recordingTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) {
        if (_isRecording) {
          setState(() {
            _recordingDuration = Duration(
              milliseconds: _recordingDuration.inMilliseconds + 100,
            );
          });
        }
      },
    );
  }

  // 停止录音
  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    final result = await _voiceService.stopRecording();
    setState(() => _isRecording = false);
    
    if (result != null) {
      _submit(message: result.text);
    }
  }

  // 选择图片
  Future<void> _pickImage() async {
    // 实际实现需要调用文件选择器
    // 这里仅作示例
  }

  // 选择文件
  Future<void> _pickFile() async {
    // 实际实现需要调用文件选择器
    // 这里仅作示例
  }

  // 提交消息
  void _submit({File? voiceFile, String? message}) {
    final content = message ?? _textController.text;
    
    if (content.isEmpty && 
        _attachments.isEmpty && 
        voiceFile == null) {
      return;
    }

    final msg = SoliloquyMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_${widget.currentUserId}',
      content: content,
      authorId: widget.currentUserId,
      timestamp: DateTime.now(),
      type: voiceFile != null ? MessageType.voice : 
            _attachments.isNotEmpty ? MessageType.file : 
            MessageType.text,
      replyTo: _replyingTo,
      attachments: _attachments.isNotEmpty ? List.from(_attachments) : null,
      voiceFile: voiceFile,
      voiceDuration: voiceFile != null ? _recordingDuration : null,
      waveform: voiceFile != null ? List.from(_waveform) : null,
    );

    widget.onSubmit(msg);

    // 清空输入
    _textController.clear();
    setState(() {
      _attachments.clear();
      _replyingTo = null;
      _waveform = [];
      _recordingDuration = Duration.zero;
    });
    
    _focusNode.unfocus();
  }
}

/// 波形绘制器
class WaveformPainter extends CustomPainter {
  final List<double> waveform;
  final Color color;

  WaveformPainter({
    required this.waveform,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final height = size.height;
    final centerY = height / 2;
    final barWidth = width / waveform.length;

    for (var i = 0; i < waveform.length; i++) {
      final amplitude = waveform[i] * height * 0.8;
      final x = i * barWidth + barWidth / 2;
      
      canvas.drawLine(
        Offset(x, centerY - amplitude / 2),
        Offset(x, centerY + amplitude / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
