import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nameController = TextEditingController();
  String _savedName = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    setState(() {
      _savedName = name;
      _nameController.text = name;
      _loading = false;
    });
  }

  Future<void> _saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    setState(() => _savedName = name);
  }

  void _callBen() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tell Ben your name first')),
      );
      return;
    }
    await _saveName(name);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CallScreen(userName: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF111111),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4ADE80))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Avatar
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 2),
                ),
                child: const Center(
                  child: Text('B', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w500, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),

              const Text('Ben',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w500, color: Colors.white, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text('Your AI friend. Always here.',
                style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.4))),

              const Spacer(flex: 2),

              if (_savedName.isEmpty) ...[
                Text('What should Ben call you?',
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5))),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Your name',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                Text('Hey $_savedName 👋',
                  style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text('Ben is ready to talk',
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.4))),
                const SizedBox(height: 20),
              ],

              // Call button
              GestureDetector(
                onTap: _callBen,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.call, color: Color(0xFF0A1F13), size: 22),
                      SizedBox(width: 10),
                      Text('Call Ben',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: Color(0xFF0A1F13))),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (_savedName.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _savedName = ''),
                  child: Text('Not $_savedName? Change name',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.3),
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withOpacity(0.3),
                    )),
                ),

              const Spacer(),

              Text('Built by BrytMa Tech Uganda',
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.2))),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
