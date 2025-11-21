import 'package:flutter/material.dart';
import '../theme_provider.dart';
import '../theme_provider.dart' show darkTheme;

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
        );
    _slideController.forward();

    // Welcome message
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _messages.add({
            "sender": "bot",
            "message":
                "👋 Hello! I'm your smart home assistant. How can I help you today?",
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    final userMessage = _controller.text.trim();
    setState(() {
      _messages.add({"sender": "user", "message": userMessage});
      _isTyping = true;
    });

    _controller.clear();
    _scrollToBottom();

    // Simulate bot response
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _messages.add({
            "sender": "bot",
            "message": _generateBotResponse(userMessage),
          });
          _isTyping = false;
        });
        _scrollToBottom();
      }
    });
  }

  String _generateBotResponse(String userMessage) {
    final msg = userMessage.toLowerCase();

    // Device control responses
    if (msg.contains('turn on') || msg.contains('switch on')) {
      return "✅ I'll turn that on for you. The device should be active now.";
    } else if (msg.contains('turn off') || msg.contains('switch off')) {
      return "✅ Device turned off successfully.";
    } else if (msg.contains('status') || msg.contains('check')) {
      return "📊 Here's the current status of your devices. All systems are running normally.";
    } else if (msg.contains('energy') ||
        msg.contains('power') ||
        msg.contains('usage')) {
      return "⚡ Your current energy consumption is optimal. I can provide detailed analytics if needed.";
    } else if (msg.contains('schedule')) {
      return "📅 I can help you set up schedules for your devices. What would you like to schedule?";
    } else if (msg.contains('help')) {
      return "💡 I can help you with:\n• Controlling devices\n• Checking energy usage\n• Setting schedules\n• Device status updates\n\nJust ask me anything!";
    } else if (msg.contains('hello') || msg.contains('hi')) {
      return "👋 Hello! How can I assist you with your smart home today?";
    } else if (msg.contains('thank')) {
      return "😊 You're welcome! Let me know if you need anything else.";
    } else {
      return "I understand you said: \"$userMessage\". I'm here to help with your smart home devices. Try asking me to turn on/off devices, check energy usage, or set schedules!";
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

  bool _isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width <
        600; // Define your small screen breakpoint
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = _isSmallScreen(context);
    final panelWidth = isSmallScreen
        ? MediaQuery.of(context).size.width
        : MediaQuery.of(context).size.width * 0.4;

    return SlideTransition(
      position: _slideAnimation,
      child: Align(
        alignment: Alignment.centerRight,
        child: Theme(
          data: darkTheme, // Apply the dark theme explicitly
          child: Material(
            elevation: 16,
            shadowColor: Colors.black45,
            child: Container(
              width: panelWidth,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).cardColor,
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((255 * 0.3).round()),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal.withAlpha(
                                  (255 * 0.2).round(),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.smart_toy,
                                color: Colors.teal,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Smart Assistant",
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  "Online",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              onPressed: () {
                                _slideController.reverse().then((_) {
                                  Navigator.of(context).pop();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Messages
                  Expanded(
                    child: _messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color?.withAlpha(77),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Start a conversation",
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color
                                        ?.withAlpha(128),
                                    fontSize: 16,
                                  ),
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
                              final isUser = msg["sender"] == "user";
                              return _buildMessageBubble(
                                context,
                                msg["message"]!,
                                isUser,
                              );
                            },
                          ),
                  ),

                  // Typing indicator
                  if (_isTyping)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2F45),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTypingDot(0),
                              const SizedBox(width: 4),
                              _buildTypingDot(1),
                              const SizedBox(width: 4),
                              _buildTypingDot(2),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Input field
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((255 * 0.3).round()),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                style: Theme.of(context).textTheme.bodyLarge,
                                decoration: InputDecoration(
                                  hintText: "Type your message...",
                                  hintStyle: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color
                                        ?.withAlpha(128),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                                textInputAction: TextInputAction.send,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.secondary,
                                    Theme.of(
                                      context,
                                    ).colorScheme.secondary.withAlpha(150),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.send,
                                  color: Theme.of(context).iconTheme.color,
                                ),
                                onPressed: _sendMessage,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    String message,
    bool isUser,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withAlpha((255 * 0.2).round()),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.smart_toy,
                color: Theme.of(context).colorScheme.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.secondary,
                          Theme.of(
                            context,
                          ).colorScheme.secondary.withAlpha(150),
                        ],
                      )
                    : null,
                color: isUser ? null : Theme.of(context).cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.2).round()),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontSize: 15, height: 1.4),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withAlpha((255 * 0.2).round()),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.secondary,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animValue = (value - delay).clamp(0.0, 1.0);
        final opacity = (animValue * 2).clamp(0.3, 1.0);

        return Opacity(
          opacity: opacity,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted && _isTyping) {
          setState(() {});
        }
      },
    );
  }
}
