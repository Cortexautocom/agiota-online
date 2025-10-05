import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class RelatoriosPage extends StatefulWidget {
  const RelatoriosPage({super.key});

  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

class _RelatoriosPageState extends State<RelatoriosPage> {
  final dataInicioCtrl = TextEditingController();
  final dataFimCtrl = TextEditingController();
  final dataMask = MaskTextInputFormatter(mask: '##/##/####');
  String tipoRelatorio = 'Parcelas em aberto';

  final List<Map<String, dynamic>> relatorio = [
    {"cliente": "João Silva", "numero": 1, "capital": 1500.00, "juros": 120.00, "total": 1620.00},
    {"cliente": "Maria Souza", "numero": 2, "capital": 1000.00, "juros": 80.00, "total": 1080.00},
    {"cliente": "Carlos Lima", "numero": 3, "capital": 2000.00, "juros": 200.00, "total": 2200.00},
  ];

  @override
  Widget build(BuildContext context) {
    final formatador = NumberFormat.currency(locale: "pt_BR", symbol: "R\$");

    double totalCapital = relatorio.fold(0, (s, e) => s + e['capital']);
    double totalJuros = relatorio.fold(0, (s, e) => s + e['juros']);
    double totalGeral = relatorio.fold(0, (s, e) => s + e['total']);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Linha de filtros
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
                    DropdownMenuItem(value: "Parcelas em aberto", child: Text("Parcelas em aberto")),
                    DropdownMenuItem(value: "Empréstimos ativos", child: Text("Empréstimos ativos")),
                    DropdownMenuItem(value: "Empréstimos quitados", child: Text("Empréstimos quitados")),
                    DropdownMenuItem(value: "Clientes x Dívida", child: Text("Clientes x Dívida")),
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

          // 🔹 Título do relatório
          Text(
            tipoRelatorio,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          // 🔹 Cabeçalho da tabela
          Container(
            color: Colors.grey[300],
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text("Cliente", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text("Nº", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("Capital", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("Juros", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("Total", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          // 🔹 Linhas de dados
          Expanded(
            child: ListView.builder(
              itemCount: relatorio.length,
              itemBuilder: (context, index) {
                final item = relatorio[index];
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(item['cliente'])),
                      Expanded(flex: 1, child: Text(item['numero'].toString())),
                      Expanded(flex: 2, child: Text(formatador.format(item['capital']))),
                      Expanded(flex: 2, child: Text(formatador.format(item['juros']))),
                      Expanded(flex: 2, child: Text(formatador.format(item['total']))),
                    ],
                  ),
                );
              },
            ),
          ),

          // 🔹 Linha de totalizadores
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                const Expanded(flex: 4, child: Text("Totais:", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text(formatador.format(totalCapital), style: const TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text(formatador.format(totalJuros), style: const TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text(formatador.format(totalGeral), style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
