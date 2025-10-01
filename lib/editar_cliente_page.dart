import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditarClientePage extends StatefulWidget {
  final Map<String, dynamic> cliente;

  const EditarClientePage({super.key, required this.cliente});

  @override
  State<EditarClientePage> createState() => _EditarClientePageState();
}

class _EditarClientePageState extends State<EditarClientePage> {
  late TextEditingController nomeController;
  late TextEditingController cpfController;
  late TextEditingController telefoneController;
  late TextEditingController enderecoController;
  late TextEditingController cidadeController;
  late TextEditingController indicacaoController;

  final cpfFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) # ####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    nomeController = TextEditingController(text: widget.cliente['nome']);
    cpfController = TextEditingController(text: widget.cliente['cpf']);
    telefoneController = TextEditingController(text: widget.cliente['telefone']);
    enderecoController = TextEditingController(text: widget.cliente['endereco']);
    cidadeController = TextEditingController(text: widget.cliente['cidade']);
    indicacaoController = TextEditingController(text: widget.cliente['indicacao']);
  }

  Future<void> _salvarAlteracoes() async {
    final novoCliente = {
      "nome": nomeController.text,
      "cpf": cpfController.text,
      "telefone": telefoneController.text,
      "endereco": enderecoController.text,
      "cidade": cidadeController.text,
      "indicacao": indicacaoController.text,
      "id_usuario": widget.cliente['id_usuario'],
    };

    await Supabase.instance.client
        .from('clientes')
        .update(novoCliente)
        .eq('id_cliente', widget.cliente['id_cliente']);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Sucesso"),
        content: const Text("Informações salvas com sucesso"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // fecha diálogo
              Navigator.pop(context, true); // volta para lista
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _excluirCliente() async {
    final clienteId = widget.cliente['id_cliente'];

    // 🔹 Confirmação
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmação"),
        content: const Text(
          "Tem certeza que deseja excluir todos os registros do cliente do sistema?\n\n"
          "Esta exclusão será definitiva e irreversível.",
        ),
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

    if (confirmar != true) return;

    // 🔹 Verifica empréstimos ativos
    final emprestimosAtivos = await Supabase.instance.client
        .from('emprestimos')
        .select()
        .eq('id_cliente', clienteId)
        .eq('ativo', 'sim');

    if (emprestimosAtivos.isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Atenção"),
          content: const Text(
            "Este cliente não pode ser excluído, pois ainda possui empréstimos ativos",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    // 🔹 Verifica garantias vinculadas
    final garantias = await Supabase.instance.client
        .from('garantias')
        .select()
        .eq('id_cliente', clienteId);

    if (garantias.isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Atenção"),
          content: const Text(
            "Este cliente não pode ser excluído, pois ainda possui garantias cadastradas.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    // 🔹 Exclui parcelas de todos os empréstimos (inativos)
    final emprestimosTodos = await Supabase.instance.client
        .from('emprestimos')
        .select('id')
        .eq('id_cliente', clienteId);

    for (final emp in emprestimosTodos) {
      await Supabase.instance.client
          .from('parcelas')
          .delete()
          .eq('id_emprestimo', emp['id']);
    }

    // 🔹 Exclui empréstimos
    await Supabase.instance.client
        .from('emprestimos')
        .delete()
        .eq('id_cliente', clienteId);

    // 🔹 Exclui cliente
    await Supabase.instance.client
        .from('clientes')
        .delete()
        .eq('id_cliente', clienteId);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Sucesso"),
        content: const Text("Cliente excluído com sucesso"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // fecha diálogo
              Navigator.pop(context, true); // volta para lista
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Cliente"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
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
              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _salvarAlteracoes,
                    icon: const Icon(Icons.save),
                    label: const Text("Salvar alterações"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _excluirCliente,
                    icon: const Icon(Icons.delete),
                    label: const Text("Excluir cliente"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
