import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class AmortizacaoService {
  final NumberFormat _fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final Uuid _uuid = const Uuid();

  // 🔹 MÉTODOS DE FORMATAÇÃO
  String fmtMoeda(double valor) {
    if (valor == 0.0) return '';
    return _fmt.format(valor);
  }

  double parseMoeda(String texto) {
    if (texto.isEmpty) return 0.0;
    final cleaned = texto
        .replaceAll('R\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  // 🔹 MÉTODO PARA FORMATAÇÃO DE PORCENTAGEM
  TextInputFormatter percentMaskFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      var text = newValue.text.replaceAll(RegExp(r'[^0-9,]'), '');
      
      // Permite apenas uma vírgula
      final commaCount = text.split(',').length - 1;
      if (commaCount > 1) {
        text = text.substring(0, text.length - 1);
      }
      
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  double parsePercent(String texto) {
    if (texto.isEmpty) return 0.0;
    final cleaned = texto.replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  // 🔹 MÉTODO PARA FORMATAÇÃO DE DATA (MÁSCARA dd/mm/aaaa)
  TextInputFormatter dateMaskFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (text.length >= 3) {
        text = '${text.substring(0, 2)}/${text.substring(2)}';
      }
      if (text.length >= 6) {
        text = '${text.substring(0, 5)}/${text.substring(5)}';
      }
      if (text.length > 10) {
        text = text.substring(0, 10);
      }
      
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  // 🔹 CALCULA DIFERENÇA DE DIAS ENTRE DATAS (30 dias/mês)
  int calcularDiferencaDias(String dataAnteriorStr, String dataAtualStr) {
    try {
      final partsAnterior = dataAnteriorStr.split('/');
      final partsAtual = dataAtualStr.split('/');
      
      if (partsAnterior.length != 3 || partsAtual.length != 3) return 0;
      
      final diaAnterior = int.parse(partsAnterior[0]);
      final mesAnterior = int.parse(partsAnterior[1]);
      final anoAnterior = int.parse(partsAnterior[2]);
      
      final diaAtual = int.parse(partsAtual[0]);
      final mesAtual = int.parse(partsAtual[1]);
      final anoAtual = int.parse(partsAtual[2]);
      
      // 🔹 CALCULA DIFERENÇA CONSIDERANDO SEMPRE 30 DIAS POR MÊS
      final totalDiasAnterior = (anoAnterior * 360) + (mesAnterior * 30) + diaAnterior;
      final totalDiasAtual = (anoAtual * 360) + (mesAtual * 30) + diaAtual;
      
      return totalDiasAtual - totalDiasAnterior;
    } catch (e) {
      return 0;
    }
  }

  // 🔹 CONVERTE DATA BR PARA ISO (yyyy-mm-dd)
  String? toIsoDate(String text) {
    if (text.isEmpty) return null;
    final parts = text.split('/');
    if (parts.length != 3) return null;
    final dia = parts[0].padLeft(2, '0');
    final mes = parts[1].padLeft(2, '0');
    final ano = parts[2];
    return "$ano-$mes-$dia";
  }

  // 🔹 CONVERTE DATA ISO PARA BR (dd/mm/yyyy)
  String? toBrDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return null;
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return null;
    }
  }

  // 🔹 BUSCAR PARCELAS DO BANCO (tipo_mov = 'amortizacao')
  Future<List<Map<String, dynamic>>> buscarParcelasAmortizacao(String idEmprestimo) async {
    try {
      final response = await Supabase.instance.client
          .from('parcelas')
          .select()
          .eq('id_emprestimo', idEmprestimo)
          .eq('tipo_mov', 'amortizacao')
          .order('data_mov');

      final parcelas = (response as List).cast<Map<String, dynamic>>();

      // Converter para formato da tabela
      return parcelas.map((parcela) {
        return {
          'id': parcela['id'],
          'data': toBrDate(parcela['data_mov']?.toString()) ?? '',
          'saldo_inicial': 0.0, // Será calculado
          'aporte': 0.0, // Não usado por enquanto
          'pg_capital': (parcela['pg_principal'] as num?)?.toDouble() ?? 0.0,
          'pg_juros': (parcela['pg_juros'] as num?)?.toDouble() ?? 0.0,
          'juros_mes': (parcela['juros_periodo'] as num?)?.toDouble() ?? 0.0,
          'saldo_final': 0.0, // Será calculado
        };
      }).toList();
    } catch (e) {
      print('Erro ao buscar parcelas: $e');
      return [];
    }
  }

  // 🔹 SALVAR PARCELAS NO BANCO
  Future<bool> salvarParcelasAmortizacao(
    String idEmprestimo, 
    List<Map<String, dynamic>> linhas,
    String idUsuario,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final parcelasParaSalvar = <Map<String, dynamic>>[];

      for (final linha in linhas) {
        final dataMov = toIsoDate(linha['data']?.toString() ?? '');
        if (dataMov == null) continue; // Pula linhas sem data

        final parcelaId = linha['id'] as String? ?? _uuid.v4();

        final parcelaData = {
          'id': parcelaId,
          'id_emprestimo': idEmprestimo,
          'numero': null, // Amortização não tem número de parcela
          'data_mov': dataMov,
          'pg_principal': (linha['pg_capital'] as num?)?.toDouble() ?? 0.0,
          'pg_juros': (linha['pg_juros'] as num?)?.toDouble() ?? 0.0,
          'juros_periodo': (linha['juros_mes'] as num?)?.toDouble() ?? 0.0,
          'tipo_mov': 'amortizacao',
          'id_usuario': idUsuario,
          // Campos não usados (mantidos como null)
          'valor': null,
          'vencimento': null,
          'juros': null,
          'desconto': null,
          'valor_pago': null,
          'residual': null,
          'data_pagamento': null,
          'data_prevista': null,
          'comentario': null,
          'juros_acordo': null,
        };

        parcelasParaSalvar.add(parcelaData);
      }

      // 🔹 Estratégia: Upsert (insert ou update) baseado no ID
      for (final parcela in parcelasParaSalvar) {
        await supabase
            .from('parcelas')
            .upsert(parcela, onConflict: 'id');
      }

      // 🔹 Remover parcelas que não estão mais na lista
      final parcelasExistentes = await supabase
          .from('parcelas')
          .select('id')
          .eq('id_emprestimo', idEmprestimo)
          .eq('tipo_mov', 'amortizacao');

      final idsExistentes = (parcelasExistentes as List)
          .cast<Map<String, dynamic>>()
          .map((e) => e['id'] as String)
          .toList();

      final idsParaManter = parcelasParaSalvar
          .map((e) => e['id'] as String)
          .toList();

      final idsParaRemover = idsExistentes
          .where((id) => !idsParaManter.contains(id))
          .toList();

      if (idsParaRemover.isNotEmpty) {
        await supabase
            .from('parcelas')
            .delete()
            .inFilter('id', idsParaRemover);
      }

      return true;
    } catch (e) {
      print('Erro ao salvar parcelas: $e');
      return false;
    }
  }

  // 🔹 CRIAR EMPRÉSTIMO DE AMORTIZAÇÃO (se necessário)
  Future<String?> criarEmprestimoAmortizacao({
    required String idCliente,
    required String idUsuario,
    required double valorTotal,
  }) async {
    try {
      final emprestimoId = _uuid.v4();
      final dataAtual = DateFormat('yyyy-MM-dd').format(DateTime.now());

      await Supabase.instance.client.from('emprestimos').insert({
        'id': emprestimoId,
        'id_cliente': idCliente,
        'valor': valorTotal,
        'data_inicio': dataAtual,
        'parcelas': 1, // Valor fictício para amortização
        'juros': 0.0,
        'prestacao': valorTotal,
        'id_usuario': idUsuario,
        'ativo': 'sim',
        'tipo': 'amortizacao', // Novo campo para diferenciar
      });

      return emprestimoId;
    } catch (e) {
      print('Erro ao criar empréstimo: $e');
      return null;
    }
  }
}