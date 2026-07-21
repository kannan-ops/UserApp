import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:enquiry_app/chartfile/chat_screen.dart';

class ShareHelper {
  static String formatEnquiry(Map<String, dynamic> e) {
    final buffer = StringBuffer();
    buffer.writeln("📋 ENQUIRY DETAILS");
    buffer.writeln("ID: #${e['id'] ?? 'N/A'}");
    if (e['name'] != null && e['name'].toString().isNotEmpty) buffer.writeln("Client Name: ${e['name']}");
    if (e['subject'] != null && e['subject'].toString().isNotEmpty) buffer.writeln("Subject: ${e['subject']}");
    if (e['company'] != null && e['company'].toString().isNotEmpty) buffer.writeln("Company: ${e['company']}");
    if (e['mobile'] != null && e['mobile'].toString().isNotEmpty) buffer.writeln("Mobile: ${e['mobile']}");
    if (e['email'] != null && e['email'].toString().isNotEmpty) buffer.writeln("Email: ${e['email']}");
    if (e['product'] != null && e['product'].toString().isNotEmpty) buffer.writeln("Product: ${e['product']}");
    if (e['category'] != null && e['category'].toString().isNotEmpty) buffer.writeln("Category: ${e['category']}");
    if (e['notes'] != null && e['notes'].toString().isNotEmpty) buffer.writeln("Notes: ${e['notes']}");
    if (e['submittedAt'] != null && e['submittedAt'].toString().isNotEmpty) buffer.writeln("Submitted: ${e['submittedAt']}");
    return buffer.toString();
  }

  static String formatBulkOrder(Map<String, dynamic> o) {
    final buffer = StringBuffer();
    buffer.writeln("📦 BULK ORDER DETAILS");
    buffer.writeln("ID: #${o['bulkOrderID'] ?? o['id'] ?? 'N/A'}");
    if (o['name'] != null && o['name'].toString().isNotEmpty) buffer.writeln("Client Name: ${o['name']}");
    if (o['product'] != null && o['product'].toString().isNotEmpty) buffer.writeln("Product: ${o['product']}");
    if (o['product_title'] != null && o['product_title'].toString().isNotEmpty) buffer.writeln("Product Title: ${o['product_title']}");
    if (o['quantity'] != null && o['quantity'].toString().isNotEmpty) buffer.writeln("Quantity: ${o['quantity']}");
    if (o['company'] != null && o['company'].toString().isNotEmpty) buffer.writeln("Company: ${o['company']}");
    if (o['mobile'] != null && o['mobile'].toString().isNotEmpty) buffer.writeln("Mobile: ${o['mobile']}");
    if (o['email'] != null && o['email'].toString().isNotEmpty) buffer.writeln("Email: ${o['email']}");
    if (o['category'] != null && o['category'].toString().isNotEmpty) buffer.writeln("Category: ${o['category']}");
    if (o['submittedAt'] != null && o['submittedAt'].toString().isNotEmpty) buffer.writeln("Submitted: ${o['submittedAt']}");
    return buffer.toString();
  }

  static String formatSector(Map<String, dynamic> p) {
    final buffer = StringBuffer();
    buffer.writeln("🏢 SECTOR PRODUCT DETAILS");
    buffer.writeln("ID: #${p['id'] ?? 'N/A'}");
    if (p['title'] != null && p['title'].toString().isNotEmpty) buffer.writeln("Title: ${p['title']}");
    if (p['name'] != null && p['name'].toString().isNotEmpty) buffer.writeln("Name: ${p['name']}");
    if (p['sector_title'] != null && p['sector_title'].toString().isNotEmpty) buffer.writeln("Sector: ${p['sector_title']}");
    if (p['price'] != null && p['price'].toString().isNotEmpty) buffer.writeln("Price: ${p['price']}");
    if (p['quantity'] != null && p['quantity'].toString().isNotEmpty) buffer.writeln("Quantity: ${p['quantity']}");
    if (p['category'] != null && p['category'].toString().isNotEmpty) buffer.writeln("Category: ${p['category']}");
    if (p['description'] != null && p['description'].toString().isNotEmpty) buffer.writeln("Description: ${p['description']}");
    return buffer.toString();
  }

  static String formatMultipleItems(List<dynamic> items, String itemType) {
    final buffer = StringBuffer();
    buffer.writeln("📌 SELECTED $itemType (${items.length} Items)\n");
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is Map<String, dynamic>) {
        buffer.writeln("--- Item #${i + 1} ---");
        if (itemType.contains("Enquir")) {
          buffer.writeln(formatEnquiry(item));
        } else if (itemType.contains("Bulk")) {
          buffer.writeln(formatBulkOrder(item));
        } else {
          buffer.writeln(formatSector(item));
        }
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  static void showShareBottomSheet({
    required BuildContext context,
    required String shareText,
    required String title,
    String? phone,
    String? email,
    String? clientName,
    int? referenceId,
    String? module,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _shareOption(
                      icon: Icons.chat_bubble_rounded,
                      color: const Color(0xFF25D366),
                      label: "WhatsApp",
                      onTap: () async {
                        Navigator.pop(ctx);
                        final url = Uri.parse("https://api.whatsapp.com/send?text=${Uri.encodeComponent(shareText)}");
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                    _shareOption(
                      icon: Icons.email_rounded,
                      color: const Color(0xFFEA4335),
                      label: "Gmail",
                      onTap: () async {
                        Navigator.pop(ctx);
                        final Uri emailUri = Uri(
                          scheme: 'mailto',
                          path: email ?? '',
                          queryParameters: {
                            'subject': title,
                            'body': shareText,
                          },
                        );
                        if (await canLaunchUrl(emailUri)) {
                          await launchUrl(emailUri);
                        }
                      },
                    ),
                    _shareOption(
                      icon: Icons.sms_rounded,
                      color: const Color(0xFF4285F4),
                      label: "SMS",
                      onTap: () async {
                        Navigator.pop(ctx);
                        final Uri smsUri = Uri(
                          scheme: 'sms',
                          path: phone ?? '',
                          queryParameters: {
                            'body': shareText,
                          },
                        );
                        if (await canLaunchUrl(smsUri)) {
                          await launchUrl(smsUri);
                        }
                      },
                    ),
                    _shareOption(
                      icon: Icons.forum_rounded,
                      color: const Color(0xFF3B5BDB),
                      label: "App Chat",
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              module: module ?? "enquiry",
                              referenceId: referenceId ?? 0,
                              userName: clientName ?? "Client",
                              initialMessage: shareText,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _shareOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
