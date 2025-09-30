import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🔹 Abre o diálogo de acordo (adiamento da parcela)
Future<void> abrirAcordoDialog(BuildContext context, Map<String, dynamic> parcela) async {
  final comentarioCtrl = TextEditingController(text: parcela["comentario"] ?? "");
  DateTime? dataPrevista = parcela["data_prevista"] != null &&
          parcela["data_prevista"].toString().isNotEmpty
      ? DateFormat("dd/MM/yyyy").parse(parcela["data_prevista"])
      : null;

  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("🤝 Fazer acordo"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: comentarioCtrl,
            maxLength: 100,
            decoration: const InputDecoration(labelText: "Comentário"),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: dataPrevista ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                dataPrevista = picked;
              }
            },
            child: Text(
              dataPrevista == null
                  ? "Selecionar data prevista"
                  : DateFormat("dd/MM/yyyy").format(dataPrevista!),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        if (parcela["data_prevista"] != null &&
            parcela["data_prevista"].toString().isNotEmpty)
          TextButton(
            onPressed: () async {
              await Supabase.instance.client
                  .from("parcelas")
                  .update({"data_prevista": null, "comentario": null})
                  .eq("id", parcela["id"]);
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Acordo excluído!")),
              );
            },
            child: const Text("Excluir acordo",
                style: TextStyle(color: Colors.red)),
          ),
        ElevatedButton(
          onPressed: () async {
            if (dataPrevista == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Escolha uma data prevista.")),
              );
              return;
            }
            await Supabase.instance.client
                .from("parcelas")
                .update({
                  "data_prevista": DateFormat("dd/MM/yyyy").format(dataPrevista!),
                  "comentario": comentarioCtrl.text,
                })
                .eq("id", parcela["id"]);
            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Acordo salvo com sucesso!")),
            );
          },
          child: const Text("Salvar acordo"),
        ),
      ],
    ),
  );
}
