import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:enquiry_app/utils/api_debug_logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class BulkOrderPage extends StatefulWidget {
  const BulkOrderPage({super.key});

  @override
  State<BulkOrderPage> createState() => _BulkOrderPageState();
}

class _BulkOrderPageState extends State<BulkOrderPage>
    with SingleTickerProviderStateMixin {
  final String apiUrl = "https://bulk.srivagroups.in/api/bulk-orders";

  final name = TextEditingController();
  final mobile = TextEditingController();
  final email = TextEditingController();
  final company = TextEditingController();
  final link = TextEditingController();
  final product = TextEditingController();
  final quantity = TextEditingController();
  final instructions = TextEditingController();
  final file = TextEditingController();
  final productTitle = TextEditingController();
  final currentUrl = TextEditingController();
  final preferredDeliveryDate = TextEditingController();

  Future<void> _selectDeliveryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        preferredDeliveryDate.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _showFileSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Pick Image'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Pick PDF Document'),
              onTap: () {
                Navigator.pop(context);
                _pickPDF();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        file.text = image.path;
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
        file.text = result.files.single.path!;
      });
    }
  }

  bool callback = false;
  bool sms = false;
  bool whatsapp = false;
  bool mail = false;

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 550),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: Offset(0, .1),
      end: Offset.zero,
    ).animate(_fade);
    _controller.forward();
  }

  Future<void> postBulkOrder() async {
    String formattedLink = link.text.trim().replaceAll(' ', '');
    if (formattedLink.isNotEmpty &&
        !formattedLink.startsWith('http://') &&
        !formattedLink.startsWith('https://')) {
      formattedLink = 'https://$formattedLink';
    }

    String formattedCurrentUrl = currentUrl.text.trim().replaceAll(' ', '');
    if (formattedCurrentUrl.isNotEmpty &&
        !formattedCurrentUrl.startsWith('http://') &&
        !formattedCurrentUrl.startsWith('https://')) {
      formattedCurrentUrl = 'https://$formattedCurrentUrl';
    }

    final body = {
      "name": name.text,
      "mobile": mobile.text,
      "email": email.text,
      "company": company.text,
      "link": formattedLink,
      "product": product.text,
      "product_name": product.text,
      "product_title": productTitle.text.trim().isNotEmpty ? productTitle.text.trim() : (product.text.isNotEmpty ? product.text : "Bulk Order Inquiry"),
      "current_url": formattedCurrentUrl.isNotEmpty ? formattedCurrentUrl : (formattedLink.isNotEmpty ? formattedLink : "https://bulk.srivagroups.in"),
      "quantity": int.tryParse(quantity.text) ?? 0,
      "special_instructions": instructions.text,
      "preferred_delivery_date": preferredDeliveryDate.text,
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
      "bulk_order_pdf": file.text,
    };

    final res = await ApiDebugLogger.httpClient.post(
      Uri.parse(apiUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Order Created Successfully"),
          backgroundColor: Colors.green,
        ),
      );
      name.clear();
      mobile.clear();
      email.clear();
      company.clear();
      link.clear();
      product.clear();
      quantity.clear();
      instructions.clear();
      file.clear();
      productTitle.clear();
      currentUrl.clear();
      preferredDeliveryDate.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Creation Failed: ${res.body}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEFF3FF), Color(0xFFF8FAFF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bulk Order",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .5,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Create a new bulk order request",
                      style: TextStyle(color: Colors.black54, fontSize: 15),
                    ),

                    SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Color(0xFFFDFDFF),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1A3B5BDB),
                            blurRadius: 30,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          field("Product Title", Icons.shopping_bag, productTitle),
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
                          field("Current URL", Icons.link, currentUrl),
                          field("Product", Icons.inventory, product),
                          field(
                            "Quantity",
                            Icons.numbers,
                            quantity,
                            keyboard: TextInputType.number,
                          ),
                          field(
                            "Preferred Delivery Date",
                            Icons.calendar_month,
                            preferredDeliveryDate,
                            readOnly: true,
                            onTap: () => _selectDeliveryDate(context),
                          ),
                          field("Instructions", Icons.notes, instructions),
                          field(
                            "Reference File",
                            Icons.attach_file,
                            file,
                            readOnly: true,
                            onTap: _showFileSourceDialog,
                          ),

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
                              onPressed: postBulkOrder,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF3B5BDB),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 6,
                              ),
                              child: Text(
                                "Save Order",
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
                  ],
                ),
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
    TextEditingController c, {
    TextInputType keyboard = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboard,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
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
