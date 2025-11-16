import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parcelas_page.dart'; // ✅ Import necessário para a navegação

class VisaoGeralPage extends StatefulWidget {
  const VisaoGeralPage({super.key});

  @override
  State<VisaoGeralPage> createState() => _VisaoGeralPageState();
}

class _VisaoGeralPageState extends State<VisaoGeralPage> {
  final _supabase = Supabase.instance.client;
  
  // Estados para parcelas em aberto
  bool _parcelasAbertasExpandidas = false;
  List<Map<String, dynamic>> _parcelasAbertas = [];
  bool _carregandoAbertas = false;
  int _totalParcelasAbertas = 0;
  double _valorTotalAberto = 0.0;
  
  // Estados para parcelas vencidas
  bool _parcelasVencidasExpandidas = false;
  List<Map<String, dynamic>> _parcelasVencidas = [];
  bool _carregandoVencidas = false;
  int _totalParcelasVencidas = 0;
  double _valorTotalVencido = 0.0;

  // Estados para parcelas com acordo vigente
  bool _parcelasAcordoExpandidas = false;
  List<Map<String, dynamic>> _parcelasAcordo = [];
  bool _carregandoAcordo = false;
  int _totalParcelasAcordo = 0;
  double _valorTotalAcordo = 0.0;

  @override
  void initState() {
    super.initState();
    _carregarParcelasAbertas();
    _carregarParcelasVencidas();
    _carregarParcelasComAcordo();
  }

  // 🔹 CARREGAR PARCELAS EM ABERTO
  Future<void> _carregarParcelasAbertas() async {
    if (!mounted) return;
    
    setState(() {
      _carregandoAbertas = true;
    });

    try {
      // 🟢 --- 1️⃣ Parcelamento (usa a view normalmente)
      final viewResponse = await _supabase
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

      final List<Map<String, dynamic>> parcelasParcelamento = [];
      
      for (final p in viewResponse) {
        try {
          final tipo = _getSafeString(p, 'tipo_mov').toLowerCase().trim();
          if (tipo != 'parcelamento') continue;
          
          final residual = _getSafeDouble(p, 'residual');
          if (residual <= 1.00) continue;

          final capitalTotal = _getSafeDouble(p, 'capital_total');
          final jurosTotal = _getSafeDouble(p, 'juros_total');
          final qtdParcelas = _getSafeDouble(p, 'qtd_parcelas');
          
          if (qtdParcelas == 0) continue;

          final pgPrincipal = capitalTotal / qtdParcelas;
          final pgJuros = jurosTotal / qtdParcelas;
          final total = pgPrincipal + pgJuros;

          parcelasParcelamento.add({
            'id_emprestimo': _getSafeString(p, 'id_emprestimo'),
            'cliente': _getSafeString(p, 'cliente', padrao: 'Sem cliente'),
            'numero': _getSafeInt(p, 'numero'),
            'vencimento': _formatarData(_getSafeString(p, 'vencimento')),
            'capital': pgPrincipal,
            'juros': pgJuros,
            'total': total,
          });
        } catch (e) {
          debugPrint('Erro ao processar parcela parcelamento: $e');
          continue;
        }
      }

      // 🟣 --- 2️⃣ Amortização (busca direto na tabela parcelas)
      final List<Map<String, dynamic>> parcelasAmortizacao = [];

      try {
        final amortResponse = await _supabase
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

        final emprestimosResponse = await _supabase
            .from('emprestimos')
            .select('id, valor, tipo_mov, id_cliente')
            .eq('tipo_mov', 'amortizacao');

        final clientesResponse =
            await _supabase.from('clientes').select('id_cliente, nome');

        for (final emp in emprestimosResponse) {
          try {
            final idEmp = _getSafeString(emp, 'id');
            final tipo = _getSafeString(emp, 'tipo_mov').toLowerCase().trim();
            if (tipo != 'amortizacao') continue;

            final parcelasDoEmp = amortResponse
                .where((p) => _getSafeString(p, 'id_emprestimo') == idEmp)
                .toList();

            if (parcelasDoEmp.isEmpty) continue;

            final parcelasRestantes =
                parcelasDoEmp.where((p) => _getSafeDouble(p, 'pg') == 0).toList();

            if (parcelasRestantes.isEmpty) continue;

            parcelasRestantes.sort((a, b) {
              final da = DateTime.tryParse(_getSafeString(a, 'data_mov')) ?? DateTime(2100);
              final db = DateTime.tryParse(_getSafeString(b, 'data_mov')) ?? DateTime(2100);
              return da.compareTo(db);
            });

            final totalAporte = _getSafeDouble(emp, 'valor');
            final totalPagoPrincipal = parcelasDoEmp.fold<double>(
              0,
              (sum, p) => sum + _getSafeDouble(p, 'pg_principal'),
            );

            final restantes = parcelasRestantes.length;
            final capitalRestante = totalAporte - totalPagoPrincipal;
            final capitalPorParcela = restantes > 0 ? capitalRestante / restantes : 0.0;

            final cliente = clientesResponse.firstWhere(
              (c) => _getSafeString(c, 'id_cliente') == _getSafeString(emp, 'id_cliente'),
              orElse: () => {'nome': 'Sem cliente'},
            );

            int contador = 1;
            for (final p in parcelasRestantes) {
              final dataMov = _getSafeString(p, 'data_mov');
              final jurosPeriodo = _getSafeDouble(p, 'juros_periodo');
              final total = capitalPorParcela + jurosPeriodo;

              parcelasAmortizacao.add({
                'id_emprestimo': idEmp,
                'cliente': _getSafeString(cliente, 'nome', padrao: 'Sem cliente'),
                'numero': contador++,
                'vencimento': _formatarData(dataMov),
                'capital': capitalPorParcela,
                'juros': jurosPeriodo,
                'total': total,
              });
            }
          } catch (e) {
            debugPrint('Erro ao processar empréstimo amortização: $e');
            continue;
          }
        }
      } catch (e) {
        debugPrint('Erro ao carregar amortização: $e');
      }

      // 🔹 Combina ambos os tipos
      final todos = [...parcelasParcelamento, ...parcelasAmortizacao];

      // 🔹 Ordena por cliente e data
      todos.sort((a, b) {
        final nomeA = _getSafeString(a, 'cliente').toLowerCase();
        final nomeB = _getSafeString(b, 'cliente').toLowerCase();
        final compNome = nomeA.compareTo(nomeB);
        if (compNome != 0) return compNome;

        try {
          final da = DateFormat('dd/MM/yyyy').parse(_getSafeString(a, 'vencimento'));
          final db = DateFormat('dd/MM/yyyy').parse(_getSafeString(b, 'vencimento'));
          return da.compareTo(db);
        } catch (_) {
          return 0;
        }
      });

      // 🔹 Calcula totais
      final totalParcelas = todos.length;
      final valorTotal = todos.fold(0.0, (s, e) => s + _getSafeDouble(e, 'total'));

      if (mounted) {
        setState(() {
          _parcelasAbertas = todos;
          _totalParcelasAbertas = totalParcelas;
          _valorTotalAberto = valorTotal;
        });
      }

    } catch (e) {
      debugPrint('Erro ao carregar parcelas em aberto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar parcelas em aberto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _carregandoAbertas = false);
      }
    }
  }

  // 🔹 CARREGAR PARCELAS VENCIDAS
  Future<void> _carregarParcelasVencidas() async {
    if (!mounted) return;
    
    setState(() {
      _carregandoVencidas = true;
    });

    try {
      final hoje = DateTime.now();

      final response = await _supabase
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
            qtd_parcelas,
            tipo_mov
          ''')
          .gt('residual', 1.00)
          .eq('ativo', 'sim')
          .order('cliente', ascending: true)
          .order('vencimento', ascending: true);

      final List<Map<String, dynamic>> filtradas = [];

      for (final p in response) {
        try {
          final vencStr = _getSafeString(p, 'vencimento');
          final venc = DateTime.tryParse(vencStr);
          if (venc == null) continue;

          // apenas vencidas
          if (!venc.isBefore(DateTime(hoje.year, hoje.month, hoje.day))) {
            continue;
          }

          // ignora parcelas com acordo
          if (_getSafeString(p, 'data_prevista').isNotEmpty) continue;

          filtradas.add(p);
        } catch (e) {
          debugPrint('Erro ao filtrar parcela vencida: $e');
          continue;
        }
      }

      // 🔹 Ordena
      filtradas.sort((a, b) {
        final nomeA = _getSafeString(a, 'cliente').toLowerCase();
        final nomeB = _getSafeString(b, 'cliente').toLowerCase();
        final compNome = nomeA.compareTo(nomeB);
        if (compNome != 0) return compNome;
        
        final da = DateTime.tryParse(_getSafeString(a, 'vencimento')) ?? DateTime(2100);
        final db = DateTime.tryParse(_getSafeString(b, 'vencimento')) ?? DateTime(2100);
        return da.compareTo(db);
      });

      // 🔹 Monta as parcelas
      final List<Map<String, dynamic>> parcelasProcessadas = [];

      for (final p in filtradas) {
        try {
          final nomeCliente = _getSafeString(p, 'cliente', padrao: 'Sem cliente');
          final tipoMov = _getSafeString(p, 'tipo_mov', padrao: 'parcelamento');

          final capitalTotal = _getSafeDouble(p, 'capital_total');
          final jurosTotal = _getSafeDouble(p, 'juros_total');
          final qtdParcelas = _getSafeDouble(p, 'qtd_parcelas');
          final numeroParcela = _getSafeDouble(p, 'numero');

          double pgPrincipal = 0;
          double pgJuros = 0;

          if (tipoMov == 'parcelamento') {
            pgPrincipal = capitalTotal / qtdParcelas;
            pgJuros = jurosTotal / qtdParcelas;
          } else if (tipoMov == 'amortizacao') {
            final saldoDevedor = capitalTotal - ((numeroParcela - 1) * (capitalTotal / qtdParcelas));
            final taxaJuros = jurosTotal / capitalTotal;
            pgJuros = saldoDevedor * taxaJuros;
            pgPrincipal = capitalTotal / qtdParcelas;
          }

          final total = pgPrincipal + pgJuros;

          parcelasProcessadas.add({
            'id_emprestimo': _getSafeString(p, 'id_emprestimo'),
            'cliente': nomeCliente,
            'numero': _getSafeInt(p, 'numero'),
            'vencimento': _formatarData(_getSafeString(p, 'vencimento')),
            'capital': pgPrincipal,
            'juros': pgJuros,
            'total': total,
            'tipo_mov': tipoMov,
          });
        } catch (e) {
          debugPrint('Erro ao processar parcela vencida: $e');
          continue;
        }
      }

      // 🔹 Calcula totais
      final totalParcelas = parcelasProcessadas.length;
      final valorTotal = parcelasProcessadas.fold(0.0, (s, e) => s + _getSafeDouble(e, 'total'));

      if (mounted) {
        setState(() {
          _parcelasVencidas = parcelasProcessadas;
          _totalParcelasVencidas = totalParcelas;
          _valorTotalVencido = valorTotal;
        });
      }

    } catch (e) {
      debugPrint('Erro ao carregar parcelas vencidas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar parcelas vencidas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _carregandoVencidas = false);
      }
    }
  }

  // 🔹 CARREGAR PARCELAS COM ACORDO VIGENTE
  Future<void> _carregarParcelasComAcordo() async {
    if (!mounted) return;
    
    setState(() {
      _carregandoAcordo = true;
    });

    try {
      final response = await _supabase
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
          .not('data_prevista', 'is', null)
          .order('cliente', ascending: true)
          .order('vencimento', ascending: true);

      final List<Map<String, dynamic>> parcelasProcessadas = [];

      for (final p in response) {
        try {
          final nomeCliente = _getSafeString(p, 'cliente', padrao: 'Sem cliente');
          final capitalTotal = _getSafeDouble(p, 'capital_total');
          final jurosSupabase = _getSafeDouble(p, 'juros_total');
          final qtdParcelas = _getSafeDouble(p, 'qtd_parcelas');

          if (qtdParcelas == 0) continue;

          final pgPrincipal = capitalTotal / qtdParcelas;
          final pgJuros = jurosSupabase / qtdParcelas;
          final total = pgPrincipal + pgJuros;

          parcelasProcessadas.add({
            'id_emprestimo': _getSafeString(p, 'id_emprestimo'),
            'cliente': nomeCliente,
            'numero': _getSafeInt(p, 'numero'),
            'vencimento': _formatarData(_getSafeString(p, 'vencimento')),
            'data_prevista': _formatarData(_getSafeString(p, 'data_prevista')),
            'capital': pgPrincipal,
            'juros': pgJuros,
            'total': total,
          });
        } catch (e) {
          debugPrint('Erro ao processar parcela com acordo: $e');
          continue;
        }
      }

      // 🔹 Ordena por cliente e data
      parcelasProcessadas.sort((a, b) {
        final nomeA = _getSafeString(a, 'cliente').toLowerCase();
        final nomeB = _getSafeString(b, 'cliente').toLowerCase();
        final compNome = nomeA.compareTo(nomeB);
        if (compNome != 0) return compNome;

        final da = DateTime.tryParse(_getSafeString(a, 'vencimento')) ?? DateTime(2100);
        final db = DateTime.tryParse(_getSafeString(b, 'vencimento')) ?? DateTime(2100);
        return da.compareTo(db);
      });

      // 🔹 Calcula totais
      final totalParcelas = parcelasProcessadas.length;
      final valorTotal = parcelasProcessadas.fold(0.0, (s, e) => s + _getSafeDouble(e, 'total'));

      if (mounted) {
        setState(() {
          _parcelasAcordo = parcelasProcessadas;
          _totalParcelasAcordo = totalParcelas;
          _valorTotalAcordo = valorTotal;
        });
      }

    } catch (e) {
      debugPrint('Erro ao carregar parcelas com acordo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar parcelas com acordo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _carregandoAcordo = false);
      }
    }
  }

  // 🔹 FUNÇÕES AUXILIARES PARA ACESSO SEGURO A DADOS
  String _getSafeString(Map<String, dynamic> map, String key, {String padrao = ''}) {
    try {
      final value = map[key];
      if (value == null) return padrao;
      return value.toString();
    } catch (e) {
      return padrao;
    }
  }

  double _getSafeDouble(Map<String, dynamic> map, String key, {double padrao = 0.0}) {
    try {
      final value = map[key];
      if (value == null) return padrao;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? padrao;
      return padrao;
    } catch (e) {
      return padrao;
    }
  }

  int _getSafeInt(Map<String, dynamic> map, String key, {int padrao = 0}) {
    try {
      final value = map[key];
      if (value == null) return padrao;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? padrao;
      return padrao;
    } catch (e) {
      return padrao;
    }
  }

  String _formatarData(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return '';
    }
  }

  // 🔹 NAVEGAÇÃO PARA A TELA DE PARCELAS
  void _navegarParaParcelas(Map<String, dynamic> parcela) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParcelasPage(
          emprestimo: {
            'id': parcela['id_emprestimo'],
            'cliente': parcela['cliente'],
            'numero': parcela['numero'],
            'valor': parcela['capital'] ?? 0,
            'juros': parcela['juros'] ?? 0,
            'prestacao': parcela['total'] ?? 0,
            'data_inicio': parcela['vencimento'],
            'id_usuario': _supabase.auth.currentUser?.id ?? '',
          },
          onSaved: () {
            // ✅ Recarrega os dados quando volta da tela de parcelas
            _carregarParcelasAbertas();
            _carregarParcelasVencidas();
            _carregarParcelasComAcordo();
          },
        ),
      ),
    );
  }

  void _toggleExpandirAbertas() {
    setState(() {
      _parcelasAbertasExpandidas = !_parcelasAbertasExpandidas;
    });
  }

  void _toggleExpandirVencidas() {
    setState(() {
      _parcelasVencidasExpandidas = !_parcelasVencidasExpandidas;
    });
  }

  void _toggleExpandirAcordo() {
    setState(() {
      _parcelasAcordoExpandidas = !_parcelasAcordoExpandidas;
    });
  }

  Widget _buildCardParcelasAbertas() {
    final formatador = NumberFormat.currency(locale: "pt_BR", symbol: "R\$");

    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.trending_up, color: Colors.green),
            title: Text(
              '$_totalParcelasAbertas parcelas em aberto',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Total: ${formatador.format(_valorTotalAberto)}',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              _parcelasAbertasExpandidas ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey[600],
            ),
            onTap: _toggleExpandirAbertas,
          ),

          if (_parcelasAbertasExpandidas) ...[
            const Divider(height: 1),
            
            if (_carregandoAbertas)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_parcelasAbertas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, size: 50, color: Colors.green),
                    SizedBox(height: 10),
                    Text(
                      "Nenhuma parcela em aberto encontrada!",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  Container(
                    color: Colors.grey[100],
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: const Row(
                      children: [
                        Expanded(flex: 3, child: Text("Cliente", style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text("Nº", style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text("Vencimento", style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text("Total", style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),

                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _parcelasAbertas.length,
                      itemBuilder: (context, index) {
                        final parcela = _parcelasAbertas[index];
                        return InkWell(
                          onTap: () => _navegarParaParcelas(parcela),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                              color: index.isEven ? Colors.white : Colors.grey[50],
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: Text(_getSafeString(parcela, 'cliente'))),
                                Expanded(flex: 1, child: Text(_getSafeString(parcela, 'numero'))),
                                Expanded(flex: 2, child: Text(_getSafeString(parcela, 'vencimento'))),
                                Expanded(flex: 2, child: Text(formatador.format(_getSafeDouble(parcela, 'total')))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  Container(
                    color: Colors.green[50],
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total: ${formatador.format(_valorTotalAberto)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          "Atualizado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardParcelasVencidas() {
    final formatador = NumberFormat.currency(locale: "pt_BR", symbol: "R\$");

    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.warning, color: Colors.orange),
            title: Text(
              '$_totalParcelasVencidas parcelas vencidas',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Total: ${formatador.format(_valorTotalVencido)}',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              _parcelasVencidasExpandidas ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey[600],
            ),
            onTap: _toggleExpandirVencidas,
          ),

          if (_parcelasVencidasExpandidas) ...[
            const Divider(height: 1),
            
            if (_carregandoVencidas)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_parcelasVencidas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, size: 50, color: Colors.green),
                    SizedBox(height: 10),
                    Text(
                      "Nenhuma parcela vencida encontrada!",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  Container(
                    color: Colors.grey[100],
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: const Row(
                      children: [
                        Expanded(flex: 3, child: Text("Cliente", style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text("Nº", style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text("Vencimento", style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text("Total", style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),

                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _parcelasVencidas.length,
                      itemBuilder: (context, index) {
                        final parcela = _parcelasVencidas[index];
                        return InkWell(
                          onTap: () => _navegarParaParcelas(parcela),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                              color: index.isEven ? Colors.white : Colors.grey[50],
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: Text(_getSafeString(parcela, 'cliente'))),
                                Expanded(flex: 1, child: Text(_getSafeString(parcela, 'numero'))),
                                Expanded(flex: 2, child: Text(_getSafeString(parcela, 'vencimento'))),
                                Expanded(flex: 2, child: Text(formatador.format(_getSafeDouble(parcela, 'total')))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  Container(
                    color: Colors.orange[50],
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total: ${formatador.format(_valorTotalVencido)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        Text(
                          "Atualizado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardParcelasComAcordo() {
    final formatador = NumberFormat.currency(locale: "pt_BR", symbol: "R\$");

    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.handshake, color: Colors.purple),
            title: Text(
              '$_totalParcelasAcordo parcelas com acordo vigente',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Total: ${formatador.format(_valorTotalAcordo)}',
              style: const TextStyle(
                color: Colors.purple,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              _parcelasAcordoExpandidas ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey[600],
            ),
            onTap: _toggleExpandirAcordo,
          ),

          if (_parcelasAcordoExpandidas) ...[
            const Divider(height: 1),
            
            if (_carregandoAcordo)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_parcelasAcordo.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.handshake, size: 50, color: Colors.purple),
                    SizedBox(height: 10),
                    Text(
                      "Nenhuma parcela com acordo vigente encontrada!",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  Container(
                    color: Colors.grey[100],
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: const Row(
                      children: [
                        Expanded(flex: 3, child: Text("Cliente", style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text("Nº", style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text("Vencimento", style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text("Data prevista", style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text("Total", style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),

                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _parcelasAcordo.length,
                      itemBuilder: (context, index) {
                        final parcela = _parcelasAcordo[index];
                        return InkWell(
                          onTap: () => _navegarParaParcelas(parcela),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                              color: index.isEven ? Colors.white : Colors.grey[50],
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: Text(_getSafeString(parcela, 'cliente'))),
                                Expanded(flex: 1, child: Text(_getSafeString(parcela, 'numero'))),
                                Expanded(flex: 2, child: Text(_getSafeString(parcela, 'vencimento'))),
                                Expanded(
                                  flex: 2, 
                                  child: Text(
                                    _getSafeString(parcela, 'data_prevista'),
                                    style: TextStyle(
                                      color: Colors.purple[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(flex: 2, child: Text(formatador.format(_getSafeDouble(parcela, 'total')))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  Container(
                    color: Colors.purple[50],
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total: ${formatador.format(_valorTotalAcordo)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                        Text(
                          "Atualizado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _atualizarTudo() async {
    await _carregarParcelasAbertas();
    await _carregarParcelasVencidas();
    await _carregarParcelasComAcordo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'Visão Geral',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C2331),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Resumo completo do seu negócio',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),

            _buildCardParcelasAbertas(),
            _buildCardParcelasVencidas(),
            _buildCardParcelasComAcordo(),

            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Mais informações em breve...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _atualizarTudo,
        backgroundColor: const Color(0xFF2196F3),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}