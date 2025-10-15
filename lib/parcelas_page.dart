import 'package:flutter/material.dart';
import 'parcelas_service.dart';
import 'parcelas_table.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils.dart';

class ParcelasPage extends StatefulWidget {
  final Map<String, dynamic> emprestimo;
  final VoidCallback onSaved; // ✅ callback para atualizar o Financeiro

  const ParcelasPage({
    super.key,
    required this.emprestimo,
    required this.onSaved,
  });

  @override
  State<ParcelasPage> createState() => ParcelasPageState();
}

class ParcelasPageState extends State<ParcelasPage> {
  late Future<List<Map<String, dynamic>>> _parcelasFuture;
  final ParcelasService service = ParcelasService();

  // chave para acessar métodos do ParcelasTable
  final GlobalKey<ParcelasTableState> _tableKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _parcelasFuture = service.buscarParcelas(
      widget.emprestimo['id'] ?? widget.emprestimo['id_emprestimo'],
    );
    //_carregarNomeCliente();
  }

  /*Future<void> _carregarNomeCliente() async {
    try {
      final idCliente = widget.emprestimo['id_cliente'];
      if (idCliente == null) return;

      final response = await Supabase.instance.client
          .from('clientes')
          .select('nome')
          .eq('id', idCliente)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          widget.emprestimo['cliente'] = response['nome'];
        });
      }
    } catch (e) {
      print('Erro ao carregar nome do cliente: $e');
    }
  }
  */

  /// 🔹 Torna público para ser acessado pela ParcelasTable
  Future<void> atualizarParcelas() async {
    setState(() {
      _parcelasFuture = service.buscarParcelas(
        widget.emprestimo['id'] ?? widget.emprestimo['id_emprestimo'],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    //final cliente = widget.emprestimo["cliente"] ?? "";
    final numero = widget.emprestimo["numero"] ?? "";
    final dataInicio = formatarData(widget.emprestimo["data_inicio"]);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        centerTitle: true,
        title: Text(
          "Empréstimo Nº ${widget.emprestimo["numero"] ?? ""} - ${widget.emprestimo["cliente"] ?? "Cliente"} - Parcelamento",
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Voltar para o financeiro',
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text(
                    "Cuidado!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  content: const Text(
                    "Deseja sair sem salvar?",
                    textAlign: TextAlign.center,
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    // 🔸 Botão vermelho - sair sem salvar
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(); // fecha o diálogo
                        Navigator.pop(context, {'atualizar': true, 'cliente': widget.emprestimo['cliente']});
                      },
                      icon: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        "Sim, sair sem salvar.",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),

                    // 🔸 Botão cinza - cancelar
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(); // fecha o diálogo e permanece
                      },
                      child: const Text(
                        "Cancelar",
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),

            
      body: Container(
        color: const Color(0xFFFAF9F6),
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _parcelasFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Erro: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final parcelasList = snapshot.data ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Resumo do empréstimo
                Text(
                  "Nº $numero   |   Data do empréstimo: $dataInicio\n"
                  "Capital: ${service.fmtMoeda2(widget.emprestimo['valor'])}   |   "
                  "Juros: ${service.fmtMoeda2(widget.emprestimo['juros'])}   |   "
                  "Montante: ${service.fmtMoeda2(widget.emprestimo['valor'] + widget.emprestimo['juros'])}   |   "
                  "Parcela: ${service.fmtMoeda2(widget.emprestimo['prestacao'])}",
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
                const SizedBox(height: 12),

                // 🔹 Tabela de parcelas
                if (parcelasList.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Nenhuma parcela encontrada.",
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ParcelasTable(
                      key: _tableKey,
                      emprestimo: widget.emprestimo,
                      parcelas: parcelasList,
                    ),
                  ),

                const SizedBox(height: 12),

                // 🔹 Botões inferiores
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final confirmar = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Arquivar Empréstimo"),
                            content: const Text(
                              "Tem certeza que deseja arquivar este empréstimo?\n\n"
                              "O empréstimo será movido para a aba de arquivados.",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text("Cancelar"),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text("Arquivar"),
                              ),
                            ],
                          ),
                        );

                        if (confirmar == true) {
                          try {
                            await Supabase.instance.client
                                .from('emprestimos')
                                .update({'ativo': 'nao'})
                                .eq('id', widget.emprestimo['id']);

                            if (!mounted) return;

                            await showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                content: const Text(
                                  "Empréstimo arquivado com sucesso!",
                                  textAlign: TextAlign.center,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      Navigator.pop(context, true);
                                    },
                                    child: const Text("OK"),
                                  ),
                                ],
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            await showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                content: Text(
                                  "Erro ao arquivar: $e",
                                  textAlign: TextAlign.center,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text("OK"),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.archive),
                      label: const Text("Arquivar Empréstimo"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await _tableKey.currentState?.salvarParcelas();

                        if (ok == null) return;
                        if (ok == false && mounted) return;

                        if (ok == true && mounted) {
                          await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              content: const Text(
                                "Parcelas salvas com sucesso",
                                textAlign: TextAlign.center,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("OK"),
                                ),
                              ],
                            ),
                          );

                          // ✅ Atualiza o Financeiro imediatamente
                          widget.onSaved();

                          // ✅ Volta à tela anterior (Financeiro)
                          Navigator.pop(context, true);
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: const Text("Salvar Parcelas"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
