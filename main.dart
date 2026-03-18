import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:chat_bubbles/chat_bubbles.dart';

void main() {
  runApp(const GeminiChatApp());
}

class GeminiChatApp extends StatelessWidget {
  const GeminiChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini AI Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatMessage {
  final String message;
  final bool isUser;

  ChatMessage({
    required this.message,
    required this.isUser,
  });
}

class ApiService {
  // ✅ YOUR WORKING API KEY
  static const String _apiKey = "AIzaSyChVyyKgaPdprJztOQr79osu8_9CfqfX18";

  // ✅ Based on your response, you have access to these models
  final List<Map<String, String>> _models = [
    {'name': 'gemini-2.5-flash', 'version': 'v1', 'display': 'Gemini 2.5 Flash (Fastest)'},
    {'name': 'gemini-1.5-flash', 'version': 'v1', 'display': 'Gemini 1.5 Flash'},
    {'name': 'gemini-1.5-pro', 'version': 'v1', 'display': 'Gemini 1.5 Pro'},
    {'name': 'gemini-pro', 'version': 'v1', 'display': 'Gemini Pro'},
  ];

  Future<String> getChatResponse(String userMessage) async {
    List<String> errors = [];

    // Try each model
    for (var model in _models) {
      try {
        print('🔄 Trying: ${model['display']}');

        final response = await http.post(
          Uri.parse("https://generativelanguage.googleapis.com/${model['version']}/models/${model['name']}:generateContent?key=$_apiKey"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "contents": [
              {
                "parts": [
                  {"text": userMessage}
                ]
              }
            ],
            "generationConfig": {
              "temperature": 0.7,
              "maxOutputTokens": 1024,
              "topP": 0.95,
            }
          }),
        ).timeout(const Duration(seconds: 30));

        final data = jsonDecode(response.body);

        if (response.statusCode == 200) {
          if (data.containsKey('candidates') &&
              data['candidates'].isNotEmpty &&
              data['candidates'][0].containsKey('content') &&
              data['candidates'][0]['content'].containsKey('parts') &&
              data['candidates'][0]['content']['parts'].isNotEmpty) {

            String reply = data['candidates'][0]['content']['parts'][0]['text'];
            print('✅ Success with: ${model['display']}');
            return reply;
          }
        } else {
          String errorMsg = data['error']?['message'] ?? 'Unknown error';
          errors.add("❌ ${model['name']}: $errorMsg");
        }
      } catch (e) {
        errors.add("❌ ${model['name']}: ${e.toString()}");
      }
    }

    throw "All models failed. Last errors:\n${errors.join('\n')}";
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      message: "👋 Hi Shoaib !\n How can I help you today?",
      isUser: false,
    ));
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(message: text, isUser: true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final reply = await _apiService.getChatResponse(text);
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(message: reply, isUser: false));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
        title: const Text('Gemini AI Chat', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                  child: BubbleSpecialThree(
                    text: msg.message,
                    color: msg.isUser ? const Color(0xFFE8E8EE) : const Color(0xFF673AB7),
                    tail: true,
                    textStyle: TextStyle(
                      color: msg.isUser ? Colors.black : Colors.white,
                      fontSize: 16,
                    ),
                    isSender: msg.isUser,
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SpinKitThreeBounce(color: Colors.deepPurple, size: 20),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.deepPurple,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}