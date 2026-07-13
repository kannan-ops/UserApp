import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:enquiry_app/utils/api_debug_logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class AddGets extends StatefulWidget {
  const AddGets({super.key});

  @override
  State<AddGets> createState() => _AddGetsState();
}

class _AddGetsState extends State<AddGets> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final emailController = TextEditingController();
  final mrpController = TextEditingController();
  final priceController = TextEditingController();
  final quantityController = TextEditingController();
  final titleController = TextEditingController();
  final currentUrlController = TextEditingController();

  final String apiUrl = "https://bulk.srivagroups.in/api/product";

  Future<void> postGets() async {
    if (!_formKey.currentState!.validate()) return;

    final mrpVal = double.tryParse(mrpController.text) ?? 0.0;
    final priceVal = double.tryParse(priceController.text) ?? 0.0;
    final qtyVal = int.tryParse(quantityController.text) ?? 0;

    final body = {
      "name": nameController.text.trim(),
      "mobile": mobileController.text.trim(),
      "email": emailController.text.trim(),
      "mrp": mrpVal,
      "price": priceVal,
      "quantity": qtyVal,
      "total_price": priceVal * qtyVal,
      "title": titleController.text.trim().isNotEmpty ? titleController.text.trim() : "Sector Inquiry",
      "current_url": currentUrlController.text.trim().isNotEmpty ? currentUrlController.text.trim() : "https://bulk.srivagroups.in",
    };

    final res = await ApiDebugLogger.httpClient.post(
      Uri.parse(apiUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Data Inserted Successfully"),
          backgroundColor: Colors.green,
        ),
      );

      _formKey.currentState!.reset();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res.body)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Gets"),
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
                    "Product Title",
                    Icons.shopping_bag,
                    titleController,
                    validator: (v) => v!.isEmpty ? "Product title required" : null,
                  ),

                  field(
                    "Name",
                    Icons.person,
                    nameController,
                    validator: (v) => v!.isEmpty ? "Name required" : null,
                  ),

                  field(
                    "Mobile",
                    Icons.phone,
                    mobileController,
                    keyboard: TextInputType.phone,
                    validator: (v) =>
                        v!.length < 10 ? "Enter valid mobile number" : null,
                  ),

                  field(
                    "Email",
                    Icons.email,
                    emailController,
                    keyboard: TextInputType.emailAddress,
                    validator: (v) =>
                        !v!.contains("@") ? "Enter valid email" : null,
                  ),

                  field(
                    "MRP",
                    Icons.currency_rupee,
                    mrpController,
                    keyboard: TextInputType.number,
                    validator: (v) =>
                        int.tryParse(v!) == null ? "Enter valid MRP" : null,
                  ),

                  field(
                    "Price",
                    Icons.sell,
                    priceController,
                    keyboard: TextInputType.number,
                    validator: (v) =>
                        int.tryParse(v!) == null ? "Enter valid price" : null,
                  ),

                  field(
                    "Quantity",
                    Icons.numbers,
                    quantityController,
                    keyboard: TextInputType.number,
                    validator: (v) => int.tryParse(v!) == null
                        ? "Enter valid quantity"
                        : null,
                  ),

                  field(
                    "Product/Website Link",
                    Icons.link,
                    currentUrlController,
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: postGets,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3B5BDB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 6,
                      ),
                      child: Text(
                        "SAVE",
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
