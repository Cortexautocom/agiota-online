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
      'saldo_final': 0.0,
    });
    preencherControllers();
  }

  void preencherControllers() {
    _controllers.clear();
    for (final linha in _linhas) {
      _controllers.add({
        'data': TextEditingController(text: linha['data'].toString()),
        'aporte': TextEditingController(text: fmtMoeda(linha['aporte'])),
        'pg_capital': TextEditingController(text: fmtMoeda(linha['pg_capital'])),
        'pg_juros': TextEditingController(text: fmtMoeda(linha['pg_juros'])),
        'juros_mes': TextEditingController(text: fmtMoeda(linha['juros_mes'])),
      });
    }
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
          .select('id, data_mov, aporte, pg_principal, pg_juros, juros_periodo')
          .eq('id_emprestimo', idEmprestimo)
          .order('data_mov', ascending: true);

      _linhas.clear();

      for (final p in parcelas) {
        _linhas.add({
          'id': p['id'], // mantém o ID original
          'data': _service.toBrDate(p['data_mov']) ?? '',
          'saldo_inicial': 0.0,
          'aporte': (p['aporte'] as num?)?.toDouble() ?? 0.0,
          'pg_capital': (p['pg_principal'] as num?)?.toDouble() ?? 0.0,
          'pg_juros': (p['pg_juros'] as num?)?.toDouble() ?? 0.0,
          'juros_mes': (p['juros_periodo'] as num?)?.toDouble() ?? 0.0,
          'saldo_final': 0.0,
        });
      }

      preencherControllers();
      recalcularSaldos();
    } catch (e) {
      print('Erro ao carregar parcelas do banco: $e');
    }
  }

  // 🔹 SALVAR PARCELAS NO BANCO (UPDATE linha a linha)
  Future<bool> salvarParcelasNoBanco(String idEmprestimo) async {
    // 🔹 Atualiza dados das linhas com valores dos controllers antes de salvar
    for (int i = 0; i < _linhas.length; i++) {
      final controller = _controllers[i];
      _linhas[i]['aporte'] = parseMoeda(controller['aporte']!.text);
      _linhas[i]['pg_capital'] = parseMoeda(controller['pg_capital']!.text);
      _linhas[i]['pg_juros'] = parseMoeda(controller['pg_juros']!.text);
      _linhas[i]['juros_mes'] = parseMoeda(controller['juros_mes']!.text);
      _linhas[i]['data'] = controller['data']!.text;
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

        final updateData = {
          'data_mov': dataISO,
          'aporte': linha['aporte'],
          'pg_principal': linha['pg_capital'],
          'pg_juros': linha['pg_juros'],
          'juros_periodo': linha['juros_mes'],
          'tipo_mov': 'amortizacao',
          'id_usuario': userId,
        };

        await supabase
            .from('parcelas')
            .update(updateData)
            .eq('id', idParcela);
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

  // 🔹 ADICIONAR NOVA LINHA
  void adicionarLinha() {
    final double ultimoSaldoFinal = _linhas.isNotEmpty
        ? (_linhas.last['saldo_final'] ?? 0.0)
        : 0.0;

    _linhas.add({
      'id': null,
      'data': '',
      'saldo_inicial': ultimoSaldoFinal,
      'aporte': 0.0,
      'pg_capital': 0.0,
      'pg_juros': 0.0,
      'juros_mes': 0.0,
      'saldo_final': ultimoSaldoFinal,
    });

    _controllers.add({
      'data': TextEditingController(),
      'aporte': TextEditingController(),
      'pg_capital': TextEditingController(),
      'pg_juros': TextEditingController(),
      'juros_mes': TextEditingController(),
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
      linha['data'] = controller['data']!.text;

      final saldoInicial = linha['saldo_inicial'] ?? 0.0;
      final aporte = linha['aporte'] ?? 0.0;
      final pgCapital = linha['pg_capital'] ?? 0.0;
      final pgJuros = linha['pg_juros'] ?? 0.0;
      final jurosMes = linha['juros_mes'] ?? 0.0;

      linha['saldo_final'] =
          saldoInicial + aporte - pgCapital - pgJuros + jurosMes;

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
    for (int i = 1; i < _linhas.length; i++) {
      final dataAtual = _controllers[i]['data']!.text;
      final dataAnterior = _controllers[i - 1]['data']!.text;

      if (dataAtual.length == 10 && dataAnterior.length == 10) {
        final diferencaDias =
            _service.calcularDiferencaDias(dataAnterior, dataAtual);
        if (diferencaDias > 0 && _taxaJuros > 0) {
          final saldoAnterior = _linhas[i - 1]['saldo_final'] ?? 0.0;
          final jurosCalculado =
              saldoAnterior * (_taxaJuros / 100 / 30) * diferencaDias;
          _controllers[i]['juros_mes']!.text = fmtMoeda(jurosCalculado);
          _linhas[i]['juros_mes'] = jurosCalculado;
        }
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

    for (var i = 0; i < _linhas.length; i++) {
      totalAporte += parseMoeda(_controllers[i]['aporte']!.text);
      totalPgCapital += parseMoeda(_controllers[i]['pg_capital']!.text);
      totalPgJuros += parseMoeda(_controllers[i]['pg_juros']!.text);
      totalJurosPeriodo += parseMoeda(_controllers[i]['juros_mes']!.text);
    }

    return {
      'aporte': totalAporte,
      'pg_capital': totalPgCapital,
      'pg_juros': totalPgJuros,
      'juros_periodo': totalJurosPeriodo,
      'saldo_final':
          _linhas.isNotEmpty ? (_linhas.last['saldo_final'] ?? 0.0) : 0.0,
    };
  }
}
