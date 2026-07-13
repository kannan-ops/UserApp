import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:enquiry_app/utils/api_debug_logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class EditEnquiryPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const EditEnquiryPage({super.key, required this.data});

  @override
  State<EditEnquiryPage> createState() => _EditEnquiryPageState();
}

class _EditEnquiryPageState extends State<EditEnquiryPage> {
  final _formKey = GlobalKey<FormState>();

  final String apiUrl = "https://bulk.srivagroups.in/api/enquiries";

  late TextEditingController name;
  late TextEditingController mobile;
  late TextEditingController email;
  late TextEditingController company;
  late TextEditingController link;
  late TextEditingController subject;
  late TextEditingController comments;
  bool callback = false;
  bool sms = false;
  bool whatsapp = false;
  bool mail = false;
  late TextEditingController imagePath;
  late TextEditingController pdfPath;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        imagePath.text = image.path;
      });
    }
  }

  Future<void> _pickPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        pdfPath.text = result.files.single.path!;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    name = TextEditingController(text: widget.data["name"]);
    mobile = TextEditingController(text: widget.data["mobile"]);
    email = TextEditingController(text: widget.data["email"]);
    company = TextEditingController(text: widget.data["company"]);
    link = TextEditingController(text: widget.data["link"]);
    subject = TextEditingController(text: widget.data["subject"]);
    comments = TextEditingController(text: widget.data["comments"]);
    bool toBool(dynamic val) {
      if (val == null) return false;
      if (val is bool) return val;
      if (val is num) return val != 0;
      if (val is String) return val == '1' || val.toLowerCase() == 'true';
      return false;
    }
    
    final String ctStr = (widget.data["contactType"] ?? "").toString().toLowerCase();
    callback = ctStr.contains("callback") || ctStr.contains("call") || toBool(widget.data["contact_callback"] ?? widget.data["contact_Callback"] ?? widget.data["contact"]);
    sms = ctStr.contains("sms") || toBool(widget.data["contact_sms"] ?? widget.data["contact_SMS"]);
    whatsapp = ctStr.contains("whatsapp") || toBool(widget.data["contact_whatsapp"] ?? widget.data["contact_WhatsApp"]);
    mail = ctStr.contains("mail") || toBool(widget.data["contact_mail"] ?? widget.data["contact_Mail"]);
    imagePath = TextEditingController(text: widget.data["imagePath"]);
    pdfPath = TextEditingController(text: widget.data["pdfPath"]);
  }

  Future<void> updateEnquiry() async {
    if (!_formKey.currentState!.validate()) return;

    // Boolean flags callback, sms, whatsapp, mail are directly used.

    String formattedLink = link.text.trim().replaceAll(' ', '');
    if (formattedLink.isNotEmpty) {
      if (!formattedLink.startsWith('http://') && !formattedLink.startsWith('https://')) {
        formattedLink = 'https://$formattedLink';
      }
    }

    final body = {
      "id": widget.data["id"],
      "name": name.text,
      "mobile": mobile.text,
      "email": email.text,
      "company": company.text,
      "link": formattedLink,
      "subject": subject.text,
      "comments": comments.text,
      "contact_callback": callback,
      "contact_sms": sms,
      "contact_whatsapp": whatsapp,
      "contact_mail": mail,
      "contact_methods": [
        if (callback) "Callback",
        if (sms) "SMS",
        if (whatsapp) "WhatsApp",
        if (mail) "Mail",
      ].join(", "),
      "image_path": imagePath.text,
      "pdf_path": pdfPath.text,
      "product_title": subject.text.isNotEmpty ? subject.text : "Enquiry",
      "current_url": formattedLink.isNotEmpty ? formattedLink : "https://bulk.srivagroups.in",
    };

    final res = await ApiDebugLogger.httpClient.put(
      Uri.parse("$apiUrl/${widget.data["id"]}"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (res.statusCode == 200 || res.statusCode == 204) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Updated Successfully"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Update Failed : ${res.body}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Enquiry"),
        backgroundColor: Color(0xFF3B5BDB),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEEF2FF), Color(0xFFF9FAFF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x223B5BDB),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                children: [
                  field("Name", Icons.person, name),
                  field(
                    "Mobile",
                    Icons.phone,
                    mobile,
                    keyboard: TextInputType.phone,
                  ),
                  field(
                    "Email",
                    Icons.email,
                    email,
                    keyboard: TextInputType.emailAddress,
                  ),
                  field("Company", Icons.business, company),
                  field("Website Link", Icons.link, link),
                  field("Subject", Icons.subject, subject),
                  field("Comments", Icons.comment, comments, maxLines: 3),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Contact:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            option("Callback", callback, (v) => callback = v),
                            option("SMS", sms, (v) => sms = v),
                            option("WhatsApp", whatsapp, (v) => whatsapp = v),
                            option("Mail", mail, (v) => mail = v),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image),
                          label: const Text("Upload Image"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickPDF,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text("Upload PDF"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (imagePath.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.image, color: Colors.teal.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              imagePath.text.split('/').last.split('\\').last,
                              style: TextStyle(
                                color: Colors.teal.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                imagePath.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (pdfPath.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.picture_as_pdf,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pdfPath.text.split('/').last.split('\\').last,
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                pdfPath.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: updateEnquiry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3B5BDB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 6,
                      ),
                      child: Text(
                        "UPDATE ENQUIRY",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
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

  Widget field(
    String label,
    IconData icon,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        validator: (v) => v == null || v.isEmpty ? "Required field" : null,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF3B5BDB)),
          labelText: label,
          labelStyle: const TextStyle(
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: const Color(0xFFF1F4FF),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE0E6FF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF3B5BDB), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget option(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            activeColor: const Color(0xFF3B5BDB),
            onChanged: (v) => setState(() => onChanged(v ?? false)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Color(0xFF1E293B),
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
