import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_service.dart';
import '../../../data/local/user_prefs_service.dart';

const Object _aiChatUnset = Object();

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isStreaming;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isStreaming = false,
  });

  ChatMessage copyWith({String? content, bool? isStreaming}) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      isUser: isUser,
      timestamp: timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class AiChatState {
  final List<ChatMessage> messages;
  final bool isSending;
  final bool isConfirmingPlanSave;
  final String? conversationId;
  final String? latestSavedPlanId;
  final String? latestSavedPlanTitle;
  final Map<String, dynamic>? pendingPlanData;
  final String? pendingPlanTitle;
  final String? pendingPlanCity;
  final int? pendingPlanDays;

  const AiChatState({
    this.messages = const [],
    this.isSending = false,
    this.isConfirmingPlanSave = false,
    this.conversationId,
    this.latestSavedPlanId,
    this.latestSavedPlanTitle,
    this.pendingPlanData,
    this.pendingPlanTitle,
    this.pendingPlanCity,
    this.pendingPlanDays,
  });

  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    bool? isConfirmingPlanSave,
    String? conversationId,
    Object? latestSavedPlanId = _aiChatUnset,
    Object? latestSavedPlanTitle = _aiChatUnset,
    Object? pendingPlanData = _aiChatUnset,
    Object? pendingPlanTitle = _aiChatUnset,
    Object? pendingPlanCity = _aiChatUnset,
    Object? pendingPlanDays = _aiChatUnset,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      isConfirmingPlanSave: isConfirmingPlanSave ?? this.isConfirmingPlanSave,
      conversationId: conversationId ?? this.conversationId,
      latestSavedPlanId: identical(latestSavedPlanId, _aiChatUnset)
          ? this.latestSavedPlanId
          : latestSavedPlanId as String?,
      latestSavedPlanTitle: identical(latestSavedPlanTitle, _aiChatUnset)
          ? this.latestSavedPlanTitle
          : latestSavedPlanTitle as String?,
      pendingPlanData: identical(pendingPlanData, _aiChatUnset)
          ? this.pendingPlanData
          : pendingPlanData as Map<String, dynamic>?,
      pendingPlanTitle: identical(pendingPlanTitle, _aiChatUnset)
          ? this.pendingPlanTitle
          : pendingPlanTitle as String?,
      pendingPlanCity: identical(pendingPlanCity, _aiChatUnset)
          ? this.pendingPlanCity
          : pendingPlanCity as String?,
      pendingPlanDays: identical(pendingPlanDays, _aiChatUnset)
          ? this.pendingPlanDays
          : pendingPlanDays as int?,
    );
  }
}

class AiChatViewModel extends StateNotifier<AiChatState> {
  final Ref ref;
  StreamSubscription<Map<String, dynamic>>? _streamSub;

  AiChatViewModel(this.ref) : super(const AiChatState()) {
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    final prefs = ref.read(userPrefsProvider);
    final persona = prefs.getPersona() ?? '旅行者';
    state = state.copyWith(
      messages: [
        ChatMessage(
          id: 'welcome',
          content: '你好，$persona！我是你的灵感伴游 AI。\n\n你可以问我：\n· 帮我规划一条成都 3 天的路线\n· 这个地方有什么好吃的\n· 适合拍照的小众景点推荐',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isSending) return;

    await _streamSub?.cancel();

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );
    final aiMsgId = '${DateTime.now().millisecondsSinceEpoch}_ai';
    final aiMsg = ChatMessage(
      id: aiMsgId,
      content: '',
      isUser: false,
      timestamp: DateTime.now(),
      isStreaming: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg, aiMsg],
      isSending: true,
      latestSavedPlanId: null,
      latestSavedPlanTitle: null,
      pendingPlanData: null,
      pendingPlanTitle: null,
      pendingPlanCity: null,
      pendingPlanDays: null,
    );

    final prefs = ref.read(userPrefsProvider);
    final stream = ApiService().streamChat(
      message: text.trim(),
      conversationId: state.conversationId,
      mbtiType: prefs.getMBTI(),
    );

    String accumulated = '';

    _streamSub = stream.listen(
      (chunk) {
        final type = chunk['type'] as String? ?? '';
        final content = chunk['content'] as String? ?? '';
        final convId = chunk['conversation_id'] as String?;

        if (type == 'error') {
          if (accumulated.isNotEmpty) {
            _updateAiMessage(aiMsgId, content: accumulated, isStreaming: false);
            _appendAssistantMessage(
              '连接中断了，但已保留刚刚生成的攻略内容。你可以继续追问，或让我重新整理并保存。',
            );
          } else {
            _updateAiMessage(
              aiMsgId,
              content: content.isEmpty ? '服务暂时不可用，请稍后重试' : content,
              isStreaming: false,
            );
          }
          state = state.copyWith(isSending: false);
          return;
        }

        if (type == 'plan_ready') {
          final rawPlanData = chunk['plan_data'];
          final rawDays = chunk['days'];
          if (rawPlanData is Map) {
            state = state.copyWith(
              pendingPlanData: Map<String, dynamic>.from(rawPlanData),
              pendingPlanTitle: chunk['title'] as String? ?? '新行程',
              pendingPlanCity: chunk['city'] as String?,
              pendingPlanDays: rawDays is int ? rawDays : (rawDays is num ? rawDays.toInt() : null),
            );
            _appendAssistantMessage('攻略已经整理好了，确认后就能加入“我的行程”。');
          }
          return;
        }

        if (type == 'plan_saved') {
          final planId = chunk['plan_id'] as String?;
          final title = chunk['title'] as String? ?? '新行程';
          state = state.copyWith(
            latestSavedPlanId: planId,
            latestSavedPlanTitle: title,
            pendingPlanData: null,
            pendingPlanTitle: null,
            pendingPlanCity: null,
            pendingPlanDays: null,
            isConfirmingPlanSave: false,
          );
          _appendAssistantMessage('已将攻略保存到我的行程：$title');
          return;
        }

        if (type == 'complete') {
          _updateAiMessage(aiMsgId, isStreaming: false);
          state = state.copyWith(isSending: false);
          return;
        }

        accumulated += content;
        _updateAiMessage(aiMsgId, content: accumulated, isStreaming: true);
        if (convId != null) {
          state = state.copyWith(conversationId: convId);
        }
      },
      onError: (_) {
        if (accumulated.isNotEmpty) {
          _updateAiMessage(aiMsgId, content: accumulated, isStreaming: false);
          _appendAssistantMessage('连接中断了，但当前攻略内容已经保留。');
        } else {
          _updateAiMessage(aiMsgId, content: '网络连接失败，请稍后重试', isStreaming: false);
        }
        state = state.copyWith(isSending: false);
      },
      onDone: () {
        _updateAiMessage(aiMsgId, isStreaming: false);
        state = state.copyWith(isSending: false);
      },
    );
  }

  Future<void> confirmPendingPlanSave() async {
    final planData = state.pendingPlanData;
    if (planData == null || state.isConfirmingPlanSave) {
      return;
    }

    state = state.copyWith(isConfirmingPlanSave: true);
    final saved = await ApiService().confirmPlanSave(planData: planData);
    if (saved == null) {
      state = state.copyWith(isConfirmingPlanSave: false);
      _appendAssistantMessage('保存失败了，请稍后再试一次。');
      return;
    }

    final title = saved['title'] as String? ?? state.pendingPlanTitle ?? '新行程';
    final planId = saved['plan_id'] as String?;
    state = state.copyWith(
      isConfirmingPlanSave: false,
      latestSavedPlanId: planId,
      latestSavedPlanTitle: title,
      pendingPlanData: null,
      pendingPlanTitle: null,
      pendingPlanCity: null,
      pendingPlanDays: null,
    );
    _appendAssistantMessage('已确认添加到我的行程：$title');
  }

  void dismissPendingPlan() {
    state = state.copyWith(
      pendingPlanData: null,
      pendingPlanTitle: null,
      pendingPlanCity: null,
      pendingPlanDays: null,
      isConfirmingPlanSave: false,
    );
  }

  void _updateAiMessage(String msgId, {String? content, bool? isStreaming}) {
    final updatedMessages = state.messages.map((message) {
      if (message.id == msgId) {
        return message.copyWith(content: content, isStreaming: isStreaming);
      }
      return message;
    }).toList();
    state = state.copyWith(messages: updatedMessages);
  }

  void _appendAssistantMessage(String content) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
          content: content,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  void clearChat() {
    _streamSub?.cancel();
    state = const AiChatState();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}

final aiChatProvider = StateNotifierProvider<AiChatViewModel, AiChatState>((ref) {
  return AiChatViewModel(ref);
});
