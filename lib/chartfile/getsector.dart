  import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:enquiry_app/utils/api_debug_logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'editsec.dart';
import 'chat_screen.dart';
import 'package:enquiry_app/widgets/reply_form_dialog.dart';
import 'package:enquiry_app/services/storage_service.dart';

class GetById extends StatefulWidget {
  const GetById({super.key});

  @override
  State<GetById> createState() => _GetByIdState();
}

class _GetByIdState extends State<GetById> {
  late Future<List<dynamic>> futureProducts;
  String _searchQuery = "";
  String _selectedFilter = "all";
  final String apiUrl = "https://bulk.srivagroups.in/api/product?limit=1000000";

  final Map<int, bool> _unreadChats = {};
  final Map<int, List<dynamic>> _chatMessages = {};
  bool _isChatStatusLoaded = false;

  Future<void> _fetchAllChatStatuses(List<dynamic> items, String module) async {
    Map<int, List<dynamic>> tempChatMessages = {};
    Map<int, bool> tempUnreadChats = {};
    
    final chunkSize = 10;
    for (var i = 0; i < items.length; i += chunkSize) {
      if (!mounted) return;
      final chunk = items.sublist(i, i + chunkSize > items.length ? items.length : i + chunkSize);
      
      await Future.wait(chunk.map((item) async {
        if (item is! Map) return;
        final id = item["id"] is int ? item["id"] : int.tryParse(item["id"].toString()) ?? 0;
        if (id == 0) return;
        
        final url = "https://bulk.srivagroups.in/api/messages/$module/$id";
        try {
          final res = await ApiDebugLogger.httpClient.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            final decoded = jsonDecode(res.body);
            List<dynamic> msgs = [];
            if (decoded is List) {
              msgs = decoded;
            } else if (decoded is Map) {
              if (decoded.containsKey('messages')) {
                final m = decoded['messages'];
                if (m is List) msgs = m;
              } else if (decoded.containsKey('conversation')) {
                final c = decoded['conversation'];
                if (c is List) msgs = c;
              } else if (decoded.containsKey('data')) {
                final d = decoded['data'];
                if (d is List) {
                  msgs = d;
                } else if (d is Map) {
                  if (d.containsKey('messages')) {
                    final dm = d['messages'];
                    if (dm is List) msgs = dm;
                  } else if (d.containsKey('conversation')) {
                    final dc = d['conversation'];
                    if (dc is List) msgs = dc;
                  }
                }
              }
            }
            tempChatMessages[id] = msgs;
            if (msgs.isNotEmpty) {
              final lastMsg = msgs.last;
              final sender = lastMsg["sender"]?.toString().toLowerCase() ?? "";
              tempUnreadChats[id] = (sender != "admin" && sender.isNotEmpty);
            } else {
              tempUnreadChats[id] = false;
            }
          }
        } catch (_) {}
      }));
    }
    
    if (mounted) {
      setState(() {
        _chatMessages.addAll(tempChatMessages);
        _unreadChats.addAll(tempUnreadChats);
        _isChatStatusLoaded = true;
      });
    }
  }

  Future<void> _checkSingleChatStatus(String module, int id) async {
    if (id == 0) return;
    final url = "https://bulk.srivagroups.in/api/messages/$module/$id";
    try {
      final res = await ApiDebugLogger.httpClient.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List<dynamic> msgs = [];
        if (decoded is List) {
          msgs = decoded;
        } else if (decoded is Map) {
          if (decoded.containsKey('messages')) {
            final m = decoded['messages'];
            if (m is List) msgs = m;
          } else if (decoded.containsKey('conversation')) {
            final c = decoded['conversation'];
            if (c is List) msgs = c;
          } else if (decoded.containsKey('data')) {
            final d = decoded['data'];
            if (d is List) {
              msgs = d;
            } else if (d is Map) {
              if (d.containsKey('messages')) {
                final dm = d['messages'];
                if (dm is List) msgs = dm;
              } else if (d.containsKey('conversation')) {
                final dc = d['conversation'];
                if (dc is List) msgs = dc;
              }
            }
          }
        }
        if (mounted) {
          setState(() {
            _chatMessages[id] = msgs;
            if (msgs.isNotEmpty) {
              final lastMsg = msgs.last;
              final sender = lastMsg["sender"]?.toString().toLowerCase() ?? "";
              _unreadChats[id] = (sender != "admin" && sender.isNotEmpty);
            } else {
              _unreadChats[id] = false;
            }
          });
        }
      }
    } catch (_) {}
  }
  final Set<int> _expandedIds = {};
  bool _isAdmin = false;


  Future<List<dynamic>> fetchProducts() async {
    _isChatStatusLoaded = false;
    List<dynamic> allProducts = [];
    int currentPage = 1;
    const int limit = 1000000;
    bool hasMore = true;

    while (hasMore) {
      final url = "https://bulk.srivagroups.in/api/product?limit=$limit&page=$currentPage";
      final res = await ApiDebugLogger.httpClient.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List<dynamic> rawList = [];
        int total = 0;

        if (decoded is Map) {
          if (decoded.containsKey('total')) {
            total = decoded['total'] is int 
                ? decoded['total'] 
                : int.tryParse(decoded['total'].toString()) ?? 0;
          }
          if (decoded.containsKey('data')) {
            final dataVal = decoded['data'];
            if (dataVal is List) {
              rawList = dataVal;
            } else if (dataVal is Map) {
              if (dataVal.containsKey('data')) {
                final nestedDataVal = dataVal['data'];
                if (nestedDataVal is List) {
                  rawList = nestedDataVal;
                }
              }
            }
          }
        } else if (decoded is List) {
          rawList = decoded;
        }

        if (rawList.isEmpty) {
          hasMore = false;
        } else {
          allProducts.addAll(rawList);
          if (total > 0 && allProducts.length >= total) {
            hasMore = false;
          } else {
            currentPage++;
            if (currentPage > 100) {
              hasMore = false;
            }
          }
        }
      } else {
        hasMore = false;
      }
    }

      final list = allProducts.map((x) {
        if (x is Map) {
          final item = Map<String, dynamic>.from(x);
          item['total_Price'] ??= item['total_price'];
          return item;
        }
        return x;
      }).toList();

      _fetchAllChatStatuses(list, "sector");
      return list;
  }

  Future<void> deleteProduct(int id) async {
    final res = await ApiDebugLogger.httpClient.delete(
      Uri.parse("https://bulk.srivagroups.in/api/product/$id"),
    );

    if (res.statusCode == 200 || res.statusCode == 204) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Deleted Successfully"),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        futureProducts = fetchProducts();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete Failed : ${res.statusCode}")),
      );
    }
  }

  void confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Confirm Delete"),
        content: Text("Are you sure you want to delete this record?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await deleteProduct(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showProductDetails(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  p["title"] ?? p["name"] ?? "Product Details",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const Divider(height: 20, thickness: 1),

                          // Product Image/File attachment check
                          Builder(
                            builder: (context) {
                              final filePath = (p["file"] ?? p["filePath"] ?? p["imagePath"] ?? p["pdfPath"] ?? p["pdf_path"] ?? p["image_path"] ?? "").toString();
                              final isPdf = filePath.toLowerCase().endsWith('.pdf');
                              final hasValidFile = filePath.isNotEmpty && 
                                  !filePath.startsWith('content:/') && 
                                  !filePath.startsWith('/data/') && 
                                  !filePath.startsWith('/storage/') && 
                                  !filePath.contains('com.example');
                              
                              if (isPdf && hasValidFile) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _launchWebUrl("https://user.jobes24x7.com/$filePath"),
                                        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                                        label: Text(
                                          "View PDF (${filePath.split('/').last})",
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade700,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                );
                              }
                              
                              if (!hasValidFile || isPdf) {
                                return const SizedBox.shrink();
                              }
                              
                              final String imageUrl;
                              final String titleText = "Attached Image:";
                              if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
                                imageUrl = filePath;
                              } else {
                                imageUrl = filePath.startsWith('/') 
                                    ? "https://user.jobes24x7.com$filePath" 
                                    : "https://user.jobes24x7.com/$filePath";
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titleText,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: GestureDetector(
                                      onTap: () => _launchWebUrl(imageUrl),
                                      child: Image.network(
                                        imageUrl,
                                        height: 220,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          height: 120,
                                          color: const Color(0xFFF1F5F9),
                                          child: const Center(
                                            child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            },
                          ),

                          _infoRow(Icons.person, "Client: ", p["name"] ?? ""),
                          _infoRow(Icons.phone, "Phone: ", p["mobile"] ?? ""),
                          _infoRow(Icons.email, "Email: ", p["email"] ?? ""),
                          _infoRow(Icons.attach_money, "MRP: ", (p["mrp"] ?? "").toString()),
                          _infoRow(Icons.local_offer, "Price: ", (p["price"] ?? "").toString()),
                          _infoRow(Icons.format_list_numbered, "Quantity: ", (p["quantity"] ?? "").toString()),
                          _infoRow(Icons.functions, "Total: ", (p["total_Price"] ?? "").toString()),
                          _infoRow(Icons.link, "Website Link: ", p["current_url"] ?? "", isLink: true),
                          _infoRow(Icons.calendar_today, "Date: ", _formatDate(p["date"])),
                          _infoRow(Icons.access_time, "Time: ", p["time"] ?? ""),

                          const SizedBox(height: 24),
                          const Divider(height: 1, thickness: 1),
                          const SizedBox(height: 16),

                          // Quick Action Buttons
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.chat, color: Colors.white),
                              label: const Text(
                                "Chat",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B5BDB),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context); // Close details sheet
                                final refId = p["id"] is int ? p["id"] : int.tryParse(p["id"].toString()) ?? 0;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      module: "product",
                                      referenceId: refId,
                                      userName: p["name"] ?? "Sector Client",
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: _contactButton(
                                  icon: Icons.phone,
                                  label: "Call",
                                  color: Colors.green.shade600,
                                  onPressed: () => _launchCall(p["mobile"] ?? ""),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _contactButton(
                                  icon: Icons.reply_rounded,
                                  label: "Reply",
                                  color: const Color(0xFF3B5BDB),
                                  onPressed: () {
                                    final refId = p["id"] is int ? p["id"] : int.tryParse(p["id"].toString()) ?? 0;
                                    showDialog<bool>(
                                      context: context,
                                      builder: (context) => ReplyFormDialog(
                                        phone: p["mobile"] ?? "",
                                        email: p["email"] ?? "",
                                        name: p["name"] ?? "",
                                        company: p["company"] ?? "",
                                        initialSubject: "Product Inquiry",
                                        module: "product",
                                        referenceId: refId,
                                        fullData: p,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'View All', 'icon': Icons.all_inclusive_rounded},
      {'key': 'last', 'label': 'Last Added', 'icon': Icons.history_rounded},
      {'key': 'unreplied', 'label': 'Not Replied', 'icon': Icons.mark_chat_unread_rounded},
      {'key': 'received', 'label': 'Replies Received', 'icon': Icons.call_received_rounded},
      {'key': 'sent', 'label': 'Replies Sent', 'icon': Icons.call_made_rounded},
    ];

    return Container(
      height: 48,
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              showCheckmark: false,
              avatar: Icon(
                filter['icon'] as IconData,
                color: isSelected ? Colors.white : const Color(0xFF3B5BDB),
                size: 16,
              ),
              label: Text(
                filter['label'] as String,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF1E293B),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF3B5BDB),
              backgroundColor: const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF3B5BDB) : Colors.transparent,
                  width: 1,
                ),
              ),
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _selectedFilter = filter['key'] as String;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryBanner(List<dynamic> items) {
    int total = items.length;
    int replied = 0;
    int pending = 0;

    for (var item in items) {
      if (item is Map) {
        final id = item["id"] is int ? item["id"] : int.tryParse(item["id"].toString()) ?? 0;
        final msgs = _chatMessages[id];
        if (msgs != null && msgs.any((m) => m["sender"]?.toString().toLowerCase() == "admin")) {
          replied++;
        } else {
          pending++;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B5BDB).withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFF3B5BDB).withOpacity(0.12), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _summaryItem("Total", total, Colors.grey.shade700),
          _summaryItem("Replied", _isChatStatusLoaded ? replied : null, Colors.green.shade700),
          _summaryItem("Pending", _isChatStatusLoaded ? pending : null, Colors.orange.shade700),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, int? count, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 4),
        count == null 
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          : Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    futureProducts = fetchProducts();
    _loadAdminStatus();
  }

  Future<void> _loadAdminStatus() async {
    final storage = await StorageService.getInstance();
    if (mounted) {
      setState(() {
        _isAdmin = storage.userRole.toLowerCase() == 'admin';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Product List"),
        backgroundColor: Color(0xFF3B5BDB),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              setState(() {
                futureProducts = fetchProducts();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: Colors.white,
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: "Search by product name...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          _buildFilterChips(),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEEF2FF), Color(0xFFF9FAFF), Color(0xFFFFFFFF)],
                ),
              ),
              child: FutureBuilder<List<dynamic>>(
                future: futureProducts,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

            if (snapshot.hasError) {
              return Center(child: Text("Error : ${snapshot.error}"));
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Text("No Data Found", style: TextStyle(fontSize: 16)),
              );
            }

            final products = snapshot.data!;
            List<dynamic> filteredProducts = products.where((p) {
              final name = (p["name"] ?? "").toString().toLowerCase();
              return name.contains(_searchQuery);
            }).toList();

            // Apply filter chip selection
            if (_selectedFilter == "last") {
              final sorted = List.from(filteredProducts);
              sorted.sort((a, b) {
                final idA = a["id"] is int ? a["id"] : int.tryParse(a["id"].toString()) ?? 0;
                final idB = b["id"] is int ? b["id"] : int.tryParse(b["id"].toString()) ?? 0;
                return idB.compareTo(idA);
              });
              filteredProducts = sorted.isNotEmpty ? [sorted.first] : [];
            } else if (_selectedFilter == "received") {
              filteredProducts = filteredProducts.where((p) {
                final id = p["id"] is int ? p["id"] : int.tryParse(p["id"].toString()) ?? 0;
                final msgs = _chatMessages[id] ?? [];
                if (msgs.isEmpty) return false;
                final lastMsg = msgs.last;
                final sender = lastMsg["sender"]?.toString().toLowerCase() ?? "";
                return sender != "admin" && sender.isNotEmpty;
              }).toList();
            } else if (_selectedFilter == "unreplied") {
              filteredProducts = filteredProducts.where((p) {
                final id = p["id"] is int ? p["id"] : int.tryParse(p["id"].toString()) ?? 0;
                final msgs = _chatMessages[id] ?? [];
                return !msgs.any((m) => m["sender"]?.toString().toLowerCase() == "admin");
              }).toList();
            } else if (_selectedFilter == "sent") {
              filteredProducts = filteredProducts.where((p) {
                final id = p["id"] is int ? p["id"] : int.tryParse(p["id"].toString()) ?? 0;
                final msgs = _chatMessages[id] ?? [];
                return msgs.any((m) => m["sender"]?.toString().toLowerCase() == "admin");
              }).toList();
            }

            if (_selectedFilter != "last") {
              filteredProducts.sort((a, b) {
                final idA = a["id"] is int ? a["id"] : int.tryParse(a["id"].toString()) ?? 0;
                final idB = b["id"] is int ? b["id"] : int.tryParse(b["id"].toString()) ?? 0;
                
                final msgsA = _chatMessages[idA];
                final msgsB = _chatMessages[idB];
                
                bool hasRepliedA = false;
                bool hasRepliedB = false;
                if (msgsA != null) {
                  hasRepliedA = msgsA.any((m) => m["sender"]?.toString().toLowerCase() == "admin");
                }
                if (msgsB != null) {
                  hasRepliedB = msgsB.any((m) => m["sender"]?.toString().toLowerCase() == "admin");
                }
                
                if (!hasRepliedA && hasRepliedB) return -1;
                if (hasRepliedA && !hasRepliedB) return 1;
                
                return idB.compareTo(idA);
              });
            }

            if (filteredProducts.isEmpty) {
              return Column(
                children: [
                  _buildSummaryBanner(filteredProducts),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.filter_list_off_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            "No Matching Sectors Found",
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _buildSummaryBanner(filteredProducts),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final p = filteredProducts[index];
                      final id = p["id"] is int ? p["id"] : int.tryParse(p["id"].toString()) ?? 0;

                      final filePath = (p["file"] ?? p["filePath"] ?? p["imagePath"] ?? p["pdfPath"] ?? p["pdf_path"] ?? p["image_path"] ?? "").toString();
                      final isPdf = filePath.toLowerCase().endsWith('.pdf');
                      final hasValidFile = filePath.isNotEmpty && 
                          !filePath.startsWith('content:/') && 
                          !filePath.startsWith('/data/') && 
                          !filePath.startsWith('/storage/') && 
                          !filePath.contains('com.example');

                      final String imageUrl;
                      if (hasValidFile && !isPdf) {
                        if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
                          imageUrl = filePath;
                        } else {
                          imageUrl = filePath.startsWith('/') 
                              ? "https://user.jobes24x7.com$filePath" 
                              : "https://user.jobes24x7.com/$filePath";
                        }
                      } else {
                        imageUrl = "";
                      }

                      final isExpanded = _expandedIds.contains(id);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 4,
                        shadowColor: const Color(0x223B5BDB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedIds.remove(id);
                              } else {
                                _expandedIds.add(id);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                            Text(
                                            p["title"] ?? p["name"] ?? "Sector Product",
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          Builder(
                                            builder: (context) {
                                              if (!_isChatStatusLoaded) {
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      SizedBox(
                                                        width: 10,
                                                        height: 10,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 1.5,
                                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        "Loading...",
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.grey.shade500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }
                                              final msgs = _chatMessages[id];
                                              final bool isPending = msgs == null || !msgs.any((m) => m["sender"]?.toString().toLowerCase() == "admin");
                                              if (isPending) {
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.shade50,
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: Colors.orange.shade300, width: 1),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.hourglass_empty_rounded, size: 12, color: Colors.orange.shade800),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        "Pending Reply",
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.orange.shade800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              } else {
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade50,
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: Colors.green.shade300, width: 1),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.check_circle_outline_rounded, size: 12, color: Colors.green.shade800),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        "Replied",
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.green.shade800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }
                                            },
                                          ),


                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_isAdmin) ...
                                        [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => EditPage(data: p),
                                                ),
                                              ).then((_) {
                                                setState(() {
                                                  futureProducts = fetchProducts();
                                                });
                                              });
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () {
                                              confirmDelete(p["id"]);
                                            },
                                          ),
                                        ],
                                        Icon(
                                          isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                          color: Colors.grey.shade500,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 16, thickness: 1),
                                const SizedBox(height: 4),

                                // DATE AND TIME ON THE FRONT (VERY PROMINENT)
                                _infoRow(
                                  Icons.calendar_today,
                                  "Date: ",
                                  _formatDate(p["date"]),
                                ),

                                if (isExpanded) ...[
                                  const SizedBox(height: 12),
                                  // Product Image Header in Card when expanded
                                  if (imageUrl.isNotEmpty) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        imageUrl,
                                        height: 150,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          height: 150,
                                          color: Colors.grey.shade100,
                                          child: const Center(
                                            child: Icon(Icons.image, size: 40, color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  _infoRow(Icons.access_time, "Time: ", p["time"] ?? ""),
                                  _infoRow(Icons.person, "Client: ", p["name"] ?? ""),
                                  _infoRow(Icons.attach_money, "MRP: ", (p["mrp"] ?? "").toString()),
                                  _infoRow(Icons.local_offer, "Price: ", (p["price"] ?? "").toString()),
                                  _infoRow(Icons.format_list_numbered, "Quantity: ", (p["quantity"] ?? "").toString()),
                                  _infoRow(Icons.functions, "Total: ", (p["total_Price"] ?? "").toString()),
                                  _infoRow(Icons.link, "Website Link: ", p["current_url"] ?? "", isLink: true),
                                  const SizedBox(height: 16),
                                  const Divider(height: 1, thickness: 1),
                                  const SizedBox(height: 16),
                                  // Quick Action Buttons Section
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFEDF2F7)),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12),
                                                  gradient: LinearGradient(
                                                    colors: [const Color(0xFF059669), Colors.teal.shade500],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(0xFF10B981).withOpacity(0.15),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 3),
                                                    ),
                                                  ],
                                                ),
                                                child: ElevatedButton.icon(
                                                  icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 18),
                                                  label: const Text("Call Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.transparent,
                                                    shadowColor: Colors.transparent,
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                  onPressed: () => _launchCall(p["mobile"] ?? ""),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12),
                                                  gradient: const LinearGradient(
                                                    colors: [Color(0xFF3B5BDB), Color(0xFF4C6EF5)],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(0xFF3B5BDB).withOpacity(0.15),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 3),
                                                    ),
                                                  ],
                                                ),
                                                child: ElevatedButton.icon(
                                                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                                  label: const Text("Reply / Message", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.transparent,
                                                    shadowColor: Colors.transparent,
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => ReplyFormDialog(
                                                        referenceId: id,
                                                        module: "sector",
                                                        name: p["name"] ?? "Client",
                                                      company: "",
                                                        initialSubject: p["title"] ?? "Sector Product",
                                                        email: p["email"] ?? "",
                                                        phone: p["mobile"] ?? "",
                                                        fullData: p,
                                                      ),
                                                    ).then((val) {
                                                      if (val == true) {
                                                        setState(() {
                                                          futureProducts = fetchProducts();
                                                        });
                                                        _checkSingleChatStatus("sector", id);
                                                      }
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            icon: const Icon(Icons.history_rounded, color: Color(0xFF3B5BDB), size: 18),
                                            label: const Text("View Message History", style: TextStyle(color: Color(0xFF3B5BDB), fontWeight: FontWeight.bold, fontSize: 14)),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(color: const Color(0xFF3B5BDB).withOpacity(0.4), width: 1.5),
                                              backgroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => ChatScreen(
                                                    referenceId: id,
                                                    module: "sector",
                                                    userName: p["name"] ?? "Client",
                                                  ),
                                                ),
                                              ).then((_) {
                                                _checkSingleChatStatus("sector", id);
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 12),
                                  Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.touch_app, size: 16, color: Colors.blue.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Tap card to expand details",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.blue.shade600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  ],
),
    );
  }

  String _getProductImageUrl(String title) {
    final t = title.toLowerCase();
    if (t.contains('laptop') || t.contains('macbook') || t.contains('notebook')) {
      return 'https://images.unsplash.com/photo-1496181130204-755241544e35?w=500&auto=format&fit=crop';
    } else if (t.contains('tv') || t.contains('television') || t.contains('led tv') || t.contains('screen')) {
      return 'https://images.unsplash.com/photo-1593305841991-05c297ba4575?w=500&auto=format&fit=crop';
    } else if (t.contains('mobile') || t.contains('samsung') || t.contains('galaxy') || t.contains('iphone') || t.contains('phone')) {
      return 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500&auto=format&fit=crop';
    } else if (t.contains('desktop') || t.contains('pc') || t.contains('computer') || t.contains('docking')) {
      return 'https://images.unsplash.com/photo-1547082299-de196ea013d6?w=500&auto=format&fit=crop';
    } else {
      return 'https://images.unsplash.com/photo-1523474253046-8cd2748b5fd2?w=500&auto=format&fit=crop';
    }
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return "";
    try {
      final parsed = DateTime.parse(rawDate);
      return "${parsed.day.toString().padLeft(2, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.year}";
    } catch (_) {
      if (rawDate.length >= 10) return rawDate.substring(0, 10);
      return rawDate;
    }
  }

  Future<void> _launchWebUrl(String urlString) async {
    if (urlString.isEmpty) return;
    String cleanUrl = urlString.trim().replaceAll(' ', '');
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }
    final Uri uri = Uri.parse(cleanUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not launch $cleanUrl")),
          );
        }
      }
    }
  }

  Future<void> _launchCall(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch Phone Dialer")),
        );
      }
    }
  }

  Future<void> _launchSms(String phone) async {
    final Uri uri = Uri(scheme: 'sms', path: phone);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch SMS client")),
        );
      }
    }
  }

  Future<void> _launchMail(String email) async {
    final Uri uri = Uri(scheme: 'mailto', path: email);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch Email app")),
        );
      }
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    var cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length == 10) {
      cleanPhone = "91$cleanPhone";
    }
    final Uri uri = Uri.parse("https://wa.me/$cleanPhone");
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch WhatsApp")),
      );
    }
  }

  Widget _infoRow(IconData icon, String label, String value, {bool isLink = false}) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: GestureDetector(
              onTap: isLink ? () => _launchWebUrl(value) : null,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: isLink ? Colors.blue.shade700 : const Color(0xFF0F172A),
                  decoration: isLink ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 2,
      ),
    );
  }

  void _showReplyBottomSheet(BuildContext context, String name, String? phone, String? email, String itemDetails) {
    final messageController = TextEditingController(
      text: "Hi $name, regarding your request for $itemDetails: "
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(
                 "Reply to $name",
                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
               ),
               const SizedBox(height: 12),
               TextField(
                 controller: messageController,
                 maxLines: 4,
                 decoration: const InputDecoration(
                   border: OutlineInputBorder(),
                   hintText: "Type your reply here...",
                 ),
               ),
               const SizedBox(height: 16),
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: [
                   if (phone != null && phone.isNotEmpty) ...[
                     ElevatedButton.icon(
                       icon: const Icon(Icons.chat, color: Colors.white),
                       label: const Text("WhatsApp", style: TextStyle(color: Colors.white)),
                       style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                       onPressed: () async {
                         final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
                         final formattedPhone = cleanPhone.length == 10 ? "91$cleanPhone" : cleanPhone;
                         final uri = Uri.parse("https://wa.me/$formattedPhone?text=${Uri.encodeComponent(messageController.text)}");
                         await launchUrl(uri, mode: LaunchMode.externalApplication);
                         Navigator.pop(context);
                       },
                     ),
                     ElevatedButton.icon(
                       icon: const Icon(Icons.sms, color: Colors.white),
                       label: const Text("SMS", style: TextStyle(color: Colors.white)),
                       style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                       onPressed: () async {
                         final uri = Uri(
                           scheme: 'sms',
                           path: phone,
                           queryParameters: {'body': messageController.text},
                         );
                         await launchUrl(uri, mode: LaunchMode.externalApplication);
                         Navigator.pop(context);
                       },
                     ),
                   ],
                   if (email != null && email.isNotEmpty) ...[
                     ElevatedButton.icon(
                       icon: const Icon(Icons.mail, color: Colors.white),
                       label: const Text("Email", style: TextStyle(color: Colors.white)),
                       style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
                       onPressed: () async {
                         final uri = Uri(
                           scheme: 'mailto',
                           path: email,
                           queryParameters: {
                             'subject': 'Reply: $itemDetails',
                             'body': messageController.text,
                           },
                         );
                         await launchUrl(uri, mode: LaunchMode.externalApplication);
                         Navigator.pop(context);
                       },
                     ),
                   ],
                 ],
               ),
               const SizedBox(height: 20),
             ],
           ),
        );
      },
    );
  }
}
