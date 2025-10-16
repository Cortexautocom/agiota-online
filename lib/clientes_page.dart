import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'financeiro.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'editar_cliente_page.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  late Future<List<Map<String, dynamic>>> _clientesFuture;
  final TextEditingController _pesquisaController = TextEditingController();
  List<Map<String, dynamic>> _clientesFiltrados = [];
  List<Map<String, dynamic>> _todosClientes = [];

  @override
  void initState() {
    super.initState();
    _clientesFuture = _buscarClientes();
    _pesquisaController.addListener(_filtrarClientes);
  }

  @override
  void dispose() {
    _pesquisaController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _buscarClientes() async {
    final response = await Supabase.instance.client
        .from('clientes')
        .select()
        .order('nome', ascending: true);

    final clientes = (response as List).map((e) => e as Map<String, dynamic>).toList();

    _todosClientes = clientes;
    _clientesFiltrados = List.from(_todosClientes);

    return clientes;
  }

  void _filtrarClientes() {
    final termoPesquisa = _pesquisaController.text.toLowerCase().trim();

    setState(() {
      if (termoPesquisa.isEmpty) {
        _clientesFiltrados = List.from(_todosClientes);
      } else {
        _clientesFiltrados = _todosClientes.where((cliente) {
          final nome = cliente['nome']?.toString().toLowerCase() ?? '';
          final cpf = cliente['cpf']?.toString().toLowerCase() ?? '';
          final cidade = cliente['cidade']?.toString().toLowerCase() ?? '';
          final grupo = cliente['grupo']?.toString().toLowerCase() ?? '';

          return nome.contains(termoPesquisa) ||
              cpf.contains(termoPesquisa) ||
              cidade.contains(termoPesquisa) ||
              grupo.contains(termoPesquisa);
        }).toList();
      }
    });
  }

  void _recarregarClientes() {
    setState(() {
      _clientesFuture = _buscarClientes().then((clientes) {
        _filtrarClientes();
        return clientes;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: const Color(0xFFFAF9F6),
          child: Column(
            children: [
              // 🔹 Campo de pesquisa
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: TextField(
                  controller: _pesquisaController,
                  decoration: InputDecoration(
                    hintText: "Pesquisar cliente por nome, CPF, cidade ou grupo...",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                ),
              ),

              // 🔹 Contador de resultados
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey[100],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _clientesFuture,
                      builder: (context, snapshot) {
                        final totalClientes = _todosClientes.length;
                        final clientesExibidos = _clientesFiltrados.length;

                        return Text(
                          "Exibindo $clientesExibidos de $totalClientes clientes",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                    if (_pesquisaController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _pesquisaController.clear();
                        },
                        tooltip: "Limpar pesquisa",
                      ),
                  ],
                ),
              ),

              // 🔹 Lista de clientes
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _clientesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "Erro ao carregar: ${snapshot.error}",
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final clientes = _clientesFiltrados;

                    if (clientes.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _pesquisaController.text.isEmpty
                                  ? Icons.people_outline
                                  : Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _pesquisaController.text.isEmpty
                                  ? "Nenhum cliente encontrado."
                                  : "Nenhum cliente encontrado para '${_pesquisaController.text}'",
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_pesquisaController.text.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  _pesquisaController.clear();
                                },
                                child: const Text("Limpar pesquisa"),
                              ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: clientes.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 8, color: Colors.black26),
                      itemBuilder: (context, index) {
                        final cliente = clientes[index];
                        return Card(
                          color: Colors.white,
                          child: ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.person,
                              size: 22,
                              color: Colors.black87,
                            ),
                            title: Text(
                              cliente['nome'] ?? 'Sem nome',
                              style: const TextStyle(color: Colors.black87),
                            ),
                            subtitle: Text(
                              "CPF: ${cliente['cpf'] ?? '-'} | Cidade: ${cliente['cidade'] ?? '-'} | Grupo: ${cliente['grupo'] ?? 'Sem grupo'}",
                              style: const TextStyle(color: Colors.black54),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      FinanceiroPage(cliente: cliente),
                                ),
                              );
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: "Editar cliente",
                              onPressed: () async {
                                final resultado = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditarClientePage(cliente: cliente),
                                  ),
                                );

                                if (resultado == true) {
                                  _recarregarClientes();
                                }
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // 🔹 Botão flutuante
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () async {
              final novoCliente = await open_client_form(context);
              if (novoCliente != null) {
                await Supabase.instance.client
                    .from('clientes')
                    .insert(novoCliente);
                _recarregarClientes();
              }
            },
            backgroundColor: Colors.green,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// 🔹 Formulário de novo cliente com campo de grupo
Future<Map<String, dynamic>?> open_client_form(BuildContext context) async {
  final nomeController = TextEditingController();
  final cpfController = TextEditingController();
  final telefoneController = TextEditingController();
  final enderecoController = TextEditingController();
  final cidadeController = TextEditingController();
  final indicacaoController = TextEditingController();

  String? grupoSelecionado;
  List<String> grupos = [];

  final cpfFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) # ####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  // 🔹 Buscar grupos existentes
  final response = await Supabase.instance.client
      .from('clientes')
      .select('grupo')
      .not('grupo', 'is', null)
      .neq('grupo', '')
      .order('grupo', ascending: true);

  grupos = (response as List)
      .map((e) => e['grupo']?.toString() ?? '')
      .where((g) => g.isNotEmpty)
      .toSet()
      .toList();

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Novo Cliente"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nomeController,
                    decoration: const InputDecoration(labelText: "Nome"),
                  ),
                  TextField(
                    controller: cpfController,
                    decoration: const InputDecoration(labelText: "CPF"),
                    keyboardType: TextInputType.number,
                    inputFormatters: [cpfFormatter],
                  ),
                  TextField(
                    controller: telefoneController,
                    decoration: const InputDecoration(labelText: "Telefone"),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [telefoneFormatter],
                  ),
                  TextField(
                    controller: enderecoController,
                    decoration: const InputDecoration(labelText: "Endereço"),
                  ),
                  TextField(
                    controller: cidadeController,
                    decoration: const InputDecoration(labelText: "Cidade"),
                  ),
                  TextField(
                    controller: indicacaoController,
                    decoration: const InputDecoration(labelText: "Indicação"),
                  ),
                  const SizedBox(height: 10),

                  // 🔹 Campo de grupo
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Grupo"),
                    value: grupoSelecionado,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text("Sem grupo"),
                      ),
                      ...grupos.map((g) => DropdownMenuItem<String>(
                            value: g,
                            child: Text(g),
                          )),
                      const DropdownMenuItem<String>(
                        value: "__novo__",
                        child: Text("➕ Criar novo grupo"),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == "__novo__") {
                        final novoGrupo = await _criarNovoGrupo(context);
                        if (novoGrupo != null && novoGrupo.isNotEmpty) {
                          setState(() {
                            grupos.add(novoGrupo);
                            grupoSelecionado = novoGrupo;
                          });
                        }
                      } else {
                        setState(() {
                          grupoSelecionado = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () {
                  final novoCliente = {
                    "nome": nomeController.text,
                    "cpf": cpfController.text,
                    "telefone": telefoneController.text,
                    "endereco": enderecoController.text,
                    "cidade": cidadeController.text,
                    "indicacao": indicacaoController.text,
                    "grupo": grupoSelecionado,
                    "id_usuario": Supabase.instance.client.auth.currentUser!.id,
                  };
                  Navigator.pop(context, novoCliente);
                },
                child: const Text("Salvar"),
              ),
            ],
          );
        },
      );
    },
  );
}

// 🔹 Função auxiliar para criar novo grupo
Future<String?> _criarNovoGrupo(BuildContext context) async {
  final grupoController = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Novo Grupo"),
        content: TextField(
          controller: grupoController,
          decoration: const InputDecoration(labelText: "Nome do grupo"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, grupoController.text.trim());
            },
            child: const Text("Salvar"),
          ),
        ],
      );
    },
  );
}
