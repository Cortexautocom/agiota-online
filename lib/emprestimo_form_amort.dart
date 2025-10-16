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
  final FocusNode parcelasFocus = FocusNode();
  final ValueNotifier<bool> indefinido = ValueNotifier<bool>(false);
  final ValueNotifier<String?> frequencia = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    dataInicioCtrl.text =
        '${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}';

    // 🔹 Listener: ao sair do campo de parcelas, calcula a data final
    parcelasFocus.addListener(() {
      if (!parcelasFocus.hasFocus) {
        _atualizarDataFinal();
      }
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

    // 🔹 Verifica se a frequência foi escolhida, exceto se for indefinido
    if (frequencia.value == null && !indefinido.value) {
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

      // 🔹 Cria primeira parcela (aporte)
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

      // 🔹 Cria parcelas futuras, se definidas
      final qtdParcelas = int.tryParse(qtdParcelasCtrl.text) ?? 0;
      if (qtdParcelas > 0) {
        final freq = frequencia.value;
        DateTime dataParcela = dataInicio;

        for (int i = 1; i <= qtdParcelas; i++) {
          if (freq == 'Semanal') {
            dataParcela = dataParcela.add(const Duration(days: 7));
          } else if (freq == 'Mensal') {
            final mes = dataParcela.month + 1;
            final ano = dataParcela.year + ((mes - 1) ~/ 12);
            final mesFinal = ((mes - 1) % 12) + 1;
            int dia = dataParcela.day;

            // Ajusta se o mês não tiver o mesmo dia (ex: fevereiro)
            final ultimoDiaDoMes = DateTime(ano, mesFinal + 1, 0).day;
            if (dia > ultimoDiaDoMes) dia = ultimoDiaDoMes;

            dataParcela = DateTime(ano, mesFinal, dia);
          }

          final dataMov =
              "${dataParcela.year}-${dataParcela.month.toString().padLeft(2, '0')}-${dataParcela.day.toString().padLeft(2, '0')}";

          await supabase.from('parcelas').insert({
            'id': uuid.v4(),
            'id_emprestimo': emprestimoId,
            'data_mov': dataMov,
            'pg_principal': 0.0,
            'pg_juros': 0.0,
            'juros_periodo': 0.0,
            'tipo_mov': 'amortizacao',
            'id_usuario': userId,
          });
        }
      }

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
                    ValueListenableBuilder<bool>(
                      valueListenable: indefinido,
                      builder: (context, indef, _) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Campo de quantidade de parcelas
                            Expanded(
                              child: TextFormField(
                                controller: qtdParcelasCtrl,
                                focusNode: parcelasFocus, // 🔹 adiciona o focus node
                                keyboardType: TextInputType.number,
                                enabled: !indef,
                                onEditingComplete: _atualizarDataFinal, // 🔹 calcula ao sair do campo
                                decoration: InputDecoration(
                                  labelText: 'Qtd. parcelas',                                  
                                ),
                                validator: (v) {
                                  if (!indef) {
                                    if (v == null || v.isEmpty) return "Informe a quantidade";
                                    final n = int.tryParse(v);
                                    if (n == null || n <= 0) return "Número inválido";
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Caixa de seleção "Indefinido"
                            Row(
                              children: [
                                Checkbox(
                                  value: indef,
                                  onChanged: (novoValor) {
                                    if (novoValor != null) {
                                      indefinido.value = novoValor;
                                      if (novoValor) {
                                        qtdParcelasCtrl.text = '0';
                                        frequencia.value = null;
                                      }
                                    }
                                  },
                                ),
                                const Text('Indefinido'),
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    // 🔹 Campo Frequência de pagamentos
                    ValueListenableBuilder<bool>(
                      valueListenable: indefinido,
                      builder: (context, indef, _) {
                        final desativado = indef;
                        return InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Frequência de pagamentos',
                            border: UnderlineInputBorder(),
                          ),
                          child: AbsorbPointer(
                            absorbing: desativado, // bloqueia interação se indefinido
                            child: Opacity(
                              opacity: desativado ? 0.5 : 1.0, // efeito esmaecido
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
                                              if (checked == true) {
                                                frequencia.value = 'Semanal';
                                                _atualizarDataFinal(); // 🔹 calcula data final automaticamente
                                              } else {
                                                frequencia.value = null;
                                              }
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
                                              if (checked == true) {
                                                frequencia.value = 'Mensal';
                                                _atualizarDataFinal(); // 🔹 calcula data final automaticamente
                                              } else {
                                                frequencia.value = null;
                                              }
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
                          ),
                        );
                      },
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
                    ValueListenableBuilder<bool>(
                      valueListenable: indefinido,
                      builder: (context, indef, _) {
                        return TextFormField(
                          controller: dataFimCtrl,
                          decoration: const InputDecoration(
                            labelText: "Data final",
                            hintText: "dd/mm/aaaa",
                          ),
                          enabled: !indef, // 🔹 bloqueia se indefinido
                          keyboardType: TextInputType.number,
                          inputFormatters: [_dateMaskFormatter()],
                          validator: (value) {
                            if (indef) return null; // 🔹 ignora validação se indefinido
                            if (value == null || value.isEmpty) return "Informe a data final";
                            if (!_validarData(value)) return "Data inválida";
                            return null;
                          },
                        );
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
    parcelasFocus.dispose(); // 🔹 libera o focus node
    dataInicioCtrl.dispose();
    valorCtrl.dispose();
    dataFimCtrl.dispose();
    taxaCtrl.dispose();
    qtdParcelasCtrl.dispose();
    indefinido.dispose();
    frequencia.dispose();
    super.dispose();
  }

  void _atualizarDataFinal() {
    final qtd = int.tryParse(qtdParcelasCtrl.text) ?? 0;
    if (qtd <= 0) return;
    if (frequencia.value == null) return;
    if (!_validarData(dataInicioCtrl.text)) return;

    final partes = dataInicioCtrl.text.split('/');
    DateTime data = DateTime(
      int.parse(partes[2]),
      int.parse(partes[1]),
      int.parse(partes[0]),
    );

    // 🔹 Calcula data final conforme a frequência
    for (int i = 0; i < qtd; i++) {
      if (frequencia.value == 'Semanal') {
        data = data.add(const Duration(days: 7));
      } else if (frequencia.value == 'Mensal') {
        final mes = data.month + 1;
        final ano = data.year + ((mes - 1) ~/ 12);
        final mesFinal = ((mes - 1) % 12) + 1;
        int dia = data.day;

        final ultimoDiaDoMes = DateTime(ano, mesFinal + 1, 0).day;
        if (dia > ultimoDiaDoMes) dia = ultimoDiaDoMes;

        data = DateTime(ano, mesFinal, dia);
      }
    }

    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    dataFimCtrl.text = "$dia/$mes/$ano";
  }



}
