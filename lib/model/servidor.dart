import '../pages/home/home_page.dart';

class Servidor {
  String nome;
  List<DateTime>? ferias;  // Pode ser nulo se o servidor não tiver férias
  DateTime? ultimoDiaUtil; // Pode ser nulo se não houver férias
  DateTime? diaDeRetorno; // Pode ser nulo se não houver férias

  Servidor({
    required this.nome,
    this.ferias,
    this.ultimoDiaUtil,
    this.diaDeRetorno,
  });

  @override
  String toString() {
    return '$nome';
  }

  Map<String, dynamic> toJson() => {
    "nome": nome,
    "ferias": ferias,
    "ultimoDiaUtil": ultimoDiaUtil,
    "diaDeRetorno": diaDeRetorno,
  };
}

// Funções auxiliares
bool isWeekend(DateTime date) {
  return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
}

DateTime getPreviousBusinessDay(DateTime startDate) {
  DateTime date = startDate.subtract(const Duration(days: 1));
  if (feriados.contains(date)) {
    // Se for feriado, retrocedemos para o dia anterior
    DateTime anterior = date.subtract(const Duration(days: 1));

    // Continuamos retrocedendo até encontrar um dia útil
    while (_isFeriadoOuFinalDeSemana(anterior, feriados)) {
      anterior = anterior.subtract(const Duration(days: 1));
    }

    return anterior; // Retorna o primeiro dia útil
  }
  if(startDate.weekday == DateTime.monday) {
    return startDate.subtract(const Duration(days: 3));
  }
  if(isWeekend(date)) {
    if(date.weekday == DateTime.saturday) {
      date = startDate.subtract(const Duration(days: 1));
    }else {
      date = startDate.subtract(const Duration(days: 2));
    }
  }

  return date;
}

bool _isFeriadoOuFinalDeSemana(DateTime data, List<DateTime> feriados) {
  // Verifica se a data é um sábado, domingo ou feriado
  return data.weekday == DateTime.saturday ||
      data.weekday == DateTime.sunday ||
      feriados.contains(data);
}

DateTime getReturnDay(DateTime endDate) {
  final DateTime date = endDate;
  if(isWeekend(date)) {
    return date.add(Duration(days: (date.weekday == DateTime.saturday) ? 2 : 1));
  }else if(date.add(const Duration(days: 1)).weekday == DateTime.saturday) {
    return date.add(const Duration(days: 3));
  }

  return date.add(const Duration(days: 1));
}

DateTime calculate10DaysBefore(DateTime vacationStart) {
  DateTime firstBusinessDay = getPreviousBusinessDay(vacationStart);
  DateTime tenDaysBefore = firstBusinessDay.subtract(const Duration(days: 9));
  if(isWeekend(tenDaysBefore)) {
    if(tenDaysBefore.weekday == DateTime.saturday) {
      return tenDaysBefore.subtract(const Duration(days: 1));
    }else {
      return tenDaysBefore.subtract(const Duration(days: 2));
    }
  }

  return tenDaysBefore;
}

DateTime calculatePreparation(DateTime vacationStart) {
  DateTime firstBusinessDay = getPreviousBusinessDay(vacationStart);
  DateTime tenDaysBefore = firstBusinessDay.subtract(const Duration(days: 9));

  return tenDaysBefore;
}

List<DateTime>? parseFerias(String? feriasString) {
  if (feriasString == null || feriasString.isEmpty || !feriasString.contains('-')) {
    return null;
  }

  List<String> datas = feriasString.split(' a ');

  try {
    DateTime start = DateTime.parse(datas[0]);
    DateTime end = DateTime.parse(datas[1]);

    return [start, end];
  } catch (e) {
    print('Erro ao processar as datas: $e');
    return null;
  }
}

Servidor fromJson(Map<String, dynamic> json) {
  String nome = json['nome'];
  String inicioFerias = json["inicio_ferias"];
  String fimFerias = json["final_ferias"];
  List<DateTime>? ferias = parseFerias('$inicioFerias a $fimFerias');

  DateTime? ultimoDiaUtil;
  DateTime? diaDeRetorno;
  if (ferias != null && ferias.isNotEmpty) {
    ultimoDiaUtil = getPreviousBusinessDay(ferias[0]);
    diaDeRetorno = getReturnDay(ferias[1]);
  }

  return Servidor(
    nome: nome,
    ferias: ferias,
    ultimoDiaUtil: ultimoDiaUtil,
    diaDeRetorno: diaDeRetorno
  );
}