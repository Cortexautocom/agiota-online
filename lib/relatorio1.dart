import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RelatorioParcelasEmAberto extends StatefulWidget {
  final TextEditingController dataInicioCtrl;
  final TextEditingController dataFimCtrl;

  const RelatorioParcelasEmAberto({
    super.key,
    required this.dataInicioCtrl,
    required this.dataFimCtrl,
  });

  @override
  State<RelatorioParcelasEmAberto> createState() =>
      _RelatorioParcelasEmAbertoState();
}

class _RelatorioParcelasEmAbertoState
    extends State<RelatorioParcelasEmAberto> {
  bool carregando = false;
  List<Map<String, dynamic>> relatorio = [];

  @override
  void initState() {
    super.initState();
    _buscarParcelasEmAberto();
  }

  Future<void> _buscarParcelasEmAberto() async {
    setState(() {
      carregando = true;
      relatorio = [];
    });

    try {
      final supabase = Supabase.instance.client;

      // 🔹 Busca na VIEW com dados completos
      final query = supabase.from('vw_parcelas_detalhes').select('''
        id,
        numero,
        valor,
        juros,
        residual,
        vencimento,
        cliente,
        ativo,
        capital_total,
        juros_total,
        qtd_parcelas
      ''').gt('residual', 0).eq('ativo', 'sim');

      // 🔹 Filtro de datas (se preenchido)
      if (widget.dataInicioCtrl.text.isNotEmpty &&
          widget.dataFimCtrl.text.isNotEmpty) {
        final inicioParts = widget.dataInicioCtrl.text.split('/');
        final fimParts = widget.dataFimCtrl.text.split('/');

        final dataInicio = DateTime(
          int.parse(inicioParts[2]),
          int.parse(inicioParts[1]),
          int.parse(inicioParts[0]),
        );
        final dataFim = DateTime(
          int.parse(fimParts[2]),
          int.parse(fimParts[1]),
          int.parse(fimParts[0]),
        );

        query
          ..gte('vencimento', dataInicio.toIso8601String())
          ..lte('vencimento', dataFim.toIso8601String());
      }

      final response = await query.order('vencimento', ascending: true);
      final dados = response as List;

      setState(() {
        relatorio = dados.map<Map<String, dynamic>>((p) {
          final nomeCliente = p['cliente'] ?? 'Sem cliente';
          final capital = (p['valor'] ?? 0).toDouble();
          final jurosSupabase = (p['juros_total'] ?? 0).toDouble();
          final qtdParcelas = (p['qtd_parcelas'] ?? 1).toDouble();

          // 🔹 Cálculo replicado da tela ParcelasTable:
          final pgPrincipal = (p['capital_total'] ?? 0) / qtdParcelas;
          final pgJuros = jurosSupabase / qtdParcelas; // sem desconto nem juros digitado
          final total = capital + pgJuros;

          return {
            'cliente': nomeCliente,
            'numero': p['numero'],
            'capital': capital,
            'juros': pgJuros,
            'total': total,
          };
        }).toList();
      });
    } catch (e) {
      debugPrint("❌ Erro ao buscar parcelas em aberto: $e");
    } finally {
      setState(() {
        carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatador = NumberFormat.currency(locale: "pt_BR", symbol: "R\$");

    double totalCapital = relatorio.fold(0, (s, e) => s + e['capital']);
    double totalJuros = relatorio.fold(0, (s, e) => s + e['juros']);
    double totalGeral = relatorio.fold(0, (s, e) => s + e['total']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔹 Botão Buscar
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: carregando ? null : _buscarParcelasEmAberto,
              icon: const Icon(Icons.search),
              label: const Text("Buscar"),
            ),
          ],
        ),

        const SizedBox(height: 10),
        const Text(
          "📄 Parcelas em aberto",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

        // 🔹 Corpo do relatório
        Expanded(
          child: carregando
              ? const Center(child: CircularProgressIndicator())
              : relatorio.isEmpty
                  ? const Center(child: Text("Nenhuma parcela em aberto encontrada."))
                  : ListView.builder(
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

        // 🔹 Totais
        if (relatorio.isNotEmpty)
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
    );
  }
}
