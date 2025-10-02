import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParcelasService {
  final _formatter = NumberFormat.currency(locale: "pt_BR", symbol: "R\$");

  /// 🔹 Formata número para moeda brasileira
  String fmtMoeda(dynamic valor) {
    if (valor == null) return "R\$ 0,00"; // sempre mostra 0
    final txt = valor.toString().trim();
    if (txt.isEmpty) return "R\$ 0,00";
    if (txt.startsWith("R\$")) return txt;
    final numero = num.tryParse(txt.replaceAll(",", "."));
    if (numero == null) return "R\$ 0,00";
    return _formatter.format(numero);
  }


  /// 🔹 Converte texto de moeda para double
  double parseMoeda(String txt) {
    if (txt.isEmpty) return 0;
    return double.tryParse(
          txt.replaceAll("R\$", "").replaceAll(".", "").replaceAll(",", ".").trim(),
        ) ??
        0;
  }

  /// 🔹 Máscara simples para dd/mm/aaaa
  TextInputFormatter dateMaskFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (text.length > 8) text = text.substring(0, 8);

      String formatted = '';
      for (int i = 0; i < text.length; i++) {
        formatted += text[i];
        if (i == 1 || i == 3) formatted += '/';
      }

      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
  }

  /// 🔹 Busca parcelas no Supabase
  Future<List<Map<String, dynamic>>> buscarParcelas(String emprestimoId) async {
    final response = await Supabase.instance.client
        .from('parcelas')
        .select()
        .eq('id_emprestimo', emprestimoId)
        .order('numero', ascending: true);

    return (response as List).map((e) => e as Map<String, dynamic>).toList();
  }

  /// 🔹 Salva (atualiza ou insere) parcelas no Supabase
  Future<void> salvarParcelasNoSupabase(
    String emprestimoId,
    String usuarioId,
    List<Map<String, dynamic>> parcelas,
  ) async {
    final supabase = Supabase.instance.client;

    try {
      for (final p in parcelas) {
        final id = p['id'];
        final dadosAtualizados = Map<String, dynamic>.from(p)..remove('id');

        if (id != null) {
          // Atualiza mantendo o mesmo ID
          await supabase.from('parcelas').update(dadosAtualizados).eq('id', id);
        } else {
          // Se não tiver ID (nova parcela), insere
          await supabase.from('parcelas').insert(p);
        }
      }

      print("Parcelas salvas/atualizadas no Supabase!");
    } catch (e) {
      print("Erro ao salvar parcelas: $e");
      rethrow;
    }
  }
}
