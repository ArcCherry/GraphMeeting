import 'dart:async';
import '../models/chrono_vine/vine_node.dart';
import '../ui/widgets/chat/chat_input_bar.dart';

/// 全局事件总线
/// 
/// 连接 Chat UI 和 3D 藤蔓视图
class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  // 消息提交事件（Chat → 3D）
  final _messageController = StreamController<SoliloquyMessage>.broadcast();
  Stream<SoliloquyMessage> get onMessageSubmit => _messageController.stream;

  // 节点选中事件（3D → Chat）
  final _nodeSelectController = StreamController<VineNode>.broadcast();
  Stream<VineNode> get onNodeSelect => _nodeSelectController.stream;

  // 回复事件（3D → Chat 输入栏）
  final _replyController = StreamController<String>.broadcast();
  Stream<String> get onReply => _replyController.stream;

  // 提交消息
  void submitMessage(SoliloquyMessage message) {
    _messageController.add(message);
  }

  // 选中节点
  void selectNode(VineNode node) {
    _nodeSelectController.add(node);
  }

  // 发起回复
  void replyTo(String nodeId) {
    _replyController.add(nodeId);
  }

  void dispose() {
    _messageController.close();
    _nodeSelectController.close();
    _replyController.close();
  }
}
