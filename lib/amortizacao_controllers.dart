import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'amortizacao_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AmortizacaoControllers {
  final AmortizacaoService _service = AmortizacaoService();

  // 🔹 DADOS DA TABELA
  final List<Map<String, dynamic>> _linhas = [];
  final List<Map<String, TextEditingController>> _controllers = [];

  // 🔹 CONTROLE DE TAXA DE JUROS
  final TextEditingController taxaJurosCtrl = TextEditingController();
  double _taxaJuros = 0.0;

  // 🔹 GETTERS
  List<Map<String, dynamic>> get linhas => _linhas;
  List<Map<String, TextEditingController>> get controllers => _controllers;
  double get taxaJuros => _taxaJuros;
  set taxaJuros(double value) => _taxaJuros = value;

  AmortizacaoControllers() {
    _inicializarPrimeiraLinha();
  }

  void _inicializarPrimeiraLinha() {
    _linhas.add({
      'id': null,
      'data': DateFormat('dd/MM/yyyy').format(DateTime.now()),
      'saldo_inicial': 0.0,
      'aporte': 0.0,
      'pg_capital': 0.0,
      'pg_juros': 0.0,
      'juros_mes': 0.0,
      'juros_atraso': 0.0,
      'data_pagamento': '',
      'saldo_final': 0.0,
      'pg': 0,
    });
    preencherControllers();
  }

  void preencherControllers() {
    _controllers.clear();
    for (final linha in _linhas) {
      _controllers.add({
        'data': TextEditingController(text: linha['data'].toString()),
        
        'aporte': TextEditingController(
          text: (linha['aporte'] ?? 0.0) == 0.0 ? '' : fmtMoeda(linha['aporte']),
        ),

        'pg_capital': TextEditingController(
          text: fmtMoeda(linha['pg_capital']),
        ),
        'pg_juros': TextEditingController(
          text: fmtMoeda(linha['pg_juros']),
        ),
        'juros_mes': TextEditingController(
          text: fmtMoeda(linha['juros_mes']),
        ),

        'juros_atraso': TextEditingController(
          text: (linha['juros_atraso'] ?? 0.0) == 0.0
              ? ''
              : fmtMoeda(linha['juros_atraso']),
        ),

        // 🔹 NOVO: Controller para data de pagamento (igual à tabela de parcelas)
        'data_pagamento': TextEditingController(
          text: _toBrDate(linha['data_pagamento']?.toString()),
        ),
      });
    }
  }

  // 🔹 ADICIONE ESTE MÉTODO NA MESMA CLASSE (AmortizacaoControllers)
  String? _toBrDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      final parts = isoDate.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    } catch (e) {
      print('Erro ao converter data: $e');
    }
    return '';
  }


  // 🔹 FORMATAÇÃO
  String fmtMoeda(double valor) => _service.fmtMoeda(valor);
  double parseMoeda(String texto) => _service.parseMoeda(texto);

  // 🔹 CARREGAR PARCELAS DO BANCO (com ID correto)
  Future<void> carregarParcelasDoBanco(String idEmprestimo) async {
    final supabase = Supabase.instance.client;

    try {
      final parcelas = await supabase
          .from('parcelas')
          .select('id, data_mov, aporte, pg_principal, pg_juros, juros_atraso, pg, data_pagamento')
          .eq('id_emprestimo', idEmprestimo)
          .order('data_mov', ascending: true);

      _linhas.clear();

      for (final p in parcelas) {
        _linhas.add({
          'id': p['id'],
          'data': _service.toBrDate(p['data_mov']) ?? '',
          'saldo_inicial': 0.0,
          'aporte': (p['aporte'] as num?)?.toDouble() ?? 0.0,
          'pg_capital': (p['pg_principal'] as num?)?.toDouble() ?? 0.0,
          'pg_juros': (p['pg_juros'] as num?)?.toDouble() ?? 0.0,
          'juros_mes': 0.0,
          'juros_atraso': (p['juros_atraso'] as num?)?.toDouble() ?? 0.0,
          'pg': (p['pg'] as int?) ?? 0,
          'data_pagamento': _service.toBrDate(p['data_pagamento']?.toString()) ?? '',
          'saldo_final': 0.0,
        });
      }

      preencherControllers();
      recalcularSaldos();
      recalcularTodosJuros();
    } catch (e) {
      print('Erro ao carregar parcelas do banco: $e');
    }
  }

  // 🔹 SALVAR PARCELAS NO BANCO (UPDATE linha a linha)
  Future<bool> salvarParcelasNoBanco(String idEmprestimo) async {
    for (int i = 0; i < _linhas.length; i++) {
      final controller = _controllers[i];
      _linhas[i]['aporte'] = parseMoeda(controller['aporte']!.text);
      _linhas[i]['pg_capital'] = parseMoeda(controller['pg_capital']!.text);
      _linhas[i]['pg_juros'] = parseMoeda(controller['pg_juros']!.text);
      _linhas[i]['juros_mes'] = parseMoeda(controller['juros_mes']!.text);
      _linhas[i]['juros_atraso'] = parseMoeda(controller['juros_atraso']!.text); // 🆕
      _linhas[i]['data'] = controller['data']!.text;
      _linhas[i]['data_pagamento'] = controller['data_pagamento']!.text;
    }

    final userId = _getUserId();
    if (userId == null) {
      print('Erro: Usuário não autenticado');
      return false;
    }

    try {
      final supabase = Supabase.instance.client;

      for (final linha in _linhas) {
        final idParcela = linha['id'];
        if (idParcela == null) {
          print('⚠️ Ignorando linha sem ID');
          continue;
        }

        final dataISO = _service.toIsoDate(linha['data']);

        final dataPagamentoBr = linha['data_pagamento']?.toString() ?? '';
        final dataPagamentoISO = dataPagamentoBr.isNotEmpty 
            ? _service.toIsoDate(dataPagamentoBr)
            : null;

        final updateData = {
          'data_mov': dataISO,
          'aporte': linha['aporte'],
          'pg_principal': linha['pg_capital'],
          'pg_juros': linha['pg_juros'],
          'juros_periodo': linha['juros_mes'],
          'juros_atraso': linha['juros_atraso'],
          'pg': linha['pg'],
          'tipo_mov': 'amortizacao',
          'id_usuario': userId,
          // 🔹 NOVO: Salva a data de pagamento no banco
          'data_pagamento': dataPagamentoISO,
        };

        await supabase.from('parcelas').update(updateData).eq('id', idParcela);
      }

      print('✅ Parcelas atualizadas com sucesso.');
      return true;
    } catch (e, st) {
      print('❌ Erro ao salvar parcelas: $e');
      print(st);
      return false;
    }
  }

  String? _getUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (e) {
      return null;
    }
  }
  
  void adicionarLinha() {
    final double ultimoSaldoFinal =
        _linhas.isNotEmpty ? (_linhas.last['saldo_final'] ?? 0.0) : 0.0;

    _linhas.add({
      'id': null,
      'data': '',
      'saldo_inicial': ultimoSaldoFinal,
      'aporte': 0.0,
      'pg_capital': 0.0,
      'pg_juros': 0.0,
      'juros_mes': 0.0,
      'juros_atraso': 0.0,
      'data_pagamento': '',
      'saldo_final': ultimoSaldoFinal,
      'pg': 0,
    });

    _controllers.add({
      'data': TextEditingController(),
      'aporte': TextEditingController(),
      'pg_capital': TextEditingController(),
      'pg_juros': TextEditingController(),
      'juros_mes': TextEditingController(), 
      'juros_atraso': TextEditingController(),
      'data_pagamento': TextEditingController(),
    });

    recalcularSaldos();
  }

  bool haDataVazia() {
    for (final controller in _controllers) {
      if (controller['data']!.text.isEmpty) return true;
    }
    return false;
  }

  void recalcularSaldos() {
    for (int i = 0; i < _linhas.length; i++) {
      final linha = _linhas[i];
      final controller = _controllers[i];

      linha['aporte'] = parseMoeda(controller['aporte']!.text);
      linha['pg_capital'] = parseMoeda(controller['pg_capital']!.text);
      linha['pg_juros'] = parseMoeda(controller['pg_juros']!.text);
      linha['juros_mes'] = parseMoeda(controller['juros_mes']!.text);
      linha['juros_atraso'] = parseMoeda(controller['juros_atraso']!.text); // 🆕
      linha['data'] = controller['data']!.text;

      final saldoInicial = linha['saldo_inicial'] ?? 0.0;
      final aporte = linha['aporte'] ?? 0.0;
      final pgCapital = linha['pg_capital'] ?? 0.0;
      final pgJuros = linha['pg_juros'] ?? 0.0;
      final jurosMes = linha['juros_mes'] ?? 0.0;
      final jurosAtraso = linha['juros_atraso'] ?? 0.0; // 🆕 novo campo

      linha['saldo_final'] =
          saldoInicial + aporte - pgCapital - pgJuros + jurosMes + jurosAtraso;

      if (i < _linhas.length - 1) {
        _linhas[i + 1]['saldo_inicial'] = linha['saldo_final'];
      }
    }
  }

  void calcularJurosAutomatico(int index) {
    if (index == 0) return;
    final dataAtual = _controllers[index]['data']!.text;
    final dataAnterior = _controllers[index - 1]['data']!.text;

    if (dataAtual.length == 10 && dataAnterior.length == 10) {
      final diferencaDias =
          _service.calcularDiferencaDias(dataAnterior, dataAtual);

      if (diferencaDias > 0 && _taxaJuros > 0) {
        final saldoAnterior = _linhas[index - 1]['saldo_final'] ?? 0.0;
        final jurosCalculado =
            saldoAnterior * (_taxaJuros / 100 / 30) * diferencaDias;
        final jurosAtual = parseMoeda(_controllers[index]['juros_mes']!.text);
        if (jurosAtual == 0.0) {
          _controllers[index]['juros_mes']!.text = fmtMoeda(jurosCalculado);
          _linhas[index]['juros_mes'] = jurosCalculado;
          recalcularSaldos();
        }
      }
    }
  }

  void recalcularTodosJuros() {
    if (_linhas.isEmpty) return;
    double? ultimoJurosValido;

    // 🔹 Zera todos os juros antes de recalcular
    for (var i = 0; i < _linhas.length; i++) {
      _linhas[i]['juros_mes'] = 0.0;
      _controllers[i]['juros_mes']!.text = fmtMoeda(0.0);
    }

    for (int i = 1; i < _linhas.length; i++) {
      final dataAtual = _controllers[i]['data']!.text;
      final dataAnterior = _controllers[i - 1]['data']!.text;

      if (dataAtual.length != 10 || dataAnterior.length != 10) continue;

      // 🔸 Primeira parcela após o aporte
      if (i == 1) {
        final diferencaDias = _service.calcularDiferencaDias(dataAnterior, dataAtual);
        if (diferencaDias > 0 && _taxaJuros > 0) {
          final saldoAnterior = _linhas[i - 1]['saldo_final'] ?? 0.0;
          final jurosCalculado =
              saldoAnterior * (_taxaJuros / 100 / 30) * diferencaDias;

          _linhas[i]['juros_mes'] = jurosCalculado;
          _controllers[i]['juros_mes']!.text = fmtMoeda(jurosCalculado);
          ultimoJurosValido = jurosCalculado;
        }
        continue;
      }

      final linhaAnterior = _linhas[i - 1];

      // 🔹 Detecta se a linha anterior está vencida e não paga
      final dataTextoAnterior = linhaAnterior['data']?.toString() ?? '';
      bool estaAtrasada = false;

      try {
        if (dataTextoAnterior.length == 10) {
          final dataAnteriorFmt = DateFormat('dd/MM/yyyy').parse(dataTextoAnterior);
          final agora = DateTime.now().toUtc().subtract(const Duration(hours: 3));
          final hoje = DateTime(agora.year, agora.month, agora.day);
          final pgAnterior = linhaAnterior['pg'] ?? 0;

          if (dataAnteriorFmt.isBefore(hoje) && pgAnterior == 0) {
            estaAtrasada = true;
          }
        }
      } catch (e) {
        estaAtrasada = false;
      }

      // 🔸 Critério de recálculo: houve movimentação OU está em atraso
      final bool deveRecalcular =
          (linhaAnterior['aporte'] ?? 0) != 0 ||
          (linhaAnterior['pg_capital'] ?? 0) != 0 ||
          (linhaAnterior['pg_juros'] ?? 0) != 0 ||
          estaAtrasada;

      if (deveRecalcular) {
        final diferencaDias = _service.calcularDiferencaDias(dataAnterior, dataAtual);
        if (diferencaDias > 0 && _taxaJuros > 0) {
          final saldoAnterior = _linhas[i - 1]['saldo_final'] ?? 0.0;
          final jurosCalculado =
              saldoAnterior * (_taxaJuros / 100 / 30) * diferencaDias;

          _linhas[i]['juros_mes'] = jurosCalculado;
          _controllers[i]['juros_mes']!.text = fmtMoeda(jurosCalculado);
          ultimoJurosValido = jurosCalculado;
        }
      } else {
        // 🔸 Sem movimentação e sem atraso → repete o último juros válido
        if (ultimoJurosValido != null) {
          _linhas[i]['juros_mes'] = ultimoJurosValido;
          _controllers[i]['juros_mes']!.text = fmtMoeda(ultimoJurosValido);
        }
      }

      // 🔹 Atualiza saldos finais e iniciais
      final saldoInicial = _linhas[i]['saldo_inicial'] ?? 0.0;
      final aporte = _linhas[i]['aporte'] ?? 0.0;
      final pgCapital = _linhas[i]['pg_capital'] ?? 0.0;
      final pgJuros = _linhas[i]['pg_juros'] ?? 0.0;
      final jurosMes = _linhas[i]['juros_mes'] ?? 0.0;
      final jurosAtraso = _linhas[i]['juros_atraso'] ?? 0.0;

      _linhas[i]['saldo_final'] =
          saldoInicial + aporte - pgCapital - pgJuros + jurosMes + jurosAtraso;

      if (i < _linhas.length - 1) {
        _linhas[i + 1]['saldo_inicial'] = _linhas[i]['saldo_final'];
      }
    }

    recalcularSaldos();
  }


  void dispose() {
    for (final controllerMap in _controllers) {
      controllerMap['data']?.dispose();
      controllerMap['aporte']?.dispose();
      controllerMap['pg_capital']?.dispose();
      controllerMap['pg_juros']?.dispose();
      controllerMap['juros_mes']?.dispose();
      controllerMap['juros_atraso']?.dispose();
      controllerMap['data_pagamento']?.dispose();
    }
    taxaJurosCtrl.dispose();
  }

  bool validarDados() {
    for (final controller in _controllers) {
      if (controller['data']!.text.isEmpty) return false;
    }
    for (int i = 1; i < _controllers.length; i++) {
      final dataAnterior = _controllers[i - 1]['data']!.text;
      final dataAtual = _controllers[i]['data']!.text;
      if (dataAnterior.isNotEmpty && dataAtual.isNotEmpty) {
        final dias = _service.calcularDiferencaDias(dataAnterior, dataAtual);
        if (dias < 0) return false;
      }
    }
    return true;
  }

  Map<String, double> calcularTotais() {
    double totalAporte = 0;
    double totalPgCapital = 0;
    double totalPgJuros = 0;
    double totalJurosPeriodo = 0;
    double totalJurosAtraso = 0;

    for (var i = 0; i < _linhas.length; i++) {
      totalAporte += parseMoeda(_controllers[i]['aporte']!.text);
      totalPgCapital += parseMoeda(_controllers[i]['pg_capital']!.text);
      totalPgJuros += parseMoeda(_controllers[i]['pg_juros']!.text);
      totalJurosPeriodo += parseMoeda(_controllers[i]['juros_mes']!.text);
      totalJurosAtraso += parseMoeda(_controllers[i]['juros_atraso']!.text);
    }

    return {
      'aporte': totalAporte,
      'pg_capital': totalPgCapital,
      'pg_juros': totalPgJuros,
      'juros_periodo': totalJurosPeriodo,
      'juros_atraso': totalJurosAtraso,
      'saldo_final':
          _linhas.isNotEmpty ? (_linhas.last['saldo_final'] ?? 0.0) : 0.0,
    };
  }
}
