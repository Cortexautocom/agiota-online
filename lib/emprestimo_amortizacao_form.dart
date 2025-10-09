import 'package:flutter/material.dart';

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
      body: const Center(
        child: Text(
          "🧮 Tela de Amortização (em desenvolvimento)",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
