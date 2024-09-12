import 'dart:convert';

import 'package:escala_trabalho/model/servidor.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<List<Data?>> excelData = [];
  List<Servidor> servidoresList = [];
  int month = 0;
  int days = 0;

  @override
  void initState() {
    super.initState();
    month = DateTime.now().month + 1;
    days = getDiasDoMes();
    loadServidores();
  }

  int getDiasDoMes() {
    // Cria uma data no primeiro dia do mês desejado
    DateTime primeiroDiaDoMes = DateTime(2024, month, 1);

    // Cria uma data no primeiro dia do mês seguinte
    DateTime primeiroDiaDoMesSeguinte = DateTime(2024, month + 1, 1);

    // Calcula a diferença em dias
    int diasNoMes = primeiroDiaDoMesSeguinte.difference(primeiroDiaDoMes).inDays;

    print('O mês $month tem $diasNoMes dias.');

    return diasNoMes;
  }

  // Função para carregar os servidores do JSON
  void loadServidores() {

    servidoresList = servidores.map((json) => fromJson(json)).toList();

    setState(() {}); // Atualiza a tela após carregar os dados
  }

  String formatDateExtenso(DateTime date) {
    return DateFormat('d \'de\' MMMM', 'pt_BR').format(date);
  }

  Future<void> _pickAndReadExcel() async {
    // Abre o file picker para selecionar um arquivo
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'], // Permite apenas arquivos Excel
    );

    if (result != null) {
      Uint8List? fileBytes = result.files.first.bytes;
      if (fileBytes != null) {
        // Carrega o arquivo Excel
        var excel = Excel.decodeBytes(fileBytes);

        // Lê os dados da primeira planilha (sheet)
        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table];
          if (sheet != null) {
            setState(() {
              excelData = sheet.rows;
            });
            break; // Sai após a primeira planilha
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distribuição de Servidores'),
        actions: [
          IconButton(
            onPressed: _pickAndReadExcel,
            icon: const Icon(Icons.add, color: Colors.black,)
          )
        ]
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

                  // Iterar sobre todos os dias de outubro
                  for (int i = 0; i < days; i++) {
                    DateTime currentDay = DateTime(2024, month, i + 1);
                    String formattedDate = formatDateExtenso(currentDay);


                    // Pega o primeiro servidor da fila
                    Servidor servidorAtual = filaServidores.first;
                    //print('SERVIDOR ATUAL ${servidorAtual.nome}');

                    // Verifica se o servidor está de férias ou nos 10 dias anteriores ao início das férias
                    bool estaDeFerias = false;
                    if (servidorAtual.ferias != null && servidorAtual.ferias!.isNotEmpty) {
                    // Verifica se o servidor está de férias no dia atual ou nos 10 dias anteriores
                    DateTime dezDiasAntes = calculate10DaysBefore(servidorAtual.ultimoDiaUtil!);
                    //   print('ULTIMO DIA QUE ${servidorAtual.nome} PODE TRABALHAR $dezDiasAntes E VAI VOLTAR ${servidorAtual.diaDeRetorno} /// CURRENT DAY ${currentDay} ${currentDay.isAfter(dezDiasAntes) && currentDay.isBefore(servidorAtual.diaDeRetorno!)}');
                    if ((currentDay == dezDiasAntes || currentDay.isAfter(dezDiasAntes)) && currentDay.isBefore(servidorAtual.diaDeRetorno!)) {
                      estaDeFerias = true;
                    }

                    }
                    if (estaDeFerias) {
                      filaServidores.removeAt(0); // Remove da frente
                      filaServidores.add(servidorAtual); // Adiciona no final

                      // Tenta o próximo servidor
                      servidorAtual = filaServidores.first;
                    }
                    //
                    for(var servidor in servidoresList) {
                      if (currentDay == servidor.diaDeRetorno) {
                        filaServidores.insert(0, servidor); // Adiciona o novo servidor no início da fila
                        servidorAtual = servidor;
                      }
                    }

                    // Adiciona a linha na tabela
                    if(!isWeekend(currentDay)) {
                      rows.add(DataRow(
                        cells: [
                          DataCell(Text(formattedDate)),
                          DataCell(Text(servidorAtual.nome)),
                        ],
                      ));
                    }else {
                      rows.add(DataRow(
                        cells: [
                          DataCell(Text(formattedDate)),
                          const DataCell(Text('FIM DE SEMANA')),
                        ],
                      ));
                    }

                    // Move o servidor atual para o final da fila após alocar o dia
                    filaServidores.removeAt(0);
                    filaServidores.add(servidorAtual);
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
                  ],
                  rows: servidoresList.map((servidor) {
                    if(servidor.ultimoDiaUtil != null) {
                      return DataRow(cells: [
                        DataCell(Text(servidor.nome, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(formatDateExtenso(calculate10DaysBefore(servidor.ultimoDiaUtil!)))),
                        DataCell(Text(formatDateExtenso(servidor.diaDeRetorno!))),
                      ]);
                    }else {
                      return DataRow(cells: [
                        DataCell(Text(servidor.nome, style: const TextStyle(fontWeight: FontWeight.bold))),
                        const DataCell(Text('SEM FÉRIAS')),
                        const DataCell(Text('SEM FÉRIAS')),
                      ]);
                    }
                  }).toList()
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
