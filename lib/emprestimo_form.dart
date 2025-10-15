import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import 'parcelas_page.dart';
import 'package:flutter/services.dart';

class EmprestimoForm extends StatefulWidget {
  final String idCliente;
  final String? idUsuario;
  final VoidCallback onSaved;

  const EmprestimoForm({
    super.key,
    required this.idCliente,
    this.idUsuario,
    required this.onSaved,
  });

  @override
  State<EmprestimoForm> createState() => _EmprestimoFormState();
}

class _EmprestimoFormState extends State<EmprestimoForm> {
  final _formKey = GlobalKey<FormState>();

  final capitalCtrl = TextEditingController();
  final mesesCtrl = TextEditingController();
  final taxaCtrl = TextEditingController();
  final jurosCtrl = TextEditingController();
  List<Map<String, dynamic>> parcelasPreview = [];

  String? resumo;
  double? prestacao;
  double? totalJuros;

  DateTime dataEmprestimo = DateTime.now();

  TextInputFormatter _moedaFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (text.isEmpty) return newValue;
      final value = int.parse(text) / 100;
      final formatted = _formatarMoeda(value);
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
  }

  String _formatarMoeda(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final real = parts[0];
    final centavos = parts[1];
    String realFormatado = '';
    for (int i = real.length - 1, j = 0; i >= 0; i--, j++) {
      if (j > 0 && j % 3 == 0) {
        realFormatado = '.$realFormatado';
      }
      realFormatado = real[i] + realFormatado;
    }
    return 'R\$ $realFormatado,$centavos';
  }

  double _parseMoeda(String texto) {
    if (texto.isEmpty) return 0.0;
    final cleaned = texto
        .replaceAll('R\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  void simular() {
    final capital = _parseMoeda(capitalCtrl.text);
    final meses = int.tryParse(mesesCtrl.text) ?? 0;
    final taxa = double.tryParse(taxaCtrl.text.replaceAll(',', '.')) ?? 0;
    final jurosInformado = _parseMoeda(jurosCtrl.text);

    if (capital <= 0 || meses <= 0) {
      setState(() => resumo = "Preencha capital e meses.");
      return;
    }
    if (taxa > 0 && jurosInformado > 0) {
      setState(() => resumo = "Preencha apenas Taxa ou Juros, não os dois.");
      return;
    }

    double p = 0;
    double totalPago = 0;
    double jurosTotal = 0;

    if (taxa > 0) {
      final t = taxa / 100;
      p = (capital * t) / (1 - pow(1 + t, -meses).toDouble());
      totalPago = p * meses;
      jurosTotal = totalPago - capital;
    } else if (jurosInformado > 0) {
      jurosTotal = jurosInformado;
      totalPago = capital + jurosTotal;
      p = totalPago / meses;
    }

    setState(() {
      prestacao = p;
      totalJuros = jurosTotal;

      String taxaFmt = "";
      if (taxa > 0) {
        taxaFmt = "${taxa.toStringAsFixed(2)}% a.m";
      } else {
        double melhorDif = double.infinity;
        double taxaCalc = 0;
        for (double t = 0.0001; t < 1; t += 0.0001) {
          double pCalc = (capital * t) / (1 - pow(1 + t, -meses).toDouble());
          double dif = (pCalc - p).abs();
          if (dif < melhorDif) {
            melhorDif = dif;
            taxaCalc = t;
          }
        }
        taxaFmt = "${(taxaCalc * 100).toStringAsFixed(2)}% a.m";
      }

      resumo =
          "O total desse financiamento de $meses parcelas de ${fmtMoeda(p)} "
          "é ${fmtMoeda(totalPago)}, sendo ${fmtMoeda(jurosTotal)} de juros.\n"
          "Taxa aproximada: $taxaFmt";

      parcelasPreview.clear();
      final diaRef = dataEmprestimo.day;
      for (int i = 1; i <= meses; i++) {
        int ano = dataEmprestimo.year;
        int mes = dataEmprestimo.month + i;
        while (mes > 12) {
          mes -= 12;
          ano += 1;
        }
        int ultimoDiaMes = DateTime(ano, mes + 1, 0).day;
        int dia = diaRef <= ultimoDiaMes ? diaRef : 1;
        DateTime vencimento = DateTime(ano, mes, dia);

        parcelasPreview.add({
          "numero": i,
          "valor": p,
          "vencimento":
              "${vencimento.day.toString().padLeft(2, '0')}/${vencimento.month.toString().padLeft(2, '0')}/${vencimento.year}"
        });
      }
    });
  }

  Future<void> salvar() async {
    if (prestacao == null || totalJuros == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Faça a simulação primeiro!")),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final uuid = Uuid();
    final emprestimoId = uuid.v4();

    final userId = Supabase.instance.client.auth.currentUser!.id;

    final dataStr =
        "${dataEmprestimo.year}-${dataEmprestimo.month.toString().padLeft(2, '0')}-${dataEmprestimo.day.toString().padLeft(2, '0')}";

    final capital = _parseMoeda(capitalCtrl.text);
    final meses = int.tryParse(mesesCtrl.text) ?? 1;
    final prestacaoFinal = ((capital + (totalJuros ?? 0)) / meses);

    await supabase.from('emprestimos').insert({
      'id': emprestimoId,
      'id_cliente': widget.idCliente,
      'valor': double.parse(capital.toStringAsFixed(2)),
      'data_inicio': dataStr,
      'parcelas': meses,
      'juros': double.parse((totalJuros ?? 0).toStringAsFixed(2)),
      'prestacao': double.parse(prestacaoFinal.toStringAsFixed(2)),
      'id_usuario': userId,
      'ativo': 'sim',
    });

    final dataInicio = dataEmprestimo;
    final diaRef = dataInicio.day;
    final List<Map<String, dynamic>> parcelas = [];
    for (int i = 1; i <= meses; i++) {
      int ano = dataInicio.year;
      int mes = dataInicio.month + i;
      while (mes > 12) {
        mes -= 12;
        ano += 1;
      }
      int ultimoDiaMes = DateTime(ano, mes + 1, 0).day;
      int dia = diaRef <= ultimoDiaMes ? diaRef : 1;
      DateTime vencimento = DateTime(ano, mes, dia);
      final parcelaId = uuid.v4();

      parcelas.add({
        'id': parcelaId,
        'id_emprestimo': emprestimoId,
        'numero': i,
        'valor': double.parse(prestacaoFinal.toStringAsFixed(2)),
        'vencimento':
            "${vencimento.year}-${vencimento.month.toString().padLeft(2, '0')}-${vencimento.day.toString().padLeft(2, '0')}",
        'juros': 0.0,
        'desconto': 0.0,
        'pg_principal': 0.0,
        'pg_juros': 0.0,
        'valor_pago': 0.0,
        'residual': double.parse(prestacaoFinal.toStringAsFixed(2)),
        'data_pagamento': null,
        'id_usuario': userId,
        'data_prevista': null,
        'comentario': "",
      });
    }

    await supabase.from('parcelas').insert(parcelas);

    // ✅ Consulta corrigida: usa id_cliente
    final clienteResp = await supabase
        .from('clientes')
        .select('nome')
        .eq('id_cliente', widget.idCliente) // 🔹 CORRIGIDO
        .maybeSingle();

    final nomeCliente = clienteResp != null && clienteResp['nome'] != null
        ? clienteResp['nome'] as String
        : 'Cliente';

    final emprestimo = {
      "id": emprestimoId,
      "id_cliente": widget.idCliente,
      "valor": capital,
      "data_inicio": dataStr,
      "parcelas": meses,
      "juros": totalJuros ?? 0,
      "prestacao": prestacaoFinal,
      "id_usuario": userId,
      "ativo": "sim",
      "cliente": nomeCliente,
    };

    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParcelasPage(
          emprestimo: emprestimo,
          onSaved: widget.onSaved,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Novo Empréstimo")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: capitalCtrl,
                      decoration:
                          const InputDecoration(labelText: "Valor financiado"),
                      keyboardType: TextInputType.number,
                      inputFormatters: [_moedaFormatter()],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: mesesCtrl,
                      decoration: const InputDecoration(labelText: "Meses"),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: taxaCtrl,
                      decoration: const InputDecoration(labelText: "Taxa mensal (% a.m)"),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: jurosCtrl,
                      decoration: const InputDecoration(labelText: "Total de Juros"),
                      keyboardType: TextInputType.number,
                      inputFormatters: [_moedaFormatter()],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: simular,
                      child: const Text("📊 Simular Empréstimo"),
                    ),
                    if (resumo != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        resumo!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: salvar,
                      icon: const Icon(Icons.save),
                      label: const Text("Criar Empréstimo"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 20),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (parcelasPreview.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        "Prévia das Parcelas:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: parcelasPreview.map((parc) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Parcela ${parc['numero']}"),
                                Text(fmtMoeda(double.tryParse(parc['valor'].toString()) ?? 0)),
                                Text(parc['vencimento']),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
