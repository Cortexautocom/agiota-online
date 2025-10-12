import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'amortizacao_tabela.dart';

class EmprestimoFormAmort extends StatefulWidget {
  final String idCliente;
  final String? idUsuario;
  final VoidCallback onSaved;

  const EmprestimoFormAmort({
    super.key,
    required this.idCliente,
    this.idUsuario,
    required this.onSaved,
  });

  @override
  State<EmprestimoFormAmort> createState() => _EmprestimoFormAmortState();
}

class _EmprestimoFormAmortState extends State<EmprestimoFormAmort> {
  final _formKey = GlobalKey<FormState>();

  final valorCtrl = TextEditingController();
  final dataFimCtrl = TextEditingController();
  final taxaCtrl = TextEditingController();
  final dataInicioCtrl = TextEditingController();
  final qtdParcelasCtrl = TextEditingController();

  final ValueNotifier<bool> indefinido = ValueNotifier<bool>(false);
  final ValueNotifier<String?> frequencia = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    dataInicioCtrl.text =
        '${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}';
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

  Future<void> _criarEmprestimo() async {
    if (!_formKey.currentState!.validate()) return;

    // 🔹 Verifica se a frequência foi escolhida
    if (frequencia.value == null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Atenção'),
          content: const Text('Defina a frequência de pagamentos'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final valor = _parseMoeda(valorCtrl.text);
    final taxa = double.tryParse(taxaCtrl.text.replaceAll(',', '.')) ?? 0.0;

    if (!_validarData(dataFimCtrl.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data final inválida!")),
      );
      return;
    }

    final parts = dataFimCtrl.text.split('/');
    final dataFim = DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );

    try {
      final supabase = Supabase.instance.client;
      final uuid = Uuid();
      final emprestimoId = uuid.v4();
      final userId = Supabase.instance.client.auth.currentUser!.id;

      if (!_validarData(dataInicioCtrl.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data inicial inválida!")),
        );
        return;
      }

      final partsInicio = dataInicioCtrl.text.split('/');
      final dataInicio = DateTime(
        int.parse(partsInicio[2]),
        int.parse(partsInicio[1]),
        int.parse(partsInicio[0]),
      );

      if (dataFim.isBefore(dataInicio)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data final não pode ser anterior à data inicial!")),
        );
        return;
      }

      final dataStr =
          "${dataInicio.year}-${dataInicio.month.toString().padLeft(2, '0')}-${dataInicio.day.toString().padLeft(2, '0')}";
      final dataFimStr =
          "${dataFim.year}-${dataFim.month.toString().padLeft(2, '0')}-${dataFim.day.toString().padLeft(2, '0')}";

      await supabase.from('emprestimos').insert({
        'id': emprestimoId,
        'id_cliente': widget.idCliente,
        'valor': double.parse(valor.toStringAsFixed(2)),
        'data_inicio': dataStr,
        'data_fim': dataFimStr,
        'parcelas': int.tryParse(qtdParcelasCtrl.text) ?? 0,
        'juros': 0.0,
        'prestacao': 0.0,
        'taxa': double.parse(taxa.toStringAsFixed(2)),
        'frequencia': frequencia.value,
        'id_usuario': userId,
        'ativo': 'sim',
        'tipo_mov': 'amortizacao',
      });

      await supabase.from('parcelas').insert({
        'id': uuid.v4(),
        'id_emprestimo': emprestimoId,
        'data_mov': dataStr,
        'aporte': double.parse(valor.toStringAsFixed(2)),
        'pg_principal': 0.0,
        'pg_juros': 0.0,
        'juros_periodo': 0.0,
        'tipo_mov': 'amortizacao',
        'id_usuario': userId,
      });

      if (!mounted) return;
      final emprestimo = {
        "id": emprestimoId,
        "id_cliente": widget.idCliente,
        "valor": valor,
        "data_inicio": dataStr,
        "data_fim": dataFimStr,
        "parcelas": int.tryParse(qtdParcelasCtrl.text) ?? 0,
        "juros": 0.0,
        "prestacao": 0.0,
        "taxa": taxa,
        "frequencia": frequencia.value,
        "id_usuario": userId,
        "ativo": "sim",
        "tipo_mov": "amortizacao",
        "cliente": "",
        "aporte": valor,
      };

      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AmortizacaoTabela(emprestimo: emprestimo)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao criar empréstimo: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Novo Empréstimo - Amortização"),
        backgroundColor: Colors.green,
      ),
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
                      controller: valorCtrl,
                      decoration: const InputDecoration(
                        labelText: "Valor emprestado",
                        hintText: "R\$ 0,00",
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [_moedaFormatter()],
                      validator: (value) {
                        final valor = _parseMoeda(value ?? '');
                        if (valor <= 0) return "Informe um valor válido";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 🔹 Campo Qtd. parcelas + Indefinido
                    TextFormField(
                      controller: qtdParcelasCtrl,
                      keyboardType: TextInputType.number,
                      enabled: !indefinido.value,
                      decoration: InputDecoration(
                        labelText: 'Qtd. parcelas',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ValueListenableBuilder<bool>(
                              valueListenable: indefinido,
                              builder: (context, value, _) {
                                return Checkbox(
                                  value: value,
                                  onChanged: (novoValor) {
                                    final marcado = novoValor ?? false;
                                    indefinido.value = marcado;
                                    if (marcado) qtdParcelasCtrl.text = '0';
                                    setState(() {});
                                  },
                                );
                              },
                            ),
                            const Text('Indefinido'),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      validator: (v) {
                        if (!indefinido.value) {
                          if (v == null || v.isEmpty) return "Informe a quantidade";
                          final n = int.tryParse(v);
                          if (n == null || n <= 0) return "Número inválido";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 🔹 Campo Frequência de pagamentos
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Frequência de pagamentos',
                        border: UnderlineInputBorder(),
                      ),
                      child: ValueListenableBuilder<String?>(
                        valueListenable: frequencia,
                        builder: (context, valorAtual, _) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: valorAtual == 'Semanal',
                                    onChanged: (checked) {
                                      frequencia.value = checked == true ? 'Semanal' : null;
                                    },
                                  ),
                                  const Text('Semanal'),
                                ],
                              ),
                              Row(
                                children: [
                                  Checkbox(
                                    value: valorAtual == 'Mensal',
                                    onChanged: (checked) {
                                      frequencia.value = checked == true ? 'Mensal' : null;
                                    },
                                  ),
                                  const Text('Mensal'),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: dataInicioCtrl,
                      decoration: const InputDecoration(
                        labelText: "Data inicial",
                        hintText: "dd/mm/aaaa",
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [_dateMaskFormatter()],
                      validator: (value) {
                        if (value == null || value.isEmpty) return "Informe a data inicial";
                        if (!_validarData(value)) return "Data inválida";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: dataFimCtrl,
                      decoration: const InputDecoration(
                        labelText: "Data final",
                        hintText: "dd/mm/aaaa",
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [_dateMaskFormatter()],
                      validator: (value) {
                        if (value == null || value.isEmpty) return "Informe a data final";
                        if (!_validarData(value)) return "Data inválida";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: taxaCtrl,
                      decoration: const InputDecoration(
                        labelText: "Taxa de juros mensal (%)",
                        hintText: "0,00",
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return "Informe a taxa de juros";
                        final taxa = double.tryParse(value.replaceAll(',', '.'));
                        if (taxa == null || taxa < 0) return "Taxa inválida";
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _criarEmprestimo,
                      icon: const Icon(Icons.check),
                      label: const Text("Criar Empréstimo"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    dataInicioCtrl.dispose();
    valorCtrl.dispose();
    dataFimCtrl.dispose();
    taxaCtrl.dispose();
    qtdParcelasCtrl.dispose();
    indefinido.dispose();
    frequencia.dispose();
    super.dispose();
  }
}
