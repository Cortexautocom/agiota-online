import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'relatorio1.dart'; // 🔹 Parcelas em Aberto
import 'relatorio2.dart'; // 🔹 Parcelas em Atraso
import 'relatorio3.dart'; // 🔹 Parcelas com Acordo Vigente

class RelatoriosPage extends StatefulWidget {
  const RelatoriosPage({super.key});

  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

class _RelatoriosPageState extends State<RelatoriosPage> {
  String tipoRelatorio = 'Parcelas em aberto';

  // Controladores de data (usados por todos os relatórios)
  final dataInicioCtrl = TextEditingController();
  final dataFimCtrl = TextEditingController();
  final dataMask = MaskTextInputFormatter(mask: '##/##/####');

  /// 🔹 Monta o corpo da página com base no tipo de relatório
  Widget _buildRelatorio() {
    switch (tipoRelatorio) {
      case 'Parcelas em aberto':
        return RelatorioParcelasEmAberto(
          dataInicioCtrl: dataInicioCtrl,
          dataFimCtrl: dataFimCtrl,
        );

      case 'Parcelas em atraso':
        return RelatorioParcelasVencidas(
          dataInicioCtrl: dataInicioCtrl,
          dataFimCtrl: dataFimCtrl,
        );

      case 'Parcelas com acordo vigente':
        return RelatorioParcelasComAcordo(
          dataInicioCtrl: dataInicioCtrl,
          dataFimCtrl: dataFimCtrl,
        );

      case 'Empréstimos ativos':
        return const Center(child: Text("📊 Empréstimos ativos (em breve)"));

      case 'Empréstimos quitados':
        return const Center(child: Text("📊 Empréstimos quitados (em breve)"));

      case 'Clientes x Dívida':
        return const Center(child: Text("📊 Clientes x Dívida (em breve)"));

      default:
        return const Center(child: Text("Selecione um tipo de relatório."));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Linha superior — seleção de tipo e datas
          Row(
            children: [
              // Tipo de relatório
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: tipoRelatorio,
                  decoration: const InputDecoration(
                    labelText: "Tipo de relatório",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: "Parcelas em aberto",
                      child: Text("Parcelas em aberto"),
                    ),
                    DropdownMenuItem(
                      value: "Parcelas em atraso",
                      child: Text("Parcelas em atraso"),
                    ),
                    DropdownMenuItem(
                      value: "Parcelas com acordo vigente",
                      child: Text("Parcelas com acordo vigente"),
                    ),
                    DropdownMenuItem(
                      value: "Empréstimos ativos",
                      child: Text("Empréstimos ativos"),
                    ),
                    DropdownMenuItem(
                      value: "Empréstimos quitados",
                      child: Text("Empréstimos quitados"),
                    ),
                    DropdownMenuItem(
                      value: "Clientes x Dívida",
                      child: Text("Clientes x Dívida"),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      tipoRelatorio = v!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),

              // Data inicial
              Expanded(
                child: TextField(
                  controller: dataInicioCtrl,
                  decoration: const InputDecoration(
                    labelText: "Data inicial",
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [dataMask],
                ),
              ),
              const SizedBox(width: 16),

              // Data final
              Expanded(
                child: TextField(
                  controller: dataFimCtrl,
                  decoration: const InputDecoration(
                    labelText: "Data final",
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [dataMask],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 🔹 Corpo dinâmico — relatório selecionado
          Expanded(child: _buildRelatorio()),
        ],
      ),
    );
  }
}
