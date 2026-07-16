import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:enquiry_app/utils/api_debug_logger.dart';
import 'chat_screen.dart';

class ChatThreadsScreen extends StatefulWidget {
  const ChatThreadsScreen({super.key});

  @override
  State<ChatThreadsScreen> createState() => _ChatThreadsScreenState();
}

class _ChatThreadsScreenState extends State<ChatThreadsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _bulkOrders = [];
  List<dynamic> _enquiries = [];
  List<dynamic> _sectors = [];

  bool _isLoadingBulk = false;
  bool _isLoadingEnq = false;
  bool _isLoadingSec = false;

  String _searchQuery = "";

  // Cache for messages of each thread
  final Map<String, List<dynamic>> _messagesCache = {};
  final Map<String, bool> _isLoadingMessages = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchBulkOrders();
    _fetchEnquiries();
    _fetchSectors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Future<void> _fetchMessagesFor(String module, int id) async {
    final key = "${module}_$id";
    _isLoadingMessages[key] = true;
    final url = "https://bulk.srivagroups.in/api/messages/$module/$id";
    try {
      final res = await ApiDebugLogger.httpClient.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final loadedMessages = _extractList(decoded);
        setState(() {
          _messagesCache[key] = loadedMessages;
        });
      }
    } catch (_) {}
    _isLoadingMessages[key] = false;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchBulkOrders() async {
    setState(() => _isLoadingBulk = true);
    try {
      final res = await ApiDebugLogger.httpClient.get(Uri.parse("https://bulk.srivagroups.in/api/bulk-orders?limit=1000000"));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List<dynamic> list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map && decoded.containsKey('data')) {
          final data = decoded['data'];
          if (data is List) list = data;
        }
        setState(() {
          _bulkOrders = list;
        });
        for (var item in list) {
          final id = item["id"] is int ? item["id"] : int.tryParse(item["id"].toString()) ?? 0;
          _fetchMessagesFor("bulk_order", id);
        }
      }
    } catch (_) {}
    setState(() => _isLoadingBulk = false);
  }

  Future<void> _fetchEnquiries() async {
    setState(() => _isLoadingEnq = true);
    try {
      final res = await ApiDebugLogger.httpClient.get(Uri.parse("https://bulk.srivagroups.in/api/enquiries?limit=1000000"));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List<dynamic> list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map && decoded.containsKey('data')) {
          final data = decoded['data'];
          if (data is List) list = data;
        }
        setState(() {
          _enquiries = list;
        });
        for (var item in list) {
          final id = item["id"] is int ? item["id"] : int.tryParse(item["id"].toString()) ?? 0;
          _fetchMessagesFor("enquiry", id);
        }
      }
    } catch (_) {}
    setState(() => _isLoadingEnq = false);
  }

  Future<void> _fetchSectors() async {
    setState(() => _isLoadingSec = true);
    try {
      final res = await ApiDebugLogger.httpClient.get(Uri.parse("https://bulk.srivagroups.in/api/product?limit=1000000"));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List<dynamic> list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map && decoded.containsKey('data')) {
          final data = decoded['data'];
          if (data is List) list = data;
        }
        setState(() {
          _sectors = list;
        });
        for (var item in list) {
          final id = item["id"] is int ? item["id"] : int.tryParse(item["id"].toString()) ?? 0;
          _fetchMessagesFor("product", id);
        }
      }
    } catch (_) {}
    setState(() => _isLoadingSec = false);
  }

  List<dynamic> _filterList(List<dynamic> list, String nameKey, String subKey) {
    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((item) {
      final name = (item[nameKey] ?? "").toString().toLowerCase();
      final sub = (item[subKey] ?? "").toString().toLowerCase();
      return name.contains(q) || sub.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Admin Chat Center",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3B5BDB),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _fetchBulkOrders();
              _fetchEnquiries();
              _fetchSectors();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_bag), text: "Bulk Orders"),
            Tab(icon: Icon(Icons.question_answer), text: "Enquiries"),
            Tab(icon: Icon(Icons.business), text: "Sectors"),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabContent(
                  items: _bulkOrders,
                  isLoading: _isLoadingBulk,
                  nameKey: "name",
                  subKey: "product",
                  module: "bulk_order",
                  icon: Icons.shopping_bag_outlined,
                  color: Colors.blue,
                ),
                _buildTabContent(
                  items: _enquiries,
                  isLoading: _isLoadingEnq,
                  nameKey: "name",
                  subKey: "subject",
                  module: "enquiry",
                  icon: Icons.question_answer_outlined,
                  color: Colors.purple,
                ),
                _buildTabContent(
                  items: _sectors,
                  isLoading: _isLoadingSec,
                  nameKey: "name",
                  subKey: "name",
                  module: "product",
                  icon: Icons.business_center_outlined,
                  color: Colors.teal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surface,
      child: TextField(
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        decoration: InputDecoration(
          hintText: "Search chats by user name...",
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
          prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
          filled: true,
          fillColor: Theme.of(context).colorScheme.brightness == Brightness.dark
              ? const Color(0xFF1E293B)
              : const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color, IconData icon, int count) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "$count",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    dynamic item,
    String nameKey,
    String subKey,
    String module,
    IconData icon,
    Color color,
    bool isUnread,
    bool isRecent,
  ) {
    final name = item[nameKey] ?? "Unknown Client";
    final sub = item[subKey] ?? "No details available";
    final id = item["id"] is int ? item["id"] : int.tryParse(item["id"].toString()) ?? 0;

    final key = "${module}_$id";
    final messages = _messagesCache[key] ?? [];
    String subtitleText = sub;
    String timeText = "";
    if (messages.isNotEmpty) {
      final lastMsg = messages.last;
      final rawMsg = (lastMsg["message"] ?? "").toString();
      final regExp = RegExp(r'\n\n\[via:(.*?)\]$');
      final match = regExp.firstMatch(rawMsg);
      if (match != null) {
        subtitleText = rawMsg.substring(0, match.start);
      } else {
        subtitleText = rawMsg;
      }
      final created = lastMsg["created_at"];
      if (created != null) {
        try {
          final dt = DateTime.parse(created.toString());
          timeText = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
        } catch (_) {}
      }
    }

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            if (isUnread)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            if (timeText.isNotEmpty)
              Text(
                timeText,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
          ],
        ),
        subtitle: Text(
          subtitleText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isUnread 
                ? Theme.of(context).colorScheme.onSurface 
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                module: module,
                referenceId: id,
                userName: name,
              ),
            ),
          );
          _fetchMessagesFor(module, id);
        },
      ),
    );
  }

  Widget _buildTabContent({
    required List<dynamic> items,
    required bool isLoading,
    required String nameKey,
    required String subKey,
    required String module,
    required IconData icon,
    required Color color,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filterList(items, nameKey, subKey);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              "No chats found",
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    final List<dynamic> unread = [];
    final List<dynamic> recent = [];
    final List<dynamic> noChats = [];

    for (var item in filtered) {
      final id = item["id"] is int ? item["id"] : int.tryParse(item["id"].toString()) ?? 0;
      final key = "${module}_$id";
      final messages = _messagesCache[key];

      if (messages == null || messages.isEmpty) {
        noChats.add(item);
      } else {
        final lastMsg = messages.last;
        final sender = lastMsg["sender"]?.toString().toLowerCase() ?? "";
        if (sender != "admin") {
          unread.add(item);
        } else {
          recent.add(item);
        }
      }
    }

    final List<Widget> children = [];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (unread.isNotEmpty) {
      children.add(_buildSectionHeader(
        "Unread Messages", 
        isDark ? Colors.red.shade300 : Colors.red.shade700, 
        Icons.mark_chat_unread_rounded, 
        unread.length,
      ));
      for (var item in unread) {
        children.add(_buildTile(item, nameKey, subKey, module, icon, color, true, false));
      }
    }

    if (recent.isNotEmpty) {
      children.add(_buildSectionHeader(
        "Recent Chats", 
        isDark ? Colors.blue.shade300 : Colors.blue.shade700, 
        Icons.chat_rounded, 
        recent.length,
      ));
      for (var item in recent) {
        children.add(_buildTile(item, nameKey, subKey, module, icon, color, false, true));
      }
    }

    if (noChats.isNotEmpty) {
      children.add(_buildSectionHeader(
        "No Chats Yet", 
        isDark ? Colors.grey.shade400 : Colors.grey.shade600, 
        Icons.chat_bubble_outline_rounded, 
        noChats.length,
      ));
      for (var item in noChats) {
        children.add(_buildTile(item, nameKey, subKey, module, icon, color, false, false));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: children,
    );
  }
}
