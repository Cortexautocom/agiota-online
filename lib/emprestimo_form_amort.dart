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
        MaterialPageRoute(
          builder: (_) => AmortizacaoTabela(
            emprestimo: emprestimo,
            onSaved: widget.onSaved, // ✅ adiciona o callback herdado do form
          ),
        ),
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
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade50,
              Colors.green.shade100,
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
                          
                          // Valor do empréstimo
                          _buildValorField(),
                          const SizedBox(height: 16),
                          
                          // Configuração de parcelas
                          _buildParcelasSection(),
                          const SizedBox(height: 16),
                          
                          // Frequência de pagamentos
                          _buildFrequenciaSection(),
                          const SizedBox(height: 16),
                          
                          // Datas
                          _buildDatasSection(),
                          const SizedBox(height: 16),
                          
                          // Taxa de juros
                          _buildTaxaField(),
                          const SizedBox(height: 24),
                          
                          // Botão de ação
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
          "Novo Empréstimo - Amortização",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Preencha os dados do empréstimo",
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildValorField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Valor do Empréstimo",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: valorCtrl,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: "R\$ 0,00",
            hintStyle: const TextStyle(fontSize: 15),
            prefixIcon: Icon(Icons.attach_money, size: 20, color: Colors.green.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.green.shade600, width: 1.5),
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

  Widget _buildParcelasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [        
        ValueListenableBuilder<bool>(
          valueListenable: indefinido,
          builder: (context, indef, _) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  // Campo de quantidade de parcelas
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Quantidade de Parcelas",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: qtdParcelasCtrl,
                              focusNode: parcelasFocus,
                              style: const TextStyle(fontSize: 14),
                              keyboardType: TextInputType.number,
                              enabled: !indef,
                              onEditingComplete: _atualizarDataFinal,
                              decoration: InputDecoration(
                                hintText: "",
                                hintStyle: const TextStyle(fontSize: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: indef ? Colors.grey.shade100 : Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Checkbox Indefinido
                      Row(
                        mainAxisSize: MainAxisSize.min,
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
                          Text(
                            'Indefinido',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Marque 'Indefinido' para empréstimos sem prazo determinado",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFrequenciaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [        
        ValueListenableBuilder<bool>(
          valueListenable: indefinido,
          builder: (context, indef, _) {
            return AbsorbPointer(
              absorbing: indef,
              child: Opacity(
                opacity: indef ? 0.5 : 1.0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ValueListenableBuilder<String?>(
                    valueListenable: frequencia,
                    builder: (context, valorAtual, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Selecione a periodicidade dos pagamentos:",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFrequenciaOption(
                                  value: 'Semanal',
                                  label: 'Semanal',
                                  icon: Icons.calendar_view_week,
                                  isSelected: valorAtual == 'Semanal',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildFrequenciaOption(
                                  value: 'Mensal',
                                  label: 'Mensal',
                                  icon: Icons.calendar_today,
                                  isSelected: valorAtual == 'Mensal',
                                ),
                              ),
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
      ],
    );
  }

  Widget _buildFrequenciaOption({
    required String value,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        frequencia.value = isSelected ? null : value;
        _atualizarDataFinal();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.green.shade300 : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.green.shade700 : Colors.grey.shade600,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [        
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Data Inicial",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: dataInicioCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "dd/mm/aaaa",
                      hintStyle: const TextStyle(fontSize: 14),
                      prefixIcon: Icon(Icons.calendar_today, size: 20, color: Colors.green.shade600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: indefinido,
                builder: (context, indef, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Data Final",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: dataFimCtrl,
                        style: const TextStyle(fontSize: 14),
                        enabled: !indef,
                        decoration: InputDecoration(
                          hintText: indef ? "Indefinido" : "dd/mm/aaaa",
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: indef ? Colors.grey.shade400 : null,
                          ),
                          prefixIcon: Icon(Icons.event, size: 20,
                              color: indef ? Colors.grey.shade400 : Colors.green.shade600),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: indef ? Colors.grey.shade100 : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [_dateMaskFormatter()],
                        validator: (value) {
                          if (indef) return null;
                          if (value == null || value.isEmpty) return "Informe a data final";
                          if (!_validarData(value)) return "Data inválida";
                          return null;
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaxaField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Taxa de Juros Mensal",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: taxaCtrl,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: "0,00%",
            hintStyle: const TextStyle(fontSize: 15),
            prefixIcon: Icon(Icons.percent, size: 20, color: Colors.green.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.green.shade600, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) return "Informe a taxa de juros";
            final taxa = double.tryParse(value.replaceAll(',', '.'));
            if (taxa == null || taxa < 0) return "Taxa inválida";
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _criarEmprestimo,
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

  @override
  void dispose() {
    parcelasFocus.dispose();
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