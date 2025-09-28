import 'package:flutter/material.dart';
import 'parcelas.dart'; // 🔹 importa a tela de parcelas

class FinanceiroPage extends StatelessWidget {
  final Map<String, dynamic> cliente;

  const FinanceiroPage({super.key, required this.cliente});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Financeiro - ${cliente['nome']}"),        
      ),
      body: Container(
        color: const Color(0xFF1c2331),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 🔹 Empréstimos (abre direto a tela de parcelas por enquanto)
            ElevatedButton.icon(
              onPressed: () {
                final emprestimoFake = {
                  "cliente": cliente['nome'],
                  "parcelas": [
                    {
                      "numero": 1,
                      "vencimento": "10/10/2025",
                      "valor": "R\$ 500,00",
                      "status": "Pago"
                    },
                    {
                      "numero": 2,
                      "vencimento": "10/11/2025",
                      "valor": "R\$ 500,00",
                      "status": "Em aberto"
                    },
                    {
                      "numero": 3,
                      "vencimento": "10/12/2025",
                      "valor": "R\$ 500,00",
                      "status": "Em aberto"
                    },
                  ]
                };

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ParcelasPage(emprestimo: emprestimoFake),
                  ),
                );
              },
              icon: const Icon(Icons.attach_money),
              label: const Text("Empréstimos / Parcelas"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // 🔹 Garantias
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Garantias ainda não implementado")),
                );
              },
              icon: const Icon(Icons.account_balance),
              label: const Text("Garantias"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // 🔹 Arquivados
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Arquivados ainda não implementado")),
                );
              },
              icon: const Icon(Icons.archive),
              label: const Text("Arquivados"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
