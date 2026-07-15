import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:enquiry_app/utils/api_debug_logger.dart';

class ChatScreen extends StatefulWidget {
  final String module; // "product", "enquiry", "bulk_order"
  final int referenceId;
  final String userName;
  final String? initialMessage;

  const ChatScreen({
    super.key,
    required this.module,
    required this.referenceId,
    required this.userName,
    this.initialMessage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null) {
      _messageController.text = widget.initialMessage!;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    }
    _fetchMessages();
  }

  List<dynamic> _extractList(dynamic json) {
    if (json is List) return json;
    if (json is Map) {
      if (json.containsKey('data')) {
        final d = json['data'];
        if (d is List) return d;
        if (d is Map) {
          if (d.containsKey('data')) {
            final dd = d['data'];
            if (dd is List) return dd;
          }
          if (d.containsKey('messages')) {
            final dm = d['messages'];
            if (dm is List) return dm;
          }
        }
      }
      if (json.containsKey('messages')) {
        final m = json['messages'];
        if (m is List) return m;
      }
      // Fallback: search values for the first list
      for (var val in json.values) {
        if (val is List) {
          return val;
        }
        if (val is Map) {
          final sub = _extractList(val);
          if (sub.isNotEmpty) return sub;
        }
      }
    }
    return [];
  }

  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
    });

    final url = "https://bulk.srivagroups.in/api/messages/${widget.module}/${widget.referenceId}";
    try {
      final res = await ApiDebugLogger.httpClient.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final loadedMessages = _extractList(decoded);

        setState(() {
          _messages = loadedMessages;
        });
        _scrollToBottom();
      }
    } catch (e) {
      // Quietly handle or show debug log
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    final url = "https://bulk.srivagroups.in/api/messages";
    final body = {
      "module": widget.module,
      "reference_id": widget.referenceId,
      "sender": "admin",
      "message": text,
    };

    try {
      final res = await ApiDebugLogger.httpClient.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        _messageController.clear();
        await _fetchMessages();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to send message: ${res.statusCode}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error sending message. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.userName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "${widget.module.toUpperCase()} #${widget.referenceId}",
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF3B5BDB),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMessages,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
        ),
        child: Column(
          children: [
            Expanded(
              child: _isLoading && _messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                "No messages yet",
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Type below and send a reply.",
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = msg["sender"] == "admin";
                            return _buildMessageBubble(msg["message"] ?? "", isMe, msg["created_at"]);
                          },
                        ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _parseMessage(String rawMessage) {
    final regExp = RegExp(r'\n\n\[via:(.*?)\]$');
    final match = regExp.firstMatch(rawMessage);
    if (match != null) {
      final channelsStr = match.group(1) ?? "";
      final channels = channelsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final cleanMessage = rawMessage.substring(0, match.start);
      return {
        "message": cleanMessage,
        "channels": channels,
      };
    }
    return {
      "message": rawMessage,
      "channels": <String>[],
    };
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "";
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      int hour = dt.hour;
      final String period = hour >= 12 ? "PM" : "AM";
      hour = hour % 12;
      if (hour == 0) hour = 12;
      final String hourStr = hour.toString().padLeft(2, '0');
      final String minuteStr = dt.minute.toString().padLeft(2, '0');
      return "$hourStr:$minuteStr $period";
    } catch (_) {
      return "";
    }
  }

  Widget _buildMessageBubble(String rawText, bool isMe, String? timeStr) {
    final parsed = _parseMessage(rawText);
    final String text = parsed["message"];
    final List<dynamic> channels = parsed["channels"];

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF3B5BDB) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF0F172A),
                fontSize: 15,
                height: 1.35,
              ),
            ),
            if (isMe && channels.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: channels.map<Widget>((channel) {
                  IconData icon;
                  Color bgColor;
                  Color textColor;
                  final c = channel.toString().toLowerCase();
                  if (c == 'whatsapp') {
                    icon = Icons.chat_bubble_rounded;
                    bgColor = Colors.white.withOpacity(0.2);
                    textColor = Colors.white;
                  } else if (c == 'email') {
                    icon = Icons.email_rounded;
                    bgColor = Colors.white.withOpacity(0.2);
                    textColor = Colors.white;
                  } else if (c == 'sms') {
                    icon = Icons.sms_rounded;
                    bgColor = Colors.white.withOpacity(0.2);
                    textColor = Colors.white;
                  } else {
                    icon = Icons.send_rounded;
                    bgColor = Colors.white.withOpacity(0.2);
                    textColor = Colors.white;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 10, color: textColor),
                        const SizedBox(width: 4),
                        Text(
                          channel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMe && channels.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Text(
                        "App Chat",
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  Text(
                    _formatTime(timeStr),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF3B5BDB),
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
