import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:enquiry_app/utils/api_debug_logger.dart';

class ReplyFormDialog extends StatefulWidget {
  final String phone;
  final String email;
  final String name;
  final String company;
  final String initialSubject;
  final String module;
  final int referenceId;
  final Map<String, dynamic>? fullData;

  const ReplyFormDialog({
    super.key,
    required this.phone,
    required this.email,
    required this.name,
    required this.company,
    required this.initialSubject,
    required this.module,
    required this.referenceId,
    this.fullData,
  });

  @override
  State<ReplyFormDialog> createState() => _ReplyFormDialogState();
}

class _ReplyFormDialogState extends State<ReplyFormDialog> {
  late TextEditingController _dearController;
  late TextEditingController _subjectController;
  late TextEditingController _conceptController;
  bool _isSending = false;
  bool _sendWhatsApp = true;
  bool _sendGmail = true;
  bool _sendSMS = true;

  String? _selectedImagePath;
  String? _selectedFilePath;

  @override
  void initState() {
    super.initState();
    final recipient = widget.company.isNotEmpty ? widget.company : widget.name;
    _dearController = TextEditingController(text: "Dear $recipient");
    _subjectController = TextEditingController(text: widget.initialSubject);
    _conceptController = TextEditingController();
  }

  @override
  void dispose() {
    _dearController.dispose();
    _subjectController.dispose();
    _conceptController.dispose();
    super.dispose();
  }

  String get _chatLink => "https://user.jobes24x7.com/chat/${widget.module}/${widget.referenceId}";

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: $e")),
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path!;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking file: $e")),
      );
    }
  }

  Map<String, String> _getPremiumDetails() {
    final Map<String, String> details = {};
    final data = widget.fullData ?? {};
    
    // Helper to extract the first non-empty value matching a list of potential keys
    String getValue(List<String> keys) {
      for (final key in keys) {
        if (data[key] != null && data[key].toString().trim().isNotEmpty) {
          return data[key].toString().trim();
        }
      }
      return "";
    }

    if (widget.module == 'bulk_order') {
      final category = getValue(["category"]);
      if (category.isNotEmpty) details["Category"] = category;
      
      final product = getValue(["product", "product_name", "product_title"]);
      if (product.isNotEmpty) details["Product Title"] = product;

      final quantity = getValue(["quantity"]);
      if (quantity.isNotEmpty) details["Quantity"] = quantity;

      final name = getValue(["name"]);
      if (name.isNotEmpty) details["Customer Name"] = name;

      final phone = getValue(["mobile", "phone"]);
      if (phone.isNotEmpty) details["Mobile Number"] = phone;

      final email = getValue(["email"]);
      if (email.isNotEmpty) details["Email Address"] = email;

      final company = getValue(["company", "company_name"]);
      if (company.isNotEmpty) details["Company Name"] = company;

      final deliveryDate = getValue(["deliveryDate", "preferred_delivery_date"]);
      if (deliveryDate.isNotEmpty) details["Delivery Date"] = deliveryDate;

      final specialInstructions = getValue(["specialInstructions", "special_instructions"]);
      if (specialInstructions.isNotEmpty) details["Special Instructions"] = specialInstructions;

      final link = getValue(["link"]);
      if (link.isNotEmpty) details["Website Link"] = link;

      final submittedAt = getValue(["submittedAt", "submitted_at"]);
      if (submittedAt.isNotEmpty) details["Submitted At"] = submittedAt;
    } else if (widget.module == 'enquiry') {
      final name = getValue(["name"]);
      if (name.isNotEmpty) details["Customer Name"] = name;

      final phone = getValue(["mobile", "phone"]);
      if (phone.isNotEmpty) details["Mobile Number"] = phone;

      final email = getValue(["email"]);
      if (email.isNotEmpty) details["Email Address"] = email;

      final company = getValue(["company", "company_name"]);
      if (company.isNotEmpty) details["Company Name"] = company;

      final subject = getValue(["subject"]);
      if (subject.isNotEmpty) details["Subject"] = subject;

      final otherSubject = getValue(["otherSubject", "other_subject"]);
      if (otherSubject.isNotEmpty) details["Other Subject"] = otherSubject;

      final comments = getValue(["comments", "message", "comment"]);
      if (comments.isNotEmpty) details["Comments / Message"] = comments;

      final link = getValue(["link"]);
      if (link.isNotEmpty) details["Website Link"] = link;

      final submittedAt = getValue(["createdDate", "created_at", "submitted_at"]);
      if (submittedAt.isNotEmpty) details["Submitted At"] = submittedAt;
    } else { // sector / product
      final title = getValue(["title", "product_title", "product_name", "name"]);
      if (title.isNotEmpty) details["Product Title"] = title;

      final name = getValue(["name"]);
      if (name.isNotEmpty) details["Customer Name"] = name;

      final phone = getValue(["mobile", "phone"]);
      if (phone.isNotEmpty) details["Mobile Number"] = phone;

      final email = getValue(["email"]);
      if (email.isNotEmpty) details["Email Address"] = email;

      final mrp = getValue(["mrp"]);
      if (mrp.isNotEmpty) details["MRP"] = mrp;

      final price = getValue(["price"]);
      if (price.isNotEmpty) details["Price"] = price;

      final quantity = getValue(["quantity"]);
      if (quantity.isNotEmpty) details["Quantity"] = quantity;

      final totalPrice = getValue(["total_price", "total_Price"]);
      if (totalPrice.isNotEmpty) details["Total Price"] = totalPrice;

      final link = getValue(["current_url", "link"]);
      if (link.isNotEmpty) details["Website Link"] = link;

      final dateTime = getValue(["date", "time", "createdDate", "created_at"]);
      if (dateTime.isNotEmpty) details["Date / Time"] = dateTime;
    }

    // Keep track of lowercased values already captured to dynamically ignore duplicates
    final Set<String> capturedValues = details.values.map((v) => v.toLowerCase()).toSet();
    
    // Technical, helper, or duplicate keys we should ignore
    final List<String> technicalKeys = [
      'id', 'user_id', 'parent_site_id', 'subdomain_site_id', 'pdf_path', 'image_path',
      'pdfpath', 'imagepath', 'chatstatus', 'has_new_messages', 'unread_count',
      'last_message_at', 'reply_status', 'bulkorderid', 'enquiryid', 'sectorid', 'status',
      'callback', 'sms', 'whatsapp', 'mail', 'contact'
    ];

    data.forEach((key, val) {
      if (val == null || val.toString().trim().isEmpty) return;
      final valStr = val.toString().trim();
      final keyLower = key.toLowerCase();
      
      // Skip already captured values to avoid double-entries
      if (capturedValues.contains(valStr.toLowerCase())) return;
      
      // Skip technical keys and helper booleans
      if (technicalKeys.any((tk) => keyLower.contains(tk))) return;
      if (val is bool) return;

      // Format clean key title
      final formattedKey = key
          .replaceAll('_', ' ')
          .split(' ')
          .map((str) => str.isNotEmpty ? '${str[0].toUpperCase()}${str.substring(1)}' : '')
          .join(' ');
      
      details[formattedKey] = valStr;
      capturedValues.add(valStr.toLowerCase());
    });

    return details;
  }

  IconData _getIconForKey(String key) {
    final k = key.toLowerCase();
    if (k.contains('name')) return Icons.person_rounded;
    if (k.contains('mobile') || k.contains('phone')) return Icons.phone_iphone_rounded;
    if (k.contains('email')) return Icons.alternate_email_rounded;
    if (k.contains('company')) return Icons.business_rounded;
    if (k.contains('product') || k.contains('title') || k.contains('category')) return Icons.shopping_bag_outlined;
    if (k.contains('quantity') || k.contains('mrp') || k.contains('price')) return Icons.payments_outlined;
    if (k.contains('date') || k.contains('time') || k.contains('submitted')) return Icons.calendar_today_rounded;
    if (k.contains('instructions') || k.contains('comments') || k.contains('subject')) return Icons.description_outlined;
    if (k.contains('link') || k.contains('url')) return Icons.link_rounded;
    return Icons.info_outline_rounded;
  }

  Color _getColorForKey(String key) {
    final k = key.toLowerCase();
    if (k.contains('name') || k.contains('company')) return Colors.indigo;
    if (k.contains('mobile') || k.contains('phone') || k.contains('email')) return Colors.teal;
    if (k.contains('product') || k.contains('title') || k.contains('category') || k.contains('quantity')) return Colors.blue;
    if (k.contains('instructions') || k.contains('comments') || k.contains('subject')) return Colors.amber.shade800;
    if (k.contains('link') || k.contains('url')) return Colors.purple;
    return Colors.blueGrey;
  }

  void _showReferenceDetails() {
    final details = _getPremiumDetails();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B5BDB).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFF3B5BDB),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${widget.module == 'bulk_order' ? 'Bulk Order' : widget.module == 'enquiry' ? 'Enquiry' : 'Sector Product'} Reference",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                "Reference ID: #${widget.referenceId}",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy_all_rounded, color: Color(0xFF3B5BDB)),
                              tooltip: "Copy All Details",
                              onPressed: () {
                                final allText = details.entries
                                    .map((e) => "${e.key}: ${e.value}")
                                    .join("\n");
                                Clipboard.setData(ClipboardData(text: allText));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text("All details copied!"),
                                    duration: const Duration(seconds: 1),
                                    backgroundColor: const Color(0xFF0F172A),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF3B5BDB).withOpacity(0.08),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(context),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.grey.shade100,
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  
                  // Details list
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: details.length,
                      itemBuilder: (context, index) {
                        final key = details.keys.elementAt(index);
                        final val = details[key]!;
                        final icon = _getIconForKey(key);
                        final color = _getColorForKey(key);
                        final kLower = key.toLowerCase();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade100, width: 1.5),
                          ),
                          color: const Color(0xFFF8FAFC),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: val));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Copied '$key' to clipboard!"),
                                  duration: const Duration(seconds: 1),
                                  backgroundColor: const Color(0xFF0F172A),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(icon, color: color, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          key.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade500,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          val,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Action buttons based on field type
                                  if (kLower.contains('mobile') || kLower.contains('phone'))
                                    _actionIconBtn(
                                      icon: Icons.call_rounded,
                                      color: Colors.green,
                                      tooltip: "Call",
                                      onTap: () async {
                                        final uri = Uri.parse("tel:$val");
                                        await launchUrl(uri).catchError((_) => false);
                                      },
                                    )
                                  else if (kLower.contains('email'))
                                    _actionIconBtn(
                                      icon: Icons.email_rounded,
                                      color: Colors.red.shade600,
                                      tooltip: "Send Email",
                                      onTap: () async {
                                        final uri = Uri.parse("mailto:$val");
                                        await launchUrl(uri).catchError((_) => false);
                                      },
                                    )
                                  else if (kLower.contains('link') || kLower.contains('url'))
                                    _actionIconBtn(
                                      icon: Icons.open_in_browser_rounded,
                                      color: Colors.purple,
                                      tooltip: "Open Website",
                                      onTap: () async {
                                        var link = val;
                                        if (!link.startsWith('http')) link = 'https://$link';
                                        final uri = Uri.parse(link);
                                        await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
                                      },
                                    )
                                  else
                                    Icon(
                                      Icons.copy_all_rounded,
                                      size: 18,
                                      color: Colors.grey.shade400,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _actionIconBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final dearText = _dearController.text.trim();
    final subjectText = _subjectController.text.trim();
    final conceptText = _conceptController.text.trim();

    if (conceptText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter the concept/message details."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_sendWhatsApp && !_sendGmail && !_sendSMS) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one channel to send."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    String attachmentInfo = "";
    if (_selectedImagePath != null) {
      final imgName = _selectedImagePath!.split('/').last.split('\\').last;
      attachmentInfo += "\n\n[Attached Image: $imgName]";
    }
    if (_selectedFilePath != null) {
      final fName = _selectedFilePath!.split('/').last.split('\\').last;
      attachmentInfo += "\n\n[Attached File: $fName]";
    }

    final fullMessage = "$dearText,\n\nSubject: $subjectText\n\n$conceptText$attachmentInfo\n\nChat link to reply:\n$_chatLink";

    final List<String> channels = [];
    if (_sendWhatsApp) channels.add("WhatsApp");
    if (_sendGmail) channels.add("Email");
    if (_sendSMS) channels.add("SMS");
    
    final savedMessage = "$fullMessage\n\n[via:${channels.join(',')}]";

    // 1. Save message to chat database API
    final url = "https://bulk.srivagroups.in/api/messages";
    final body = {
      "module": widget.module,
      "reference_id": widget.referenceId,
      "sender": "admin",
      "message": savedMessage,
    };

    try {
      await ApiDebugLogger.httpClient.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );
    } catch (_) {}

    // 2. Open WhatsApp
    if (_sendWhatsApp) {
      var cleanPhone = widget.phone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length == 10) {
        cleanPhone = "91$cleanPhone";
      }
      final waUri = Uri.parse("whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(fullMessage)}");
      try {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        final waFallback = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(fullMessage)}");
        await launchUrl(waFallback, mode: LaunchMode.externalApplication).catchError((_) => false);
      }

      if (_sendGmail || _sendSMS) {
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    }

    // 3. Open Email
    if (_sendGmail) {
      final String emailSubject = Uri.encodeComponent(subjectText);
      final String emailBody = Uri.encodeComponent(fullMessage);
      final Uri mailUri = Uri.parse("mailto:${widget.email}?subject=$emailSubject&body=$emailBody");
      try {
        await launchUrl(mailUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        await launchUrl(mailUri).catchError((_) => false);
      }

      if (_sendSMS) {
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    }

    // 4. Open SMS
    if (_sendSMS) {
      final smsBody = "$subjectText\n\nChat: $_chatLink";
      final Uri smsUri = Uri.parse("sms:${widget.phone}?body=${Uri.encodeComponent(smsBody)}");
      try {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        await launchUrl(smsUri).catchError((_) => false);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Reply sent and launchers executed!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  Widget _buildChannelChip({
    required String label,
    required bool isSelected,
    required IconData icon,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final bgColor = isSelected ? activeColor.withOpacity(0.08) : const Color(0xFFF8FAFC);
    final borderColor = isSelected ? activeColor.withOpacity(0.4) : Colors.grey.shade200;
    final textColor = isSelected ? activeColor : const Color(0xFF64748B);
    final iconColor = isSelected ? activeColor : const Color(0xFF94A3B8);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSending ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          enabled: enabled,
          style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            filled: true,
            fillColor: enabled ? const Color(0xFFF8FAFC) : Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3B5BDB), width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade100, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF3B5BDB);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: primaryColor, size: 28),
                      const SizedBox(width: 8),
                      const Text(
                        "Reply Form",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  if (widget.fullData != null && widget.fullData!.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.info_outline_rounded, color: primaryColor),
                      tooltip: "View Details",
                      onPressed: _showReferenceDetails,
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Dear Field
              _buildTextField(
                controller: _dearController,
                label: "Recipient Salutation",
                hint: "Dear Client Name/Company",
                icon: Icons.person_outline_rounded,
                enabled: !_isSending,
              ),
              const SizedBox(height: 16),

              // Subject Field
              _buildTextField(
                controller: _subjectController,
                label: "Subject",
                hint: "Enter subject",
                icon: Icons.subject_rounded,
                enabled: !_isSending,
              ),
              const SizedBox(height: 16),

              // Concept / Message Body Field
              _buildTextField(
                controller: _conceptController,
                label: "Concept / Message",
                hint: "Enter the concept details here...",
                icon: Icons.message_outlined,
                maxLines: 4,
                enabled: !_isSending,
              ),
              const SizedBox(height: 16),

              // Attachments
              const Text(
                "Attachments:",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text("Add Image", style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.attach_file_rounded, size: 18),
                      label: const Text("Add File/PDF", style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),
              if (_selectedImagePath != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.image, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedImagePath!.split('/').last.split('\\').last,
                          style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _selectedImagePath = null),
                        child: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
              if (_selectedFilePath != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file_rounded, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedFilePath!.split('/').last.split('\\').last,
                          style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _selectedFilePath = null),
                        child: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Preview Link
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.link_rounded, size: 16, color: Colors.blue),
                        SizedBox(width: 6),
                        Text(
                          "Chat Link Attachment",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _chatLink,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Send Via Channels — above Submit
              const Text(
                "Send Via:",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildChannelChip(
                    label: "WhatsApp",
                    isSelected: _sendWhatsApp,
                    icon: Icons.chat_bubble_outline_rounded,
                    activeColor: Colors.green.shade700,
                    onTap: () => setState(() => _sendWhatsApp = !_sendWhatsApp),
                  ),
                  const SizedBox(width: 8),
                  _buildChannelChip(
                    label: "Gmail",
                    isSelected: _sendGmail,
                    icon: Icons.mail_outline_rounded,
                    activeColor: Colors.red.shade700,
                    onTap: () => setState(() => _sendGmail = !_sendGmail),
                  ),
                  const SizedBox(width: 8),
                  _buildChannelChip(
                    label: "SMS",
                    isSelected: _sendSMS,
                    icon: Icons.sms_outlined,
                    activeColor: Colors.blue.shade700,
                    onTap: () => setState(() => _sendSMS = !_sendSMS),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSending ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [primaryColor, const Color(0xFF4C6EF5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              "Submit",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
