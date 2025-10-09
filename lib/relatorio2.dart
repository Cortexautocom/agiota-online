import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parcelas_page.dart'; // ✅ Import para abrir a tela de parcelas

class RelatorioParcelasVencidas extends StatefulWidget {
  final TextEditingController dataInicioCtrl;
  final TextEditingController dataFimCtrl;
  final ValueNotifier<bool> refreshNotifier; // 🔹 Novo parâmetro padronizado

  const RelatorioParcelasVencidas({
    super.key,
    required this.dataInicioCtrl,
    required this.dataFimCtrl,
    required this.refreshNotifier, // 🔹 Novo parâmetro obrigatório
  });

  @override
  State<RelatorioParcelasVencidas> createState() =>
      _RelatorioParcelasVencidasState();
}

class _RelatorioParcelasVencidasState
    extends State<RelatorioParcelasVencidas> {
  bool carregando = false;
  List<Map<String, dynamic>> relatorio = [];

  @override
  void initState() {
    super.initState();
    _buscarParcelasVencidas();
    
    // 🔹 OUVINTE para atualizar quando o notificador mudar
    widget.refreshNotifier.addListener(_onRefreshRequested);
  }

  @override
  void dispose() {
    // 🔹 IMPORTANTE: Remover o listener para evitar vazamentos de memória
    widget.refreshNotifier.removeListener(_onRefreshRequested);
    super.dispose();
  }

  // 🔹 Método chamado quando o botão Buscar é pressionado
  void _onRefreshRequested() {
    print('🔄 Relatorio2: Recebendo solicitação de atualização!');
    _buscarParcelasVencidas();
  }

  String formatarData(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return '';
    }
  }

  DateTime? _parseDataFiltro(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final parts = text.split('/');
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _buscarParcelasVencidas() async {
    print('🔍 Relatorio2: Iniciando busca com filtros...');
    print('   Data Início: ${widget.dataInicioCtrl.text}');
    print('   Data Fim: ${widget.dataFimCtrl.text}');
    
    // ✅ VERIFICAÇÃO mounted ANTES de iniciar o loading
    if (!mounted) return;
    
    setState(() {
      carregando = true;
      relatorio = [];
    });

    try {
      final supabase = Supabase.instance.client;
      final hoje = DateTime.now();

      final response = await supabase
          .from('vw_parcelas_detalhes')
          .select('''
            id,
            id_emprestimo,
            numero,
            valor,
            juros,
            residual,
            vencimento,
            data_prevista,
            cliente,
            ativo,
            capital_total,
            juros_total,
            qtd_parcelas
          ''')
          .gt('residual', 0)
          .eq('ativo', 'sim')
          // 🔹 Ordena primeiro por cliente, depois por vencimento (igual relatorio1)
          .order('cliente', ascending: true)
          .order('vencimento', ascending: true);

      // ✅ VERIFICAÇÃO mounted após a requisição
      if (!mounted) return;

      final dataInicio = _parseDataFiltro(widget.dataInicioCtrl.text);
      final dataFim = _parseDataFiltro(widget.dataFimCtrl.text);

      print('   Filtros aplicados:');
      print('   - Data início: $dataInicio');
      print('   - Data fim: $dataFim');

      final filtradas = response.where((p) {
        final venc = DateTime.tryParse(p['vencimento'] ?? '');
        if (venc == null) return false;

        // 🔹 Apenas vencidas
        if (!venc.isBefore(DateTime(hoje.year, hoje.month, hoje.day))) {
          return false;
        }

        // 🔹 Apenas sem acordo (data_prevista NULL)
        if (p['data_prevista'] != null) return false;

        // 🔹 Filtros opcionais de data
        if (dataInicio != null && venc.isBefore(dataInicio)) return false;
        if (dataFim != null && venc.isAfter(dataFim)) return false;

        return true;
      }).toList();

      print('   ✅ Parcelas vencidas encontradas: ${filtradas.length}');

      // 🔹 ORDENAÇÃO LOCAL - Primeiro por cliente (alfabético), depois por vencimento
      filtradas.sort((a, b) {
        final nomeA = (a['cliente'] ?? '').toString().toLowerCase();
        final nomeB = (b['cliente'] ?? '').toString().toLowerCase();
        final compNome = nomeA.compareTo(nomeB);
        if (compNome != 0) return compNome;

        final da = DateTime.tryParse(a['vencimento'] ?? '') ?? DateTime(2100);
        final db = DateTime.tryParse(b['vencimento'] ?? '') ?? DateTime(2100);
        return da.compareTo(db);
      });

      // ✅ VERIFICAÇÃO mounted antes de atualizar os dados
      if (!mounted) return;
      
      setState(() {
        relatorio = filtradas.map<Map<String, dynamic>>((p) {
          final nomeCliente = p['cliente'] ?? 'Sem cliente';
          final capitalTotal = (p['capital_total'] ?? 0).toDouble();
          final jurosSupabase = (p['juros_total'] ?? 0).toDouble();
          final qtdParcelas = (p['qtd_parcelas'] ?? 1).toDouble();

          final pgPrincipal = capitalTotal / qtdParcelas;
          final pgJuros = jurosSupabase / qtdParcelas;
          final total = pgPrincipal + pgJuros;

          return {
            'id_emprestimo': p['id_emprestimo'],
            'cliente': nomeCliente,
            'numero': p['numero'],
            'vencimento': formatarData(p['vencimento']),
            'capital': pgPrincipal,
            'juros': pgJuros,
            'total': total,
          };
        }).toList();
      });
    } catch (e) {
      // ✅ VERIFICAÇÃO mounted no catch também
      if (mounted) {
        debugPrint("❌ Erro ao buscar parcelas vencidas: $e");
        // Mostra snackbar de erro para o usuário
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao buscar parcelas vencidas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // ✅ VERIFICAÇÃO mounted no finally
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
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
        const SizedBox(height: 10),
        const Text(
          "📄 Parcelas em atraso",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        Container(
          color: Colors.grey[300],
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text("Cliente", style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 1, child: Text("Nº", style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text("Vencimento", style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text("Capital", style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text("Juros", style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text("Total", style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),

        Expanded(
          child: carregando
              ? const Center(child: CircularProgressIndicator())
              : relatorio.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning_amber, size: 50, color: Colors.orange),
                          SizedBox(height: 10),
                          Text(
                            "Nenhuma parcela em atraso encontrada.",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          SizedBox(height: 5),
                          Text(
                            "Tente ajustar os filtros de data.",
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: relatorio.length,
                      itemBuilder: (context, index) {
                        final item = relatorio[index];
                        return InkWell(
                          onTap: () {
                            debugPrint("🖱 Clique: abrindo parcelas do empréstimo ${item['id_emprestimo']} (${item['cliente']})");
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ParcelasPage(
                                  emprestimo: {
                                    'id': item['id_emprestimo'],
                                    'cliente': item['cliente'],
                                    'numero': item['numero'],
                                    'valor': item['capital'] ?? 0,
                                    'juros': item['juros'] ?? 0,
                                    'prestacao': item['total'] ?? 0,
                                    'data_inicio': item['vencimento'],
                                    'id_usuario': Supabase.instance.client.auth.currentUser?.id ?? '',
                                  },
                                  onSaved: () {
                                    // ✅ Recarrega os dados quando volta da tela de parcelas
                                    _buscarParcelasVencidas();
                                  },
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                              color: index.isEven ? Colors.white : Colors.grey[50],
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: Text(item['cliente'])),
                                Expanded(flex: 1, child: Text(item['numero'].toString())),
                                Expanded(flex: 2, child: Text(item['vencimento'] ?? '-')),
                                Expanded(flex: 2, child: Text(formatador.format(item['capital']))),
                                Expanded(flex: 2, child: Text(formatador.format(item['juros']))),
                                Expanded(flex: 2, child: Text(formatador.format(item['total']))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),

        if (relatorio.isNotEmpty)
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Text("Totais:", style: TextStyle(fontWeight: FontWeight.bold))),
                const Expanded(flex: 1, child: SizedBox()),
                const Expanded(flex: 2, child: SizedBox()),
                Expanded(flex: 2, child: Text(formatador.format(totalCapital), style: const TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text(formatador.format(totalJuros), style: const TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text(formatador.format(totalGeral), style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),

        // ✅ LEGENDA PADRONIZADA (igual ao relatorio1)
        if (relatorio.isNotEmpty)
          Container(
            color: Colors.orange[50],
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total de parcelas vencidas: ${relatorio.length}",
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
                Text(
                  "Atualizado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}",
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ],
            ),
          ),
      ],
    );
  }
}