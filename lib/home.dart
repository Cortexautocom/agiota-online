import 'package:flutter/material.dart';
import 'clientes_page.dart';
import 'arquivados_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const ClientesPage(),
    const Center(child: Text("📊 Relatórios", style: TextStyle(color: Colors.white))),
    const ArquivadosPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Agiota Online")),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1c2331),
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF2c3446)),
              child: Text("Menu", style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
            ListTile(
              leading: const Icon(Icons.people, color: Colors.white),
              title: const Text("Clientes", style: TextStyle(color: Colors.white)),
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.white),
              title: const Text("Relatórios", style: TextStyle(color: Colors.white)),
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive, color: Colors.white),
              title: const Text("Arquivados", style: TextStyle(color: Colors.white)),
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFF1c2331),
        child: _pages[_selectedIndex],
      ),
    );
  }
}