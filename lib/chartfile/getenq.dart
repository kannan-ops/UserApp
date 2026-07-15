import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:enquiry_app/utils/api_debug_logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'editenq.dart';
import 'chat_screen.dart';
import 'package:enquiry_app/widgets/sms_chat_dialog.dart';
import 'package:enquiry_app/widgets/reply_form_dialog.dart';
import 'package:enquiry_app/services/storage_service.dart';

class GetEnquiry extends StatefulWidget {
  const GetEnquiry({super.key});

  @override
  State<GetEnquiry> createState() => _GetEnquiryState();
}

class _GetEnquiryState extends State<GetEnquiry> {
  late Future<List<dynamic>> futureEnquiries;
  String _searchQuery = "";
  String _selectedFilter = "all";
  final Set<int> _expandedIds = {};
  bool _isAdmin = false;

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

  final String apiUrl = "https://bulk.srivagroups.in/api/enquiries?limit=1000000";

  Future<List<dynamic>> fetchEnquiries() async {
    _isChatStatusLoaded = false;
    List<dynamic> allEnquiries = [];
    int currentPage = 1;
    const int limit = 1000000;
    bool hasMore = true;

    while (hasMore) {
      final url = "https://bulk.srivagroups.in/api/enquiries?limit=$limit&page=$currentPage";
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
          allEnquiries.addAll(rawList);
          if (total > 0 && allEnquiries.length >= total) {
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

      final list = allEnquiries.map((x) {
        if (x is Map) {
          final item = Map<String, dynamic>.from(x);

          final dynamic rawMethods = item['contact_methods'];
          if (rawMethods == null || rawMethods.toString().trim().isEmpty) {
            item['contactType'] = "Callback, SMS, WhatsApp, Mail";
          } else {
            item['contactType'] = rawMethods
                .toString()
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .join(', ');
          }

          final methodsLower = item['contactType'].toLowerCase();
          item['contact_callback'] = methodsLower.contains('callback') || methodsLower.contains('call');
          item['contact_sms'] = methodsLower.contains('sms');
          item['contact_whatsapp'] = methodsLower.contains('whatsapp') || methodsLower.contains('wa');
          item['contact_mail'] = methodsLower.contains('mail');
          item['contact_Callback'] = item['contact_callback'];
          item['contact_SMS'] = item['contact_sms'];
          item['contact_WhatsApp'] = item['contact_whatsapp'];
          item['contact_Mail'] = item['contact_mail'];

          item['imagePath'] ??= item['image_path'];
          item['pdfPath'] ??= item['pdf_path'];
          item['company'] ??= item['company_name'];
          item['createdDate'] ??= item['submitted_at'] ?? item['created_date'] ?? item['created_at'];
          return item;
        }
        return x;
      }).toList();

      _fetchAllChatStatuses(list, "enquiry");
      return list;
  }

  Future<void> deleteEnquiry(int id) async {
    final res = await ApiDebugLogger.httpClient.delete(
      Uri.parse("https://bulk.srivagroups.in/api/enquiries/$id"),
    );

    if (res.statusCode == 200 || res.statusCode == 204) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Deleted Successfully"),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        futureEnquiries = fetchEnquiries();
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
        content: Text("Are you sure you want to delete this enquiry?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await deleteEnquiry(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showEnquiryDetails(Map<String, dynamic> e) {
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
                                  e["name"] ?? "Enquiry Details",
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

                          // Product Image or Attachment
                          Builder(
                            builder: (context) {
                              final imgPath = e["imagePath"]?.toString() ?? "";
                              final pdfPath = e["pdfPath"]?.toString() ?? "";
                              final isPdf = pdfPath.toLowerCase().endsWith('.pdf');
                              
                              final hasValidServerImg = imgPath.isNotEmpty && 
                                  !imgPath.startsWith('/') && 
                                  !imgPath.startsWith('content:/') && 
                                  !imgPath.contains('com.example');
                                  
                              final hasValidServerPdf = pdfPath.isNotEmpty && 
                                  !pdfPath.startsWith('/') && 
                                  !pdfPath.startsWith('content:/') && 
                                  !pdfPath.contains('com.example');
                              
                              // PDF attachment (button)
                              Widget? pdfWidget;
                              if (isPdf && hasValidServerPdf) {
                                pdfWidget = Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _launchWebUrl("https://user.jobes24x7.com/$pdfPath"),
                                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                                      label: Text(
                                        "View PDF (${pdfPath.split('/').last})",
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
                                );
                              }
                              
                              final String imageUrl;
                              final bool isUploadedImage;
                              
                              if (imgPath.isNotEmpty && hasValidServerImg) {
                                imageUrl = "https://user.jobes24x7.com/$imgPath";
                                isUploadedImage = true;
                              } else if (pdfPath.isNotEmpty && hasValidServerPdf && !isPdf) {
                                imageUrl = "https://user.jobes24x7.com/$pdfPath";
                                isUploadedImage = true;
                              } else {
                                imageUrl = "";
                                isUploadedImage = false;
                              }
                              
                              final imageWidget = isUploadedImage
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Attached Image:",
                                          style: TextStyle(
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
                                    )
                                  : const SizedBox.shrink();
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  imageWidget,
                                  if (pdfWidget != null) pdfWidget,
                                ],
                              );
                            },
                          ),

                          if (e["product_title"] != null && e["product_title"].toString().isNotEmpty)
                            _infoRow(Icons.shopping_bag, "Product: ", e["product_title"]),
                          _infoRow(Icons.person, "Client: ", e["name"] ?? ""),
                          _infoRow(Icons.phone, "Phone: ", e["mobile"] ?? ""),
                          _infoRow(Icons.email, "Email: ", e["email"] ?? ""),
                          _infoRow(Icons.business, "Company: ", e["company"] ?? ""),
                          _infoRow(
                            Icons.subject,
                            "Subject: ",
                            e["other_subject"] != null && e["other_subject"].toString().isNotEmpty
                                ? "${e["subject"]} (${e["other_subject"]})"
                                : (e["subject"] ?? ""),
                          ),
                          if (e["contactType"] != null && e["contactType"].toString().trim().isNotEmpty)
                            _infoRow(Icons.contact_mail, "Contact: ", e["contactType"] ?? ""),
                          _infoRow(Icons.link, "Website Link: ", e["link"] ?? "", isLink: true),
                          _infoRow(Icons.link, "Current URL: ", e["current_url"] ?? "", isLink: true),
                          _infoRow(Icons.calendar_today, "Submitted At: ", _formatDate(e["createdDate"])),
                          
                          if (e["comments"] != null && e["comments"].toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Comments: ${e["comments"]}",
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF334155),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],

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
                                final refId = e["id"] is int ? e["id"] : int.tryParse(e["id"].toString()) ?? 0;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      module: "enquiry",
                                      referenceId: refId,
                                      userName: e["name"] ?? "Enquiry Client",
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
                                  onPressed: () => _launchCall(e["mobile"] ?? ""),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _contactButton(
                                  icon: Icons.reply_rounded,
                                  label: "Reply",
                                  color: const Color(0xFF3B5BDB),
                                  onPressed: () {
                                    final refId = e["id"] is int ? e["id"] : int.tryParse(e["id"].toString()) ?? 0;
                                    showDialog<bool>(
                                      context: context,
                                      builder: (context) => ReplyFormDialog(
                                        phone: e["mobile"] ?? "",
                                        fullData: e,
                                        email: e["email"] ?? "",
                                        name: e["name"] ?? "",
                                        company: e["company"] ?? "",
                                        initialSubject: e["subject"] ?? "Enquiry",
                                        module: "enquiry",
                                        referenceId: refId,
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
    futureEnquiries = fetchEnquiries();
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
        title: Text("Enquiries"),
        backgroundColor: Color(0xFF3B5BDB),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              setState(() {
                futureEnquiries = fetchEnquiries();
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
                hintText: "Search by client name or subject...",
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
                future: futureEnquiries,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

            if (snapshot.hasError) {
              return Center(child: Text("Error : ${snapshot.error}"));
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  "No Enquiries Found",
                  style: TextStyle(fontSize: 16),
                ),
              );
            }

            final enquiries = snapshot.data!;
            List<dynamic> filteredEnquiries = enquiries.where((e) {
              final name = (e["name"] ?? "").toString().toLowerCase();
              final subject = (e["subject"] ?? "").toString().toLowerCase();
              return name.contains(_searchQuery) || subject.contains(_searchQuery);
            }).toList();

            // Apply filter chip selection
            if (_selectedFilter == "last") {
              final sorted = List.from(filteredEnquiries);
              sorted.sort((a, b) {
                final idA = a["id"] is int ? a["id"] : int.tryParse(a["id"].toString()) ?? 0;
                final idB = b["id"] is int ? b["id"] : int.tryParse(b["id"].toString()) ?? 0;
                return idB.compareTo(idA);
              });
              filteredEnquiries = sorted.isNotEmpty ? [sorted.first] : [];
            } else if (_selectedFilter == "received") {
              filteredEnquiries = filteredEnquiries.where((e) {
                final id = e["id"] is int ? e["id"] : int.tryParse(e["id"].toString()) ?? 0;
                final msgs = _chatMessages[id] ?? [];
                if (msgs.isEmpty) return false;
                final lastMsg = msgs.last;
                final sender = lastMsg["sender"]?.toString().toLowerCase() ?? "";
                return sender != "admin" && sender.isNotEmpty;
              }).toList();
            } else if (_selectedFilter == "unreplied") {
              filteredEnquiries = filteredEnquiries.where((e) {
                final id = e["id"] is int ? e["id"] : int.tryParse(e["id"].toString()) ?? 0;
                final msgs = _chatMessages[id] ?? [];
                return !msgs.any((m) => m["sender"]?.toString().toLowerCase() == "admin");
              }).toList();
            } else if (_selectedFilter == "sent") {
              filteredEnquiries = filteredEnquiries.where((e) {
                final id = e["id"] is int ? e["id"] : int.tryParse(e["id"].toString()) ?? 0;
                final msgs = _chatMessages[id] ?? [];
                return msgs.any((m) => m["sender"]?.toString().toLowerCase() == "admin");
              }).toList();
            }

            if (_selectedFilter != "last") {
              filteredEnquiries.sort((a, b) {
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

            if (filteredEnquiries.isEmpty) {
              return Column(
                children: [
                  _buildSummaryBanner(filteredEnquiries),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.filter_list_off_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            "No Matching Enquiries Found",
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
                _buildSummaryBanner(filteredEnquiries),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: filteredEnquiries.length,
                    itemBuilder: (context, index) {
                      final e = filteredEnquiries[index];
                      final id = e["id"] is int ? e["id"] : int.tryParse(e["id"].toString()) ?? 0;

                      final isExpanded = _expandedIds.contains(id);

                      final imgPath = e["imagePath"]?.toString() ?? "";
                      final pdfPath = e["pdfPath"]?.toString() ?? "";
                      final isPdf = pdfPath.toLowerCase().endsWith('.pdf');
                      
                      final hasValidServerImg = imgPath.isNotEmpty && 
                          !imgPath.startsWith('content:/') && 
                          !imgPath.startsWith('/data/') && 
                          !imgPath.startsWith('/storage/') && 
                          !imgPath.contains('com.example');
                          
                      final hasValidServerPdf = pdfPath.isNotEmpty && 
                          !pdfPath.startsWith('content:/') && 
                          !pdfPath.startsWith('/data/') && 
                          !pdfPath.startsWith('/storage/') && 
                          !pdfPath.contains('com.example');
                      
                      final String imageUrl;
                      if (imgPath.isNotEmpty && hasValidServerImg) {
                        imageUrl = imgPath.startsWith('http://') || imgPath.startsWith('https://')
                            ? imgPath
                            : imgPath.startsWith('/')
                                ? "https://user.jobes24x7.com$imgPath"
                                : "https://user.jobes24x7.com/$imgPath";
                      } else if (pdfPath.isNotEmpty && hasValidServerPdf && !isPdf) {
                        imageUrl = pdfPath.startsWith('http://') || pdfPath.startsWith('https://')
                            ? pdfPath
                            : pdfPath.startsWith('/')
                                ? "https://user.jobes24x7.com$pdfPath"
                                : "https://user.jobes24x7.com/$pdfPath";
                      } else {
                        imageUrl = "";
                      }

                      Widget? pdfWidget;
                      if (isPdf && hasValidServerPdf) {
                        final pdfUrl = pdfPath.startsWith('http://') || pdfPath.startsWith('https://')
                            ? pdfPath
                            : pdfPath.startsWith('/')
                                ? "https://user.jobes24x7.com$pdfPath"
                                : "https://user.jobes24x7.com/$pdfPath";
                        pdfWidget = Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _launchWebUrl(pdfUrl),
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                              label: Text(
                                "View PDF (${pdfPath.split('/').last})",
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
                        );
                      }

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
                                            e["other_subject"] != null && e["other_subject"].toString().isNotEmpty
                                                ? "${e["subject"]} (${e["other_subject"]})"
                                                : (e["subject"] ?? "Enquiry #${e["id"]}"),
                                            style: const TextStyle(
                                              fontSize: 20,
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
                                                  builder: (_) => EditEnquiryPage(data: e),
                                                ),
                                              ).then((_) {
                                                setState(() {
                                                  futureEnquiries = fetchEnquiries();
                                                });
                                              });
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () {
                                              confirmDelete(e["id"]);
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
                                  "Submitted At: ",
                                  _formatDate(e["createdDate"]),
                                ),

                                 if (isExpanded) ...[
                                   const SizedBox(height: 8),
                                   if (imageUrl.isNotEmpty) ...[
                                     ClipRRect(
                                       borderRadius: BorderRadius.circular(12),
                                       child: Container(
                                         height: 180,
                                         width: double.infinity,
                                         decoration: BoxDecoration(
                                           color: Colors.grey.shade100,
                                           borderRadius: BorderRadius.circular(12),
                                         ),
                                         child: Image.network(
                                           imageUrl,
                                           fit: BoxFit.cover,
                                           errorBuilder: (context, error, stackTrace) => const Center(
                                             child: Icon(Icons.image, size: 40, color: Colors.grey),
                                           ),
                                         ),
                                       ),
                                     ),
                                     const SizedBox(height: 12),
                                   ],
                                   if (pdfWidget != null) ...[
                                     pdfWidget,
                                     const SizedBox(height: 12),
                                   ],
                                   _infoRow(Icons.person, "Client: ", e["name"] ?? ""),
                                  _infoRow(Icons.phone, "Phone: ", e["mobile"] ?? ""),
                                  _infoRow(Icons.email, "Email: ", e["email"] ?? ""),
                                  _infoRow(Icons.business, "Company: ", e["company"] ?? ""),
                                  _infoRow(Icons.message, "Enquiry Message: ", e["message"] ?? ""),
                                  if (e["contactType"] != null && e["contactType"].toString().trim().isNotEmpty)
                                    _infoRow(Icons.contact_mail, "Preferred Contact: ", e["contactType"] ?? ""),
                                  _infoRow(Icons.link, "Website Link: ", e["link"] ?? "", isLink: true),
                                  _infoRow(Icons.link, "Current URL: ", e["current_url"] ?? "", isLink: true),
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
                                                  onPressed: () => _launchCall(e["mobile"] ?? ""),
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
                                                        module: "enquiry",
                                                        name: e["name"] ?? "Client",
                                                        company: e["company"] ?? "",
                                                        initialSubject: e["subject"] ?? "Enquiry",
                                                        email: e["email"] ?? "",
                                                        phone: e["mobile"] ?? "",
                                                        fullData: e,
                                                      ),
                                                    ).then((val) {
                                                      if (val == true) {
                                                        setState(() {
                                                          futureEnquiries = fetchEnquiries();
                                                        });
                                                        _checkSingleChatStatus("enquiry", id);
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
                                                    module: "enquiry",
                                                    userName: e["name"] ?? "Client",
                                                  ),
                                                ),
                                              ).then((_) {
                                                _checkSingleChatStatus("enquiry", id);
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
      int hour = parsed.hour;
      final String period = hour >= 12 ? "PM" : "AM";
      hour = hour % 12;
      if (hour == 0) hour = 12;
      final String hourStr = hour.toString().padLeft(2, '0');
      final String minuteStr = parsed.minute.toString().padLeft(2, '0');
      return "${parsed.day.toString().padLeft(2, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.year} $hourStr:$minuteStr $period";
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
