import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parcelas_page.dart';

class RelatorioParcelasEmAberto extends StatefulWidget {
  final TextEditingController dataInicioCtrl;
  final TextEditingController dataFimCtrl;
  final ValueNotifier<bool> refreshNotifier;
  final bool filtroParcelamento;
  final bool filtroAmortizacao;

  const RelatorioParcelasEmAberto({
    super.key,
    required this.dataInicioCtrl,
    required this.dataFimCtrl,
    required this.refreshNotifier,
    required this.filtroParcelamento,
    required this.filtroAmortizacao,
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
    widget.refreshNotifier.addListener(_onRefreshRequested);
  }

  @override
  void dispose() {
    widget.refreshNotifier.removeListener(_onRefreshRequested);
    super.dispose();
  }

  void _onRefreshRequested() {
    _buscarParcelasEmAberto();
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

  Future<void> _buscarParcelasEmAberto() async {
    if (!mounted) return;
    setState(() => carregando = true);

    try {
      final supabase = Supabase.instance.client;

      final dataInicio = _parseDataFiltro(widget.dataInicioCtrl.text);
      final dataFim = _parseDataFiltro(widget.dataFimCtrl.text);

      // 🟢 --- 1️⃣ Parcelamento (usa a view normalmente)
      final viewResponse = await supabase
          .from('vw_parcelas_detalhes')
          .select('''
            id,
            id_emprestimo,
            numero,
            valor,
            juros,
            residual,
            vencimento,
            cliente,
            ativo,
            capital_total,
            juros_total,
            qtd_parcelas,
            tipo_mov
          ''')
          .eq('ativo', 'sim')
          .order('cliente', ascending: true)
          .order('vencimento', ascending: true);

      final parcelasParcelamento = viewResponse.where((p) {
        final tipo = (p['tipo_mov'] ?? '').toString().toLowerCase().trim();
        final venc = DateTime.tryParse(p['vencimento'] ?? '');
        if (tipo != 'parcelamento' || venc == null) return false;
        if (dataInicio != null && venc.isBefore(dataInicio)) return false;
        if (dataFim != null && venc.isAfter(dataFim)) return false;
        return (p['residual'] ?? 0).toDouble() > 1.00;
      }).map<Map<String, dynamic>>((p) {
        final capitalTotal = (p['capital_total'] ?? 0).toDouble();
        final jurosTotal = (p['juros_total'] ?? 0).toDouble();
        final qtdParcelas = (p['qtd_parcelas'] ?? 1).toDouble();
        final pgPrincipal = capitalTotal / qtdParcelas;
        final pgJuros = jurosTotal / qtdParcelas;
        final total = pgPrincipal + pgJuros;

        return {
          'id_emprestimo': p['id_emprestimo'],
          'cliente': p['cliente'] ?? 'Sem cliente',
          'numero': p['numero'],
          'vencimento': formatarData(p['vencimento']),
          'capital': pgPrincipal,
          'juros': pgJuros,
          'total': total,
        };
      }).toList();

      // 🟣 --- 2️⃣ Amortização (busca direto na tabela parcelas)
      final amortResponse = await supabase
          .from('parcelas')
          .select('''
            id,
            id_emprestimo,
            data_mov,
            pg,
            pg_principal,
            juros_periodo
          ''')
          .order('data_mov', ascending: true);

      // Buscar info dos empréstimos de amortização
      final emprestimosResponse = await supabase
          .from('emprestimos')
          .select('id, valor, tipo_mov, id_cliente')
          .eq('tipo_mov', 'amortizacao');

      // Buscar clientes
      final clientesResponse =
          await supabase.from('clientes').select('id_cliente, nome');

      final List<Map<String, dynamic>> parcelasAmortizacao = [];

      for (final emp in emprestimosResponse) {
        final idEmp = emp['id'];
        final tipo = (emp['tipo_mov'] ?? '').toString().toLowerCase().trim();
        if (tipo != 'amortizacao') continue;

        // 🔸 todas as parcelas vinculadas a esse empréstimo
        final parcelasDoEmp = amortResponse
            .where((p) => p['id_emprestimo'] == idEmp)
            .toList();

        if (parcelasDoEmp.isEmpty) continue;

        // 🔸 parcelas restantes (pg == 0)
        final parcelasRestantes =
            parcelasDoEmp.where((p) => (p['pg'] ?? 0) == 0).toList();

        if (parcelasRestantes.isEmpty) continue;

        parcelasRestantes.sort((a, b) {
          final da = DateTime.tryParse(a['data_mov'] ?? '') ?? DateTime(2100);
          final db = DateTime.tryParse(b['data_mov'] ?? '') ?? DateTime(2100);
          return da.compareTo(db);
        });

        // 🔸 cálculo do capital
        final totalAporte = (emp['valor'] ?? 0).toDouble();

        // soma de todos os pg_principal (inclusive pagos)
        final totalPagoPrincipal = parcelasDoEmp.fold<double>(
          0,
          (sum, p) => sum + ((p['pg_principal'] ?? 0).toDouble()),
        );

        final restantes = parcelasRestantes.length;
        final capitalRestante = totalAporte - totalPagoPrincipal;
        final capitalPorParcela =
            restantes > 0 ? capitalRestante / restantes : 0.0;

        // 🔸 Nome do cliente
        final cliente = clientesResponse.firstWhere(
          (c) => c['id_cliente'] == emp['id_cliente'],
          orElse: () => {'nome': 'Sem cliente'},
        );

        int contador = 1;
        for (final p in parcelasRestantes) {
          final dataMov = p['data_mov'];
          final jurosPeriodo = (p['juros_periodo'] ?? 0).toDouble();
          final total = capitalPorParcela + jurosPeriodo;

          parcelasAmortizacao.add({
            'id_emprestimo': idEmp,
            'cliente': cliente['nome'],
            'numero': contador++,
            'vencimento': formatarData(dataMov),
            'capital': capitalPorParcela,
            'juros': jurosPeriodo,
            'total': total,
          });
        }
      }

      // 🔹 Combina ambos os tipos
      List<Map<String, dynamic>> todos = [];

      if (widget.filtroParcelamento && !widget.filtroAmortizacao) {
        todos = [...parcelasParcelamento];
      } else if (!widget.filtroParcelamento && widget.filtroAmortizacao) {
        todos = [...parcelasAmortizacao];
      } else if (widget.filtroParcelamento && widget.filtroAmortizacao) {
        todos = [...parcelasParcelamento, ...parcelasAmortizacao];
      } else {
        // se nenhum filtro estiver marcado, mostra tudo
        todos = [...parcelasParcelamento, ...parcelasAmortizacao];
      }

      // 🔹 Ordena por cliente e data
      todos.sort((a, b) {
        final nomeA = (a['cliente'] ?? '').toString().toLowerCase();
        final nomeB = (b['cliente'] ?? '').toString().toLowerCase();
        final compNome = nomeA.compareTo(nomeB);
        if (compNome != 0) return compNome;

        final da = DateFormat('dd/MM/yyyy').parse(a['vencimento']);
        final db = DateFormat('dd/MM/yyyy').parse(b['vencimento']);
        return da.compareTo(db);
      });

      if (!mounted) return;
      setState(() => relatorio = todos);
    } catch (e) {
      if (mounted) setState(() => relatorio = []);
    } finally {
      if (mounted) setState(() => carregando = false);
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
        const Text("📄 Parcelas em aberto",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  ? const Center(child: Text("Nenhuma parcela em aberto encontrada."))
                  : ListView.builder(
                      itemCount: relatorio.length,
                      itemBuilder: (context, index) {
                        final item = relatorio[index];
                        return InkWell(
                          onTap: () {
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
                                  onSaved: () {},
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
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
        if (relatorio.isNotEmpty)
          Container(
            color: Colors.blue[50],
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Total de parcelas: ${relatorio.length}",
                    style: const TextStyle(fontSize: 12, color: Colors.blue)),
                Text("Atualizado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}",
                    style: const TextStyle(fontSize: 12, color: Colors.blue)),
              ],
            ),
          ),
      ],
    );
  }
}
