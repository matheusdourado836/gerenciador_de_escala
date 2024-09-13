import 'dart:convert';
import 'package:escala_trabalho/model/servidor.dart';
import 'dart:html' as html;
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<List<Data?>> excelData = [];
  List<DateTime> feriados = [];
  List<Servidor> servidoresList = [];
  List<Servidor> servidoresDeFerias = [];
  int year = 0;
  int month = 0;
  int days = 0;

  @override
  void initState() {
    super.initState();
    year = DateTime.now().year;
    month = DateTime.now().month + 1;
    days = getDiasDoMes();
    loadServidores();
  }

  int getDiasDoMes() {
    // Cria uma data no primeiro dia do mês desejado
    DateTime primeiroDiaDoMes = DateTime(year, month, 1);

    // Cria uma data no primeiro dia do mês seguinte
    DateTime primeiroDiaDoMesSeguinte = DateTime(year, month + 1, 1);

    // Calcula a diferença em dias
    int diasNoMes = primeiroDiaDoMesSeguinte.difference(primeiroDiaDoMes).inDays;

    return diasNoMes;
  }

  // Função para carregar os servidores do JSON
  Future<void> loadServidores() async {
    servidoresList = [];
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final servidoresJson = prefs.getString('planilha');
    if(servidoresJson?.isNotEmpty ?? false) {
      for(var servidor in jsonDecode(servidoresJson!)) {
        servidoresList.add(fromJson(servidor));
      }
    }

    return;
  }

  String formatDateExtenso(DateTime date) {
    return DateFormat('d \'de\' MMMM', 'pt_BR').format(date);
  }

  Future<void> _pickAndReadExcel() async {
    // Cria um input de arquivo HTML
    final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.accept = '.xlsx, .xls'; // Permite apenas arquivos Excel
    uploadInput.multiple = false;

    // Define o comportamento ao selecionar um arquivo
    uploadInput.onChange.listen((e) async {
      final files = uploadInput.files;
      if (files!.isEmpty) return;

      final reader = html.FileReader();
      reader.readAsArrayBuffer(files[0]);

      reader.onLoadEnd.listen((e) async {
        // Converte os bytes do arquivo para um formato que pode ser lido pelo Excel
        final Uint8List fileBytes = reader.result as Uint8List;
        var excel = Excel.decodeBytes(fileBytes);

        List<Map<String, String>> rowsData = [];

        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table]!;

          if (sheet.rows.isEmpty) continue; // Se não houver dados, ignorar

          // A primeira linha contém os nomes das colunas (headers)
          List<String> headers = sheet.rows.first.map((cell) => cell?.value?.toString() ?? '').toList();

          // Iterar sobre as linhas de dados (começando na segunda linha, ou seja, índice 1)
          for (var i = 1; i < sheet.rows.length; i++) {
            var row = sheet.rows[i];

            // Evitar adicionar objetos vazios
            if (row.every((cell) => cell?.value == null || (cell?.value.toString().isEmpty ?? true))) {
              continue;
            }

            Map<String, String> rowData = {};

            for (var j = 0; j < headers.length; j++) {
              String key = headers[j];

              // Ignorando a coluna de feriados/recesso
              if (key.toLowerCase().contains('feriado')) {
                if(row[j]?.value?.toString().isNotEmpty ?? false) {
                  feriados.add(DateTime.parse(row[j]?.value?.toString() ?? ''));
                }
                continue;
              }

              String value = row[j]?.value?.toString() ?? '';
              rowData[key] = value;
            }

            rowsData.add(rowData);
          }
        }

        // Serializando os dados mapeados
        String excelData = jsonEncode(rowsData);

        // Salvando no SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('planilha', excelData);
        await loadServidores();
        setState(() {});
      });
    });

    // Simula o clique no input de arquivo
    uploadInput.click();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distribuição de Servidores'),
        actions: [
          TextButton.icon(
              onPressed: _pickAndReadExcel,
              label: const Text('Adicionar planilha', style: TextStyle(fontSize: 20),),
              icon: const Icon(Icons.add, size: 32,)
          ),
        ]
      ),
      body: servidoresList.isEmpty ? const Center(child: Text('NADA AQUI'),) : SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DataTable(
              columns: const [
                DataColumn(label: Text('Data')),
                DataColumn(label: Text('Servidor')),
              ],
              rows: () {
                List<Servidor> filaServidores = List.from(servidoresList); // Cópia da lista original
                List<DataRow> rows = [];
                int count = 0;

                // Iterar sobre todos os dias do mês
                for (int i = 0; i < days; i++) {
                  DateTime currentDay = DateTime(2024, month, i + 1);
                  String formattedDate = formatDateExtenso(currentDay);
                  if(!isWeekend(currentDay)) {

                    // Verifica se o servidor está de férias ou nos 10 dias anteriores ao início das férias
                    bool estaDeFerias = false;
                    if (filaServidores[count].ferias != null && filaServidores[count].ferias!.isNotEmpty) {
                      // Verifica se o servidor está de férias no dia atual ou nos 10 dias anteriores
                      DateTime dezDiasAntes = calculate10DaysBefore(filaServidores[count].ultimoDiaUtil!);
                      if ((currentDay == dezDiasAntes || currentDay.isAfter(dezDiasAntes)) && currentDay.isBefore(filaServidores[count].diaDeRetorno!)) {
                        estaDeFerias = true;
                      }

                    }
                    if (estaDeFerias) {
                      servidoresDeFerias.add(filaServidores[count]);
                      filaServidores.removeAt(count);
                    }

                    for(var servidor in servidoresDeFerias) {
                      if(servidor.diaDeRetorno != null) {
                        if ((currentDay.day == servidor.diaDeRetorno!.day) && currentDay.month == servidor.diaDeRetorno!.month) {
                          filaServidores.insert(count, servidor); // Adiciona o novo servidor no lugar do dia de retorno
                        }
                      }
                    }

                    // Adiciona a linha na tabela
                    rows.add(DataRow(
                      cells: [
                        DataCell(Text(formattedDate)),
                        DataCell(Text(filaServidores[count].nome)),
                      ],
                    ));

                    if(count >= filaServidores.length - 1) {
                      count = 0;
                    }else {
                      count++;
                    }
                  }else {
                    rows.add(DataRow(
                      cells: [
                        DataCell(Text(formattedDate)),
                        const DataCell(Text('FIM DE SEMANA')),
                      ],
                    ));
                  }
                }
                return rows;
              }(),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 40.0),
              child: DataTable(
                  dataRowMinHeight: 50,
                  dataRowMaxHeight: 80,
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold),
                  border: const TableBorder(
                    left: BorderSide(width: .5),
                    right: BorderSide(width: .5),
                    top: BorderSide(width: .5),
                    bottom: BorderSide(width: .5),
                    verticalInside: BorderSide(width: .5),
                  ),
                  columns: const [
                    DataColumn(label: Text('Nome')),
                    DataColumn(label: Text('Trabalha até')),
                    DataColumn(label: Text('Volta em')),
                    DataColumn(label: Text('Período de férias')),
                    DataColumn(label: Text('Período de preparação')),
                  ],
                  rows: servidoresList.map((servidor) {
                    if(servidor.ultimoDiaUtil != null) {
                      DateFormat format = DateFormat('dd/MM/yyyy');
                      final inicioFerias = format.format(servidor.ferias![0]);
                      final fimFerias = format.format(servidor.ferias![1]);
                      return DataRow(cells: [
                        DataCell(Text(servidor.nome, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(formatDateExtenso(calculate10DaysBefore(servidor.ultimoDiaUtil!)))),
                        DataCell(Text(formatDateExtenso(servidor.diaDeRetorno!))),
                        DataCell(Text('$inicioFerias à $fimFerias')),
                        DataCell(Text(formatDateExtenso(calculatePreparation(servidor.ferias![0])))),
                      ]);
                    }else {
                      return DataRow(cells: [
                        DataCell(Text(servidor.nome, style: const TextStyle(fontWeight: FontWeight.bold))),
                        const DataCell(Text('SEM FÉRIAS')),
                        const DataCell(Text('SEM FÉRIAS')),
                        const DataCell(Text('SEM FÉRIAS')),
                        const DataCell(Text('SEM FÉRIAS')),
                      ]);
                    }
                  }).toList()
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 40.0),
              child: DataTable(
                  dataRowMinHeight: 50,
                  dataRowMaxHeight: 80,
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold),
                  border: const TableBorder(
                    left: BorderSide(width: .5),
                    right: BorderSide(width: .5),
                    top: BorderSide(width: .5),
                    bottom: BorderSide(width: .5),
                    verticalInside: BorderSide(width: .5),
                  ),
                  columns: const [
                    DataColumn(label: Text('Feriados do mês')),
                  ],
                  rows: feriados.map((feriado) {
                    DateFormat format = DateFormat('dd/MM/yyyy');
                    final feriadoFormatted = format.format(feriado);
                    return DataRow(cells: [
                      DataCell(Text(feriadoFormatted, style: const TextStyle(fontWeight: FontWeight.bold))),
                    ]);
                  }).toList()
              ),
            ),
          ],
        ),
      ),
    );
  }
}
