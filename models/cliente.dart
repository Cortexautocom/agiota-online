class Cliente {
  final String idCliente;
  final String nome;
  final String cpf;
  final String telefone;
  final String endereco;
  final String cidade;
  final String indicacao;

  Cliente({
    required this.idCliente,
    required this.nome,
    required this.cpf,
    required this.telefone,
    required this.endereco,
    required this.cidade,
    required this.indicacao,
  });

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      idCliente: map['id_cliente'],
      nome: map['nome'] ?? '',
      cpf: map['cpf'] ?? '',
      telefone: map['telefone'] ?? '',
      endereco: map['endereco'] ?? '',
      cidade: map['cidade'] ?? '',
      indicacao: map['indicacao'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_cliente': idCliente,
      'nome': nome,
      'cpf': cpf,
      'telefone': telefone,
      'endereco': endereco,
      'cidade': cidade,
      'indicacao': indicacao,
    };
  }
}
