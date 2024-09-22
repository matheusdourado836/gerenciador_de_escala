import 'package:intl/intl.dart';

int getDiasDoMes(int month) {
  int year = DateTime.now().year;

  // Cria uma data no primeiro dia do mês desejado
  DateTime primeiroDiaDoMes = DateTime(year, month, 1);

  // Cria uma data no primeiro dia do mês seguinte
  DateTime primeiroDiaDoMesSeguinte = DateTime(year, month + 1, 1);

  // Calcula a diferença em dias
  int diasNoMes = primeiroDiaDoMesSeguinte.difference(primeiroDiaDoMes).inDays;

  return diasNoMes;
}

String formatDateExtenso(DateTime date) {
  return DateFormat('d \'de\' MMMM', 'pt_BR').format(date);
}

Map<String, int> monthMap = {
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