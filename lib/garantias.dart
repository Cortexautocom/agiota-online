import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils.dart';
import 'package:uuid/uuid.dart';

class GarantiasPage extends StatefulWidget {
  final Map<String, dynamic> cliente;

  const GarantiasPage({super.key, required this.cliente});

  @override
  State<GarantiasPage> createState() => _GarantiasPageState();
}

class _GarantiasPageState extends State<GarantiasPage> {
  late Future<List<Map<String, dynamic>>> _garantiasFuture;

  @override
  void initState() {
    super.initState();
    _garantiasFuture = _buscarGarantias();
  }

  Future<List<Map<String, dynamic>>> _buscarGarantias() async {
    final response = await Supabase.instance.client
        .from('garantias')
        .select()
        .eq('id_cliente', widget.cliente['id_cliente'])
        .order('numero', ascending: true);

    return (response as List).map((e) => e as Map<String, dynamic>).toList();
  }

  Future<void> _adicionarGarantia() async {
    final descricaoController = TextEditingController();
    final valorController = TextEditingController();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nova Garantia"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descricaoController,
              decoration: const InputDecoration(
                labelText: "Descrição",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valorController,
              decoration: const InputDecoration(
                labelText: "Valor",
                border: OutlineInputBorder(),
                prefixText: "R\$ ",
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              if (descricaoController.text.isEmpty || valorController.text.isEmpty) {
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );

    if (resultado == true) {
      final uuid = Uuid(); // 👈 ADICIONE ESTA LINHA
      
      final novaGarantia = {
        "id": uuid.v4(), // 👈 GERE O UUID AQUI
        "id_cliente": widget.cliente['id_cliente'],
        "descricao": descricaoController.text,
        "valor": valorController.text,
        "id_usuario": Supabase.instance.client.auth.currentUser!.id,
      };

      try {
        await Supabase.instance.client
            .from('garantias')
            .insert(novaGarantia);

        if (!mounted) return;
        
        setState(() {
          _garantiasFuture = _buscarGarantias();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Garantia adicionada com sucesso!")),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao adicionar garantia: $e")),
        );
      }
    }
  }

  Future<void> _excluirGarantia(Map<String, dynamic> garantia) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Excluir Garantia"),
        content: const Text("Tem certeza que deseja excluir esta garantia?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await Supabase.instance.client
            .from('garantias')
            .delete()
            .eq('id', garantia['id']);

        if (!mounted) return;
        
        setState(() {
          _garantiasFuture = _buscarGarantias();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Garantia excluída com sucesso!")),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao excluir garantia: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Garantias - ${widget.cliente['nome']}"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionarGarantia,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Container(
        color: const Color(0xFFFAF9F6),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Garantias do Cliente",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _garantiasFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Erro ao carregar garantias: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final garantias = snapshot.data ?? [];
                  if (garantias.isEmpty) {
                    return const Center(
                      child: Text(
                        "Nenhuma garantia cadastrada.",
                        style: TextStyle(color: Colors.black54),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columnSpacing: 20,
                        headingRowColor: MaterialStateProperty.all(Colors.grey[300]),
                        headingTextStyle: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                        dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                          (Set<MaterialState> states) {
                            // Linhas cinza claro alternadas
                            return Colors.grey[100];
                          },
                        ),
                        columns: const [
                          DataColumn(
                            label: SizedBox(
                              width: 60,
                              child: Text("Nº", textAlign: TextAlign.center),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 300,
                              child: Text("Descrição"),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 150,
                              child: Text("Valor", textAlign: TextAlign.right),
                            ),
                          ),
                          DataColumn(
                            label: SizedBox(
                              width: 80,
                              child: Text("Ações", textAlign: TextAlign.center),
                            ),
                          ),
                        ],
                        rows: garantias.map((garantia) {
                          return DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 60,
                                  child: Center(
                                    child: Text(
                                      "${garantia['numero'] ?? ''}",
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 300,
                                  child: Text(
                                    garantia['descricao'] ?? '',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 150,
                                  child: Text(
                                    fmtMoeda(garantia['valor']),
                                    style: const TextStyle(fontSize: 14),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 80,
                                  child: Center(
                                    child: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: () => _excluirGarantia(garantia),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}