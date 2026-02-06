import 'package:flutter/material.dart';

import '../../../models/auth/role_permissions.dart';
import 'chat_input_bar.dart';

/// 消息气泡（仅显示自己的消息历史）
class MessageBubble extends StatelessWidget {
  final SoliloquyMessage message;
  final PlayerIdentity? currentUser;
  final bool isMe;
  final Function()? onTap;
  final Function()? onLongPress;
  final Function()? onReply;

  const MessageBubble({
    super.key,
    required this.message,
    this.currentUser,
    this.isMe = true,
    this.onTap,
    this.onLongPress,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // 引用指示
              if (message.replyTo != null)
                _buildReplyPreview(),
              
              // 消息内容
              _buildMessageContent(),
              
              // 时间和状态
              _buildMessageMeta(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.reply,
            size: 12,
            color: Colors.blue.withOpacity(0.8),
          ),
          const SizedBox(width: 4),
          Text(
            '引用: ${message.replyTo!.substring(0, message.replyTo!.length > 15 ? 15 : message.replyTo!.length)}...',
            style: TextStyle(
              color: Colors.blue.withOpacity(0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    switch (message.type) {
      case MessageType.voice:
        return _buildVoiceMessage();
      case MessageType.image:
        return _buildImageMessage();
      case MessageType.file:
        return _buildFileMessage();
      case MessageType.text:
      default:
        return _buildTextMessage();
    }
  }

  Widget _buildTextMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isMe 
          ? Colors.blue.withOpacity(0.8) 
          : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message.content,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildVoiceMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMe 
          ? Colors.blue.withOpacity(0.8) 
          : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.play_circle_fill,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 8),
          // 简化波形
          SizedBox(
            width: 60,
            height: 24,
            child: CustomPaint(
              painter: SimpleWaveformPainter(
                waveform: message.waveform ?? [],
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${message.voiceDuration?.inSeconds ?? 0}"',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage() {
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // 实际应显示图片
            Center(
              child: Icon(
                Icons.image,
                size: 48,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            // 附件数量指示
            if (message.attachments != null && message.attachments!.length > 1)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '+${message.attachments!.length - 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe 
          ? Colors.blue.withOpacity(0.8) 
          : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.insert_drive_file,
            color: Colors.white70,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '文件附件',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${message.attachments?.length ?? 0} 个文件',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageMeta() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(message.timestamp),
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 4),
            // 发送状态指示
            Icon(
              Icons.check_circle,
              size: 10,
              color: Colors.white.withOpacity(0.4),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// 简单波形绘制器
class SimpleWaveformPainter extends CustomPainter {
  final List<double> waveform;
  final Color color;

  SimpleWaveformPainter({
    required this.waveform,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) {
      // 绘制默认波形
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      
      final barWidth = size.width / 20;
      final centerY = size.height / 2;
      
      for (var i = 0; i < 20; i++) {
        final height = (i % 3 + 1) * 4.0;
        final x = i * barWidth + barWidth / 2;
        canvas.drawLine(
          Offset(x, centerY - height),
          Offset(x, centerY + height),
          paint,
        );
      }
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final height = size.height;
    final centerY = height / 2;
    final step = waveform.length > 20 ? waveform.length ~/ 20 : 1;

    for (var i = 0; i < waveform.length; i += step) {
      final amplitude = waveform[i] * height * 0.8;
      final x = (i / waveform.length) * width;
      
      canvas.drawLine(
        Offset(x, centerY - amplitude / 2),
        Offset(x, centerY + amplitude / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
