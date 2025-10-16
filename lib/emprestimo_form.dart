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
  final parcelaCtrl = TextEditingController();

  final FocusNode taxaFocus = FocusNode();
  final FocusNode parcelaFocus = FocusNode();

  String? nomeCliente;
  double? prestacao;
  double? totalJuros;
  double? taxaFinal;
  int? qtdParcelas;
  double? capital;
  double? totalComJuros;

  DateTime dataEmprestimo = DateTime.now();

  @override
  void initState() {
    super.initState();
    _carregarNomeCliente();

    // 🔹 Limpa campo oposto ao digitar
    taxaCtrl.addListener(() {
      if (taxaFocus.hasFocus && taxaCtrl.text.isNotEmpty) parcelaCtrl.text = '';
    });
    parcelaCtrl.addListener(() {
      if (parcelaFocus.hasFocus && parcelaCtrl.text.isNotEmpty) taxaCtrl.text = '';
    });
  }

  @override
  void dispose() {
    capitalCtrl.dispose();
    mesesCtrl.dispose();
    taxaCtrl.dispose();
    parcelaCtrl.dispose();
    taxaFocus.dispose();
    parcelaFocus.dispose();
    super.dispose();
  }

  Future<void> _carregarNomeCliente() async {
    final supabase = Supabase.instance.client;
    final resp = await supabase
        .from('clientes')
        .select('nome')
        .eq('id_cliente', widget.idCliente)
        .maybeSingle();

    setState(() {
      nomeCliente = resp?['nome'] ?? 'Cliente';
    });
  }

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
      if (j > 0 && j % 3 == 0) realFormatado = '.$realFormatado';
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

  double _calcularTaxaMensal(double capital, int meses, double parcela) {
    double melhorDif = double.infinity;
    double taxaCalc = 0;
    for (double t = 0.0001; t < 1; t += 0.0001) {
      double pCalc = (capital * t) / (1 - pow(1 + t, -meses).toDouble());
      double dif = (pCalc - parcela).abs();
      if (dif < melhorDif) {
        melhorDif = dif;
        taxaCalc = t;
      }
    }
    return taxaCalc * 100;
  }

  void _simular() {
    final cap = _parseMoeda(capitalCtrl.text);
    final meses = int.tryParse(mesesCtrl.text) ?? 0;
    final taxaDigitada =
        double.tryParse(taxaCtrl.text.replaceAll(',', '.')) ?? 0;
    final parcelaDigitada = _parseMoeda(parcelaCtrl.text);

    if (cap <= 0 || meses <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha capital e número de meses.")),
      );
      return;
    }

    // 🔹 Se taxa e parcela preenchidas → prioriza taxa
    if (taxaDigitada > 0 && parcelaDigitada > 0) {
      parcelaCtrl.text = '';
    }

    double p = 0;
    double jurosTotal = 0;
    double taxaUsada = 0;

    if (taxaDigitada > 0 && parcelaDigitada == 0) {
      final t = taxaDigitada / 100;
      p = (cap * t) / (1 - pow(1 + t, -meses).toDouble());
      jurosTotal = (p * meses) - cap;
      taxaUsada = taxaDigitada;
      parcelaCtrl.text = _formatarMoeda(p);
    } else if (parcelaDigitada > 0 && taxaDigitada == 0) {
      final taxaAprox = _calcularTaxaMensal(cap, meses, parcelaDigitada);
      taxaUsada = taxaAprox;
      p = parcelaDigitada;
      jurosTotal = (p * meses) - cap;
      taxaCtrl.text = taxaAprox.toStringAsFixed(2);
    } else if (taxaDigitada == 0 && parcelaDigitada == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Informe taxa ou valor da parcela.")),
      );
      return;
    }

    setState(() {
      capital = cap;
      prestacao = p;
      totalJuros = jurosTotal;
      taxaFinal = taxaUsada;
      totalComJuros = cap + jurosTotal;
      qtdParcelas = meses;
    });
  }

  Future<void> salvar() async {
    if (prestacao == null || totalJuros == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Preencha os campos e simule antes de salvar!")),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final uuid = Uuid();
    final emprestimoId = uuid.v4();
    final userId = Supabase.instance.client.auth.currentUser!.id;

    final dataStr =
        "${dataEmprestimo.year}-${dataEmprestimo.month.toString().padLeft(2, '0')}-${dataEmprestimo.day.toString().padLeft(2, '0')}";

    final cap = double.parse((capital ?? 0).toStringAsFixed(2));
    final meses = qtdParcelas ?? 1;
    final jurosReais = double.parse((totalJuros ?? 0).toStringAsFixed(2));
    final prestacaoFinal = double.parse((prestacao ?? 0).toStringAsFixed(2));
    final taxaMensal = double.parse((taxaFinal ?? 0).toStringAsFixed(4));

    // 🔹 Inserir o empréstimo
    // 🔹 Inserir o empréstimo e retornar o número gerado pelo banco
    final insertResp = await supabase
        .from('emprestimos')
        .insert({
          'id': emprestimoId,
          'id_cliente': widget.idCliente,
          'valor': cap,
          'data_inicio': dataStr,
          'parcelas': meses,
          'juros': jurosReais,
          'prestacao': prestacaoFinal,
          'taxa': taxaMensal,
          'id_usuario': userId,
          'ativo': 'sim',
        })
        .select('numero')
        .maybeSingle();

    // ✅ Captura o número do empréstimo gerado pelo trigger
    final numeroEmprestimo = insertResp?['numero'] ?? 0;


    // ✅ 🔹 GERAR PARCELAS AUTOMATICAMENTE (compatível com schema)
    final List<Map<String, dynamic>> parcelas = [];
    for (int i = 1; i <= meses; i++) {
      final vencimento = DateTime(
        dataEmprestimo.year,
        dataEmprestimo.month + i,
        dataEmprestimo.day,
      );

      parcelas.add({
        'id_emprestimo': emprestimoId,
        'numero': i,
        'valor': prestacaoFinal,
        'vencimento':
            "${vencimento.year}-${vencimento.month.toString().padLeft(2, '0')}-${vencimento.day.toString().padLeft(2, '0')}",
        'juros': 0.0,
        'desconto': 0.0,
        'pg_principal': 0.0,
        'pg_juros': 0.0,
        'valor_pago': 0.0,
        'residual': prestacaoFinal,
        'data_pagamento': null,
        'id_usuario': userId,
      });
    }

    await supabase.from('parcelas').insert(parcelas);

    // 🔹 Abre a tela de parcelas
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParcelasPage(
          emprestimo: {
            "id": emprestimoId,
            "id_cliente": widget.idCliente,
            "valor": cap,
            "data_inicio": dataStr,
            "parcelas": meses,
            "juros": jurosReais,
            "prestacao": prestacaoFinal,
            "taxa": taxaMensal,
            "id_usuario": userId,
            "ativo": "sim",
            "cliente": nomeCliente ?? 'Cliente',
            "numero": numeroEmprestimo, // ✅ agora o número vai para a tela de parcelas
          },
          onSaved: widget.onSaved,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Novo empréstimo - ${nomeCliente ?? ''}"),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey[100],
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 FORMULÁRIO
            Container(
              width: 300,
              height: 600,
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: capitalCtrl,
                        decoration: const InputDecoration(labelText: "Valor financiado"),
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
                        focusNode: taxaFocus,
                        controller: taxaCtrl,
                        decoration: const InputDecoration(labelText: "Taxa mensal (% a.m)"),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        focusNode: parcelaFocus,
                        controller: parcelaCtrl,
                        decoration: const InputDecoration(labelText: "Valor da parcela"),
                        keyboardType: TextInputType.number,
                        inputFormatters: [_moedaFormatter()],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _simular,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text("📊 Simular Empréstimo"),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: salvar,
                          icon: const Icon(Icons.save),
                          label: const Text("Criar Empréstimo"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 40),

            // 🔹 CARD DE INFORMAÇÕES
            Container(
              width: 260,
              height: 370,
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Novo empréstimo",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(nomeCliente ?? "Cliente",
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Divider(),
                    Text("Valor financiado: ${fmtMoeda(totalComJuros ?? 0)}",
                        style: const TextStyle(fontSize: 12)),
                    Text("Taxa aplicada: ${(taxaFinal ?? 0).toStringAsFixed(2)}% a.m",
                        style: const TextStyle(fontSize: 12)),
                    Text("Qtd. de parcelas: ${qtdParcelas ?? '--'}",
                        style: const TextStyle(fontSize: 12)),
                    Text("Valor de cada parcela: ${fmtMoeda(prestacao ?? 0)}",
                        style: const TextStyle(fontSize: 12)),
                    Text("Capital em risco: ${fmtMoeda(capital ?? 0)}",
                        style: const TextStyle(fontSize: 12)),
                    Text("Juros totais: ${fmtMoeda(totalJuros ?? 0)}",
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
