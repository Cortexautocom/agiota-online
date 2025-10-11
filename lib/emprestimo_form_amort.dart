import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart'; // Adicionar para TextInputFormatter
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

  DateTime dataEmprestimo = DateTime.now();
  DateTime? dataFinal;

  // 🔹 Máscara para campos de moeda
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

  // 🔹 Máscara para data (dd/mm/aaaa)
  TextInputFormatter _dateMaskFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (text.length >= 3) {
        text = '${text.substring(0, 2)}/${text.substring(2)}';
      }
      if (text.length >= 6) {
        text = '${text.substring(0, 5)}/${text.substring(5)}';
      }
      if (text.length > 10) {
        text = text.substring(0, 10);
      }
      
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  // 🔹 Validar data
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
    if (!_formKey.currentState!.validate()) {
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

    if (dataFim.isBefore(dataEmprestimo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data final não pode ser anterior à data atual!")),
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final uuid = Uuid();
      final emprestimoId = uuid.v4();
      final userId = Supabase.instance.client.auth.currentUser!.id;

      final dataStr = "${dataEmprestimo.year}-${dataEmprestimo.month.toString().padLeft(2, '0')}-${dataEmprestimo.day.toString().padLeft(2, '0')}";
      final dataFimStr = "${dataFim.year}-${dataFim.month.toString().padLeft(2, '0')}-${dataFim.day.toString().padLeft(2, '0')}";

      await supabase.from('emprestimos').insert({
        'id': emprestimoId,
        'id_cliente': widget.idCliente,
        'valor': double.parse(valor.toStringAsFixed(2)),
        'data_inicio': dataStr,
        'data_fim': dataFimStr,
        'parcelas': 0, // Amortização não tem número fixo de parcelas
        'juros': 0.0, // Será calculado nas parcelas
        'prestacao': 0.0, // Não aplicável para amortização
        'taxa': double.parse(taxa.toStringAsFixed(2)),
        'id_usuario': userId,
        'ativo': 'sim',
        'tipo_mov': 'amortizacao',
      });

      if (!mounted) return;

      final emprestimo = {
        "id": emprestimoId,
        "id_cliente": widget.idCliente,
        "valor": valor,
        "data_inicio": dataStr,
        "data_fim": dataFimStr,
        "parcelas": 0,
        "juros": 0.0,
        "prestacao": 0.0,
        "taxa": taxa,
        "id_usuario": userId,
        "ativo": "sim",
        "tipo_mov": "amortizacao",
        "cliente": "Cliente ${widget.idCliente}",
      };

      // 🔹 Navega para a tela de amortização
      Navigator.pop(context); // Fecha o form
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AmortizacaoTabela(
            emprestimo: emprestimo,
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
                        if (valor <= 0) {
                          return "Informe um valor válido";
                        }
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
                        if (value == null || value.isEmpty) {
                          return "Informe a data final";
                        }
                        if (!_validarData(value)) {
                          return "Data inválida";
                        }
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
                        if (value == null || value.isEmpty) {
                          return "Informe a taxa de juros";
                        }
                        final taxa = double.tryParse(value.replaceAll(',', '.'));
                        if (taxa == null || taxa < 0) {
                          return "Taxa inválida";
                        }
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
}