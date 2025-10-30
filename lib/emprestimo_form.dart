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

  final dataInicioCtrl = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    _carregarNomeCliente();

    // 🔹 Preenche com data atual
    final hoje = DateTime.now();
    dataInicioCtrl.text =
        '${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}';

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
    dataInicioCtrl.dispose();
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

  // 🔹 Máscara de data
  TextInputFormatter _dateMaskFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (text.length >= 3) text = '${text.substring(0, 2)}/${text.substring(2)}';
      if (text.length >= 6) text = '${text.substring(0, 5)}/${text.substring(5)}';
      if (text.length > 10) text = text.substring(0, 10);
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  bool _validarData(String data) {
    if (data.isEmpty) return false;
    final parts = data.split('/');
    if (parts.length != 3) return false;
    try {
      final dia = int.parse(parts[0]);
      final mes = int.parse(parts[1]);
      final ano = int.parse(parts[2]);
      if (dia < 1 || dia > 31) return false;
      if (mes < 1 || mes > 12) return false;
      if (ano < 1900 || ano > 2100) return false;
      final date = DateTime(ano, mes, dia);
      return date.day == dia && date.month == mes && date.year == ano;
    } catch (e) {
      return false;
    }
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
        const SnackBar(content: Text("Preencha os campos e simule antes de salvar!")),
      );
      return;
    }

    if (!_validarData(dataInicioCtrl.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data inicial inválida!")),
      );
      return;
    }

    final partes = dataInicioCtrl.text.split('/');
    final dataEmprestimo = DateTime(
      int.parse(partes[2]),
      int.parse(partes[1]),
      int.parse(partes[0]),
    );

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
          'tipo_mov': 'parcelamento',
        })
        .select()
        .maybeSingle();

    final numeroEmprestimo = insertResp?['numero'] ?? 0;

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
            "numero": numeroEmprestimo,
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
        title: const Text("Novo Empréstimo - Parcelamento"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100,
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cabeçalho
                          _buildHeader(),
                          const SizedBox(height: 20),
                          
                          // Valor financiado
                          _buildCapitalField(),
                          const SizedBox(height: 16),
                          
                          // Quantidade de parcelas
                          _buildParcelasField(),
                          const SizedBox(height: 16),
                          
                          // Data inicial
                          _buildDataField(),
                          const SizedBox(height: 16),
                          
                          // Taxa ou Parcela
                          _buildCalculoSection(),
                          const SizedBox(height: 20),
                          
                          // Botão Simular
                          _buildSimularButton(),
                          const SizedBox(height: 16),
                          
                          // Resumo da simulação
                          if (prestacao != null) _buildResumoSection(),
                          const SizedBox(height: 16),
                          
                          // Botão Criar
                          _buildActionButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Novo Empréstimo - Parcelamento",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Preencha os dados do financiamento",
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildCapitalField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Valor Financiado",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: capitalCtrl,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: "R\$ 0,00",
            hintStyle: const TextStyle(fontSize: 15),
            prefixIcon: Icon(Icons.attach_money, size: 20, color: Colors.blue.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [_moedaFormatter()],
          validator: (value) {
            final valor = _parseMoeda(value ?? '');
            if (valor <= 0) return "Informe um valor válido";
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildParcelasField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quantidade de Parcelas",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: mesesCtrl,
          style: const TextStyle(fontSize: 15),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: "",
            hintStyle: const TextStyle(fontSize: 15),
            prefixIcon: Icon(Icons.format_list_numbered, size: 20, color: Colors.blue.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return "Informe a quantidade";
            final n = int.tryParse(value);
            if (n == null || n <= 0) return "Número inválido";
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDataField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Data Inicial",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: dataInicioCtrl,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: "dd/mm/aaaa",
            hintStyle: const TextStyle(fontSize: 15),
            prefixIcon: Icon(Icons.calendar_today, size: 20, color: Colors.blue.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [_dateMaskFormatter()],
          validator: (value) {
            if (value == null || value.isEmpty) return "Informe a data inicial";
            if (!_validarData(value)) return "Data inválida";
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCalculoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Cálculo do Financiamento",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Informe apenas um dos campos abaixo:",
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Taxa Mensal (%)",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    focusNode: taxaFocus,
                    controller: taxaCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "0,00%",
                      hintStyle: const TextStyle(fontSize: 14),
                      prefixIcon: Icon(Icons.percent, size: 18, color: Colors.blue.shade600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Valor da Parcela",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    focusNode: parcelaFocus,
                    controller: parcelaCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "R\$ 0,00",
                      hintStyle: const TextStyle(fontSize: 14),
                      prefixIcon: Icon(Icons.payment, size: 18, color: Colors.blue.shade600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [_moedaFormatter()],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSimularButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _simular,
        icon: const Icon(Icons.calculate, size: 20),
        label: const Text(
          "Simular Empréstimo",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildResumoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Resumo do Financiamento",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 12),
          _buildResumoItem("Valor financiado:", fmtMoeda(capital ?? 0)),
          _buildResumoItem("Taxa mensal:", "${taxaFinal?.toStringAsFixed(2)}%"),
          _buildResumoItem("Quantidade de parcelas:", "${qtdParcelas ?? '--'}"),
          _buildResumoItem("Valor da parcela:", fmtMoeda(prestacao ?? 0)),
          _buildResumoItem("Total com juros:", fmtMoeda(totalComJuros ?? 0)),
          _buildResumoItem("Juros totais:", fmtMoeda(totalJuros ?? 0)),
        ],
      ),
    );
  }

  Widget _buildResumoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: salvar,
        icon: const Icon(Icons.check_circle, size: 20),
        label: const Text(
          "Criar Empréstimo",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}