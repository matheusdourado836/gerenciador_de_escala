import 'package:intl/intl.dart';

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
    return 'Servidor(nome: $nome, ferias: $ferias, ultimoDiaUtil: $ultimoDiaUtil)';
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
  while (isWeekend(date)) {
    while(date.weekday != DateTime.friday) {
      date = date.subtract(const Duration(days: 1));
    }
  }
  return date;
}

DateTime getReturnDay(DateTime endDate) {
  final DateTime date = endDate;
  if(isWeekend(date)) {
    if(date.weekday == DateTime.saturday) {
      return date.add(const Duration(days: 2));
    }else {
      return date.add(const Duration(days: 1));
    }
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
      return tenDaysBefore.add(const Duration(days: 2));
    }else {
      return tenDaysBefore.add(const Duration(days: 1));
    }
  }
  return tenDaysBefore;
}

List<DateTime>? parseFerias(String? feriasString) {
  if (feriasString == null || feriasString.isEmpty) {
    return null;
  }

  List<String> datas = feriasString.split(' a ');
  DateFormat format = DateFormat('dd/MM/yyyy');

  DateTime start = format.parse(datas[0]);
  DateTime end = format.parse(datas[1]);

  return [start, end];
}

Servidor fromJson(Map<String, dynamic> json) {
  String nome = json['nome'];
  List<DateTime>? ferias = parseFerias(json['ferias']);

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

List<Map<String, dynamic>> servidores = [
  {
    "nome": 'Alessia',
    "ferias": "25/09/2024 a 08/10/2024",
    "ultimoDiaUtil": ""
  },
  {
    "nome": 'Erica',
    "ferias": "",
    "ultimoDiaUtil": ""
  },
  {
    "nome": 'Jose Maria',
    "ferias": "",
    "ultimoDiaUtil": ""
  },
  {
    "nome": 'Marcelo',
    "ferias": "03/10/2024 a 05/10/2024",
    "ultimoDiaUtil": ""
  },
  {
    "nome": 'Romina',
    "ferias": "23/10/2024 a 30/10/2024",
    "ultimoDiaUtil": ""
  },
  {
    "nome": 'Ronaldo',
    "ferias": "",
    "ultimoDiaUtil": ""
  },
  {
    "nome": 'Carlos',
    "ferias": "28/10/2024 a 15/11/2024",
    "ultimoDiaUtil": ""
  },
];