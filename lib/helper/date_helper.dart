import 'package:intl/intl.dart';

int getDiasDoMes() {
  int year = DateTime.now().year;
  int month = DateTime.now().month + 1;

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