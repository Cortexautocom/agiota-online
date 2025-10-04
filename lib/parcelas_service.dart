import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParcelasService {
  final _formatter = NumberFormat.currency(locale: "pt_BR", symbol: "R\$");

  /// 🔹 Formata número para moeda brasileira
  String fmtMoeda(dynamic valor) {
    if (valor == null) return "";
    final txt = valor.toString().trim();
    if (txt.isEmpty) return "";
    if (txt.startsWith("R\$")) return txt;
    final numero = num.tryParse(txt.replaceAll(",", "."));
    if (numero == null) return "";
    // 👇 Se for zero, retorna vazio (para outras colunas)
    if (numero == 0) return "";
    return _formatter.format(numero);
  }

  /// 🔹 Formata residual sempre com "R$ 0,00" quando for zero
  String fmtMoedaResidual(dynamic valor) {
    if (valor == null) return "R\$ 0,00";
    final txt = valor.toString().trim();
    if (txt.isEmpty) return "R\$ 0,00";
    if (txt.startsWith("R\$")) return txt;
    final numero = num.tryParse(txt.replaceAll(",", "."));
    if (numero == null) return "R\$ 0,00";
    return _formatter.format(numero);
  }

  /// 🔹 Formata moeda SEM ponto para valores abaixo de 1000
  String fmtMoeda2(dynamic valor) {
    if (valor == null) return "R\$ 0,00";

    String txt = valor.toString().trim();

    // remove símbolo de moeda se já tiver
    txt = txt.replaceAll("R\$", "").trim();

    // substitui vírgula por ponto (caso venha no formato errado)
    txt = txt.replaceAll(",", ".");

    final num? numero = num.tryParse(txt);
    if (numero == null) return "R\$ 0,00";

    // ✅ formata no padrão brasileiro
    final formatador = NumberFormat.currency(
      locale: "pt_BR",
      symbol: "R\$",
      decimalDigits: 2,
    );

    return formatador.format(numero);
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
    print("🔎 Buscando parcelas para id_emprestimo=$emprestimoId");

    try {
      final response = await Supabase.instance.client
          .from('parcelas')
          .select()
          .eq('id_emprestimo', emprestimoId.toString())
          .order('numero', ascending: true);

      print("📥 Resposta bruta Supabase (parcelas): $response");

      final lista = (response as List).map((e) => e as Map<String, dynamic>).toList();
      print("✅ Total de parcelas encontradas: ${lista.length}");
      for (var p in lista) {
        print("➡️ Parcela carregada: $p");
      }

      return lista;
    } catch (e) {
      print("❌ Erro ao buscar parcelas: $e");
      rethrow;
    }
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
          print("✏️ Atualizando parcela ID=$id com dados=$dadosAtualizados");
          await supabase.from('parcelas').update(dadosAtualizados).eq('id', id);
        } else {
          print("➕ Inserindo nova parcela: $p");
          await supabase.from('parcelas').insert(p);
        }
      }

      print("✅ Parcelas salvas/atualizadas no Supabase!");
    } catch (e) {
      print("❌ Erro ao salvar parcelas: $e");
      rethrow;
    }
  }
}