import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parcelas_service.dart'; // 👈 importamos para usar a máscara

/// 🔹 Abre o diálogo de acordo (adiamento da parcela)
Future<void> abrirAcordoDialog(
    BuildContext context, Map<String, dynamic> parcela) async {
  final service = ParcelasService();

  final comentarioCtrl =
      TextEditingController(text: parcela["comentario"] ?? "");
  final dataCtrl = TextEditingController(text: parcela["data_prevista"] ?? "");

  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("🤝 Fazer acordo"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🔹 Comentário com 3 linhas e limite de 100 caracteres
          TextField(
            controller: comentarioCtrl,
            maxLength: 100,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: "Comentário",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // 🔹 Campo de data com máscara e seletor de calendário
          TextField(
            controller: dataCtrl,
            readOnly: true,
            inputFormatters: [service.dateMaskFormatter()],
            decoration: const InputDecoration(
              labelText: "Data prevista",
              border: OutlineInputBorder(),
              hintText: "dd/mm/aaaa",
            ),
            onTap: () async {
              DateTime initialDate;
              try {
                initialDate = DateFormat("dd/MM/yyyy").parse(dataCtrl.text);
              } catch (_) {
                initialDate = DateTime.now();
              }

              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                dataCtrl.text = DateFormat("dd/MM/yyyy").format(picked);
              }
            },
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

              // 🔹 Mensagem no centro da tela
              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  content: const Text(
                    "Acordo excluído!",
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
            },
            child: const Text("Excluir acordo",
                style: TextStyle(color: Colors.red)),
          ),
        ElevatedButton(
          onPressed: () async {
            if (dataCtrl.text.isEmpty) {
              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  content: const Text(
                    "Escolha uma data prevista.",
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
              return;
            }

            await Supabase.instance.client
                .from("parcelas")
                .update({
                  "data_prevista": dataCtrl.text,
                  "comentario": comentarioCtrl.text,
                })
                .eq("id", parcela["id"]);

            if (!context.mounted) return;
            Navigator.pop(context);

            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                content: const Text(
                  "Acordo salvo com sucesso!",
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
          },
          child: const Text("Salvar acordo"),
        ),
      ],
    ),
  );
}
