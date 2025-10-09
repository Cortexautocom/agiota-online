import 'package:flutter/material.dart';
import 'amortizacao_tabela.dart';

class EmprestimoAmortizacaoForm extends StatefulWidget {
  final String idCliente;
  final String? idUsuario;
  final VoidCallback onSaved;

  const EmprestimoAmortizacaoForm({
    super.key,
    required this.idCliente,
    this.idUsuario,
    required this.onSaved,
  });

  @override
  State<EmprestimoAmortizacaoForm> createState() =>
      _EmprestimoAmortizacaoFormState();
}

class _EmprestimoAmortizacaoFormState extends State<EmprestimoAmortizacaoForm> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Novo Empréstimo - Amortização"),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.arrow_forward),
          label: const Text("Avançar para Conta-Corrente"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () {
            // 🔹 Aqui futuramente virão os dados reais do Supabase
            final emprestimo = {
              'id': DateTime.now().millisecondsSinceEpoch, // temporário
              'cliente': 'Cliente Exemplo',
            };

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AmortizacaoTabela(emprestimo: emprestimo),
              ),
            );
          },
        ),
      ),
    );
  }
}
