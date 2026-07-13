import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:enquiry_app/utils/api_debug_logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class EditBULK extends StatefulWidget {
  final Map<String, dynamic> data;

  const EditBULK({super.key, required this.data});

  @override
  State<EditBULK> createState() => _EditBULKState();
}

class _EditBULKState extends State<EditBULK> {
  final _formKey = GlobalKey<FormState>();

  final String apiUrl = "https://bulk.srivagroups.in/api/bulk-orders";

  late TextEditingController name;
  late TextEditingController mobile;
  late TextEditingController email;
  late TextEditingController company;
  late TextEditingController link;
  late TextEditingController product;
  late TextEditingController quantity;
  late TextEditingController instructions;
  late TextEditingController refFile;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        refFile.text = image.path;
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
        refFile.text = result.files.single.path!;
      });
    }
  }

  late bool callback;
  late bool sms;
  late bool whatsapp;
  late bool mail;

  @override
  void initState() {
    super.initState();

    name = TextEditingController(text: widget.data["name"]);
    mobile = TextEditingController(text: widget.data["mobile"]);
    email = TextEditingController(text: widget.data["email"]);
    company = TextEditingController(text: widget.data["company"]);
    link = TextEditingController(text: widget.data["link"]);
    product = TextEditingController(text: widget.data["product"]);
    quantity = TextEditingController(text: widget.data["quantity"].toString());
    instructions = TextEditingController(
      text: widget.data["specialInstructions"],
    );
    refFile = TextEditingController(text: widget.data["bulkOrderRefFile"]);

    callback = widget.data["contact_Callback"] ?? false;
    sms = widget.data["contact_SMS"] ?? false;
    whatsapp = widget.data["contact_WhatsApp"] ?? false;
    mail = widget.data["contact_Mail"] ?? false;
  }

  Future<void> updateOrder() async {
    if (!_formKey.currentState!.validate()) return;

    String formattedLink = link.text.trim().replaceAll(' ', '');
    if (formattedLink.isNotEmpty &&
        !formattedLink.startsWith('http://') &&
        !formattedLink.startsWith('https://')) {
      formattedLink = 'https://$formattedLink';
    }

    final body = {
      "id": widget.data["bulkOrderID"],
      "name": name.text,
      "mobile": mobile.text,
      "email": email.text,
      "company": company.text,
      "link": formattedLink,
      "product": product.text,
      "product_name": product.text,
      "product_title": product.text.isNotEmpty ? product.text : "Bulk Order Inquiry",
      "current_url": formattedLink.isNotEmpty ? formattedLink : "https://bulk.srivagroups.in",
      "quantity": int.parse(quantity.text),
      "special_instructions": instructions.text,
      "contact": callback,
      "contact_sms": sms,
      "contact_whatsapp": whatsapp,
      "contact_mail": mail,
      "contact_methods": [
        if (callback) "Callback",
        if (sms) "SMS",
        if (whatsapp) "WhatsApp",
        if (mail) "Mail",
      ].join(", "),
      "bulk_order_pdf": refFile.text,
    };

    final res = await ApiDebugLogger.httpClient.put(
      Uri.parse("$apiUrl/${widget.data["bulkOrderID"]}"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
        title: Text("Edit Bulk Order"),
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
                  field("Website", Icons.link, link),
                  field("Product", Icons.inventory, product),
                  field(
                    "Quantity",
                    Icons.numbers,
                    quantity,
                    keyboard: TextInputType.number,
                  ),
                  field(
                    "Special Instructions",
                    Icons.notes,
                    instructions,
                    maxLines: 3,
                  ),
                  field("Reference File", Icons.attach_file, refFile),

                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Preferred Contact:",
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

                  SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: updateOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3B5BDB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 6,
                      ),
                      child: Text(
                        "UPDATE ORDER",
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
