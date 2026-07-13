import 'package:flutter/material.dart';
import '../chartfile/getbulk.dart';
import '../chartfile/getenq.dart';
import '../chartfile/getsector.dart';
import '../chartfile/postbulk.dart';
import '../chartfile/postenq.dart';
import '../chartfile/postsector.dart';
import '../chatnew/admin.dart';
import '../chatnew/bussiness.dart';
import '../chatnew/user.dart';
import '../screens/login_screen.dart';
import 'chat_threads_screen.dart';

class Dash extends StatefulWidget {
  final String userName;

  const Dash({super.key, required this.userName});

  @override
  State<Dash> createState() => _DashState();
}

class _DashState extends State<Dash> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1F3B),

      appBar: AppBar(
        backgroundColor: const Color(0xFF2C003E),
        elevation: 0,
        title: const Text(
          "CirCuiT PoInT",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, size: 28, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.pinkAccent,
              child: Text(
                widget.userName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),

      drawer: Drawer(
        backgroundColor: Color(0xFF2C003E),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.pinkAccent, Colors.orangeAccent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 35, color: Colors.black),
                  ),
                  SizedBox(height: 15),
                  Text(
                    "WELCOME",
                    style: TextStyle(color: Colors.white70, letterSpacing: 2),
                  ),
                  Text(
                    widget.userName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 10),

            ExpansionTile(
              iconColor: Colors.white,
              collapsedIconColor: Colors.white,
              leading: Icon(Icons.inventory, color: Colors.white),
              title: Text("Bulk Order", style: TextStyle(color: Colors.white)),
              children: [
                ListTile(
                  title: Text(
                    "Add Bulk Order",
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BulkOrderPage()),
                    );
                  },
                ),
                ListTile(
                  title: Text(
                    "View Bulk Order",
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => getbuk()),
                    );
                  },
                ),
              ],
            ),

            ExpansionTile(
              iconColor: Colors.white,
              collapsedIconColor: Colors.white,
              leading: Icon(Icons.question_answer, color: Colors.white),
              title: Text("Enquiry", style: TextStyle(color: Colors.white)),
              children: [
                ListTile(
                  title: Text(
                    "Add Enquiry Order",
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EnquiryPage()),
                    );
                  },
                ),
                ListTile(
                  title: Text(
                    "View Enquiry Order",
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GetEnquiry()),
                    );
                  },
                ),
              ],
            ),

            ExpansionTile(
              iconColor: Colors.white,
              collapsedIconColor: Colors.white,
              leading: const Icon(Icons.business, color: Colors.white),
              title: const Text(
                "Sector",
                style: TextStyle(color: Colors.white),
              ),
              children: [
                ListTile(
                  title: const Text(
                    "Add Sector",
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddGets()),
                    );
                  },
                ),
                ListTile(
                  title: const Text(
                    "View Sector",
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GetById()),
                    );
                  },
                ),
              ],
            ),

            ListTile(
              leading: const Icon(Icons.chat, color: Colors.white),
              title: const Text(
                "Client Chats",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatThreadsScreen()),
                );
              },
            ),

            const Divider(color: Colors.white24),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                "Logout",
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 220,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => UserPage(userId: 1)),
                  );
                },
                child: const Text(
                  "User",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: 220,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BusinessPage(businessId: 2),
                    ),
                  );
                },
                child: const Text(
                  "BusinessMan",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: 220,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightGreenAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AdminPage(adminId: 3)),
                  );
                },
                child: const Text(
                  "Admin",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: 220,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B5BDB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatThreadsScreen()),
                  );
                },
                icon: const Icon(Icons.chat, color: Colors.white),
                label: const Text(
                  "Client Chats",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(
    BuildContext context, {
    required String text,
    required Color color,
    required Widget page,
  }) {
    return SizedBox(
      width: 220,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
