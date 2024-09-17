import 'dart:convert';
import 'dart:html' as html;
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helper/date_helper.dart';
import '../model/servidor.dart';
import '../pages/home/home_page.dart';

class SheetProvider extends ChangeNotifier {
  List<Servidor> _servidoresList = [];
  List<List<Data?>> excelData = [];
  List<Servidor> servidoresDeFerias = [];
  List<Map<String, dynamic>> excelExportData = [];
  List<DataRow> rows = [];
  Map<String, int> daysWorked = {};
  String excelJson = '';
  List<String> feriadosListString = [];

  bool loading = false;

  List<Servidor> get servidoresList => _servidoresList;

  // Função para carregar os servidores do JSON
  Future<void> loadServidores() async {
    try {
      loading = true;
      notifyListeners();
      daysWorked.clear();
      excelExportData = [];
      _servidoresList = [];
      // final SharedPreferences prefs = await SharedPreferences.getInstance();
      //
      // final servidoresJson = prefs.getString('planilha');
      // final feriadosList = prefs.getStringList('feriados') ?? [];
      feriados = feriadosListString.map((f) => DateTime.parse(f)).toList();
      if(excelJson.isNotEmpty) {
        for(var servidor in jsonDecode(excelJson)) {
          _servidoresList.add(fromJson(servidor));
        }
      }

      setRows();
      loading = false;
      notifyListeners();

      return;
    }catch(e) {
      await Sentry.captureException(e);
      return;
    }
  }

  void setRows() {
    rows = [];
    List<Servidor> filaServidores = List.from(_servidoresList); // Cópia da lista original
    int count = 0;
    int days = getDiasDoMes();
    int month = DateTime.now().month + 1;

    if(filaServidores.isNotEmpty) {
      // Iterar sobre todos os dias do mês
      for (int i = 0; i < days; i++) {
        DateTime currentDay = DateTime(2024, month, i + 1);
        String formattedDate = formatDateExtenso(currentDay);
        if(feriados.where((feriado) => feriado.month == currentDay.month && feriado.day == currentDay.day).isNotEmpty) {
          excelExportData.add({'Data': formattedDate, 'Servidor': 'FERIADO'});
          rows.add(DataRow(
            cells: [
              DataCell(Text(formattedDate)),
              const DataCell(Text('FERIADO')),
            ],
          ));
        }else if(!isWeekend(currentDay)) {
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

          // for(var servidor in servidoresDeFerias) {
          //   if ((currentDay.day == servidor.diaDeRetorno!.day) && currentDay.month == servidor.diaDeRetorno!.month) {
          //     filaServidores.insert(count, servidor); // Adiciona o novo servidor no lugar do dia de retorno
          //     servidoresDeFerias.remove(servidor); // Remove servidor da lista de ferias
          //   }
          // }

          if(count == filaServidores.length) {
            count = 0;
          }

          if (daysWorked.containsKey(filaServidores[count].nome)) {
            daysWorked[filaServidores[count].nome] = daysWorked[filaServidores[count].nome]! + 1;
          } else {
            daysWorked[filaServidores[count].nome] = 1;
          }
          // Adiciona a linha na tabela
          excelExportData.add({'Data': formattedDate, 'Servidor': filaServidores[count].nome});
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
          excelExportData.add({'Data': formattedDate, 'Servidor': 'FIM DE SEMANA'});
          rows.add(DataRow(
            cells: [
              DataCell(Text(formattedDate)),
              const DataCell(Text('FIM DE SEMANA')),
            ],
          ));
        }
      }
    }
    notifyListeners();
  }

  Future<void> pickAndReadExcel() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
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
                    feriadosListString.add(row[j]?.value?.toString() ?? '');
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
          excelJson = jsonEncode(rowsData);

          // // Salvando no SharedPreferences
          // Future.wait([
          //   prefs.setString('planilha', excelData),
          //   prefs.setStringList('feriados', feriadosList)
          // ]);
          await loadServidores();
        });
      });

      // Simula o clique no input de arquivo
      uploadInput.click();
    }catch(e) {
      await Sentry.captureException(e);
      return;
    }
  }

  Future<void> createExcelTable() async {
    try {
      if(excelExportData.isNotEmpty) {
        var excel = Excel.createExcel();
        String sheetName = 'Escala mês de ${DateFormat('MMMM', 'pt_BR').format(DateTime.now().add(const Duration(days: 30)))}';
        Sheet sheet = excel[sheetName];
        sheet.setColumnWidth(0, 14);
        sheet.setColumnWidth(1, 18);
        sheet.setRowHeight(0, 20);
        excel.setDefaultSheet(sheetName);
        excel.delete('Sheet1');
        final c1 = sheet.cell(CellIndex.indexByColumnRow(rowIndex: 0, columnIndex: 0));
        final c2 = sheet.cell(CellIndex.indexByColumnRow(rowIndex: 0, columnIndex: 1));

        CellStyle boldStyle = CellStyle(
          bold: true,
          fontFamily: getFontFamily(FontFamily.Arial), // Define a fonte como Arial, por exemplo
        );

        c1.value = TextCellValue('Data');
        c2.value = TextCellValue('Servidor');
        c1.cellStyle = boldStyle;
        c2.cellStyle = boldStyle;

        for(int i = 0; i < excelExportData.length; i++) {
          var row = excelExportData[i];
          sheet.cell(CellIndex.indexByColumnRow(rowIndex: i + 1, columnIndex: 0)).value = TextCellValue(row['Data']);
          sheet.cell(CellIndex.indexByColumnRow(rowIndex: i + 1, columnIndex: 1)).value = TextCellValue(row['Servidor']);
        }

        // Salvar o arquivo Excel como bytes
        excel.save(fileName: '$sheetName.xlsx');

        // // Criar um link de download no navegador
        // final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        // final url = html.Url.createObjectUrlFromBlob(blob);
        // html.AnchorElement(href: url)
        //   ..setAttribute('download', 'tabelas_exportadas.xlsx')
        //   ..click();
        // html.Url.revokeObjectUrl(url); // Limpa a URL temporária
      }
    }catch(e) {
      await Sentry.captureException(e);
      return;
    }
  }

  Future<void> clearData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    loading = true;
    notifyListeners();
    daysWorked.clear();
    excelExportData = [];
    _servidoresList = [];
    // await Future.wait([
    //   prefs.remove('planilha'),
    //   prefs.remove('feriados')
    // ]);
    loading = false;
    notifyListeners();
  }
}