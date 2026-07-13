import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:enquiry_app/utils/api_debug_logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class EditPage extends StatefulWidget {
  final Map data;
  const EditPage({super.key, required this.data});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController name;
  late TextEditingController mobile;
  late TextEditingController email;
  late TextEditingController price;
  late TextEditingController quantity;

  final String apiUrl = "https://bulk.srivagroups.in/api/product";

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.data["name"]);
    mobile = TextEditingController(text: widget.data["mobile"]);
    email = TextEditingController(text: widget.data["email"]);
    price = TextEditingController(text: widget.data["price"].toString());
    quantity = TextEditingController(text: widget.data["quantity"].toString());
  }

  Future<void> updateData() async {
    if (!_formKey.currentState!.validate()) return;

    final priceVal = double.tryParse(price.text) ?? 0.0;
    final qtyVal = int.tryParse(quantity.text) ?? 0;
    final mrpVal =
        double.tryParse(widget.data["mrp"]?.toString() ?? "") ?? priceVal;

    final res = await ApiDebugLogger.httpClient.put(
      Uri.parse("$apiUrl/${widget.data["id"]}"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "id": widget.data["id"],
        "name": name.text,
        "mobile": mobile.text,
        "email": email.text,
        "mrp": mrpVal,
        "price": priceVal,
        "quantity": qtyVal,
        "total_price": priceVal * qtyVal,
        "title": name.text.trim().isNotEmpty ? name.text.trim() : "Sector Inquiry",
        "current_url": "https://bulk.srivagroups.in",
      }),
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
        title: Text("Edit Product"),
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
                  field(
                    "Name",
                    Icons.person,
                    name,
                    validator: (v) => v!.isEmpty ? "Name required" : null,
                  ),

                  field(
                    "Mobile",
                    Icons.phone,
                    mobile,
                    keyboard: TextInputType.phone,
                    validator: (v) =>
                        v!.length < 10 ? "Enter valid mobile number" : null,
                  ),

                  field(
                    "Email",
                    Icons.email,
                    email,
                    keyboard: TextInputType.emailAddress,
                    validator: (v) =>
                        !v!.contains("@") ? "Enter valid email" : null,
                  ),

                  field(
                    "Price",
                    Icons.sell,
                    price,
                    keyboard: TextInputType.number,
                    validator: (v) => double.tryParse(v!) == null
                        ? "Enter valid price"
                        : null,
                  ),

                  field(
                    "Quantity",
                    Icons.numbers,
                    quantity,
                    keyboard: TextInputType.number,
                    validator: (v) => int.tryParse(v!) == null
                        ? "Enter valid quantity"
                        : null,
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: updateData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3B5BDB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 6,
                      ),
                      child: Text(
                        "UPDATE",
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
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        validator: validator,
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
}
