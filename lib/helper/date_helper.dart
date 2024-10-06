import 'package:intl/intl.dart';

int getDiasDoMes(int month) {
  int year = DateTime.now().year;

  // Cria uma data no primeiro dia do mês desejado
  DateTime primeiroDiaDoMes = DateTime(year, month, 1);

  // Cria uma data no primeiro dia do mês seguinte
  DateTime primeiroDiaDoMesSeguinte = DateTime(year, month + 1, 1);

  // Calcula a diferença em dias
  int diasNoMes = primeiroDiaDoMesSeguinte.difference(primeiroDiaDoMes).inDays;
  if(diasNoMes < 0) {
    diasNoMes = 31;
  }

  return diasNoMes;
}

String formatDateExtenso(DateTime date) {
  return DateFormat('d \'de\' MMMM', 'pt_BR').format(date);
}

int getWeekdayIndex(String date) {
  // Divida a string em dia e mês
  List<String> dateParts = date.split(' de ');
  int day = int.parse(dateParts[0]);
  String month = dateParts[1].toLowerCase();

  // Obtenha o ano atual
  int year = DateTime.now().year;

  // Verifique se o mês é válido
  if (!monthsMap.containsKey(month)) {
    throw ArgumentError('Mês inválido');
  }

  // Crie um objeto DateTime
  DateTime dateTime = DateTime(year, monthsMap[month]!, day);

  // Retorne o índice do dia da semana (1 é segunda-feira, 7 é domingo)
  return dateTime.weekday;
}

Map<String, int> monthsMap = {
  'janeiro': 1,
  'fevereiro': 2,
  'março': 3,
  'abril': 4,
  'maio': 5,
  'junho': 6,
  'julho': 7,
  'agosto': 8,
  'setembro': 9,
  'outubro': 10,
  'novembro': 11,
  'dezembro': 12,
};