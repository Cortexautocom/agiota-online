import 'package:flutter/material.dart';

class ParcelasPage extends StatelessWidget {
  final Map<String, dynamic> emprestimo;

  const ParcelasPage({super.key, required this.emprestimo});

  @override
  Widget build(BuildContext context) {
    final parcelas = emprestimo['parcelas'] ?? []; // lista de parcelas

    return Scaffold(
      appBar: AppBar(
        title: Text("Parcelas - ${emprestimo['cliente'] ?? ''}"),        
      ),
      body: Container(
        color: const Color(0xFF1c2331),
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: parcelas.length,
          itemBuilder: (context, index) {
            final p = parcelas[index];
            return Card(
              color: const Color(0xFF2c3446),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                title: Text("Parcela ${p['numero']}",
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  "Vencimento: ${p['vencimento']}  |  Valor: ${p['valor']}",
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: Text(
                  p['status'] ?? '',
                  style: TextStyle(
                    color: p['status'] == "Pago"
                        ? Colors.green
                        : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
