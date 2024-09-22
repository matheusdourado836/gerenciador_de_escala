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
  List<Map<String, dynamic>> monthsToGenerate = [];
  SharedPreferences? _prefs;

  bool loading = false;

  List<Servidor> get servidoresList => _servidoresList;

  // Função para carregar os servidores do JSON
  Future<void> loadServidores(bool clearPersistence) async {
    try {
      await clearData(clearPersistence);
      _prefs ??= await SharedPreferences.getInstance();
      setServidores();
      setFeriados();
      setMonthsList();
      try {
        setRows();
      }catch(e, stack) {
        debugPrint('Erro ao gerar rows: $e');
        await Sentry.captureException(e, stackTrace: stack);
      }

      return;
    } catch (e, stack) {
      final err = e as RangeError;
      print('Erro ao carergar servidores $err /// ${err.stackTrace}');
      await Sentry.captureException(e);
      return;
    }
  }

  void setServidores() {
    final servidoresJson = _prefs!.getString('planilha');

    if (servidoresJson?.isNotEmpty ?? false) {
      for (var servidor in jsonDecode(servidoresJson!)) {
        _servidoresList.add(fromJson(servidor));
      }
    }
  }

  void setMonthsList() {
    final monthsString = _prefs!.getString('months') ?? '';
    if (monthsString.isNotEmpty) {
      final monthsObj = jsonDecode(monthsString);
      List<Map<String, dynamic>> monthsList = [];
      for (var month in monthsObj) {
        monthsList.add(month);
      }
      monthsToGenerate = monthsList;
    }
  }

  void setFeriados() {
    final feriadosList = _prefs!.getStringList('feriados') ?? [];
    if (feriadosList.isNotEmpty) {
      feriados = feriadosList.map((f) => DateTime.parse(f)).toList();
    }
  }

  bool checkIfIsInVacation(List<Servidor> servidores, DateTime currentDay) {
    bool isInVacation = false;
    for(Servidor servidor in servidores) {
      if (servidor.ferias != null && servidor.ferias!.isNotEmpty) {
        DateTime dezDiasAntes = calculate10DaysBefore(servidor.ultimoDiaUtil!);
        final lastVacationDay = DateTime(servidor.ferias![1].year, servidor.ferias![1].month, servidor.ferias![1].day);
        bool isAfter = currentDay.isAfter(dezDiasAntes);
        bool isBefore = currentDay.isBefore(lastVacationDay);
        bool isSameAsTenDays = currentDay == dezDiasAntes;
        bool isSameAsLastDay = currentDay == lastVacationDay;
        if((isSameAsTenDays || isSameAsLastDay) || (isAfter && isBefore)) {
          isInVacation = true;
          servidores.remove(servidor);
        }
      }
    }

    return isInVacation;
  }

  void setRows() {
    List<Map<String, dynamic>> daysWorkedList = [];
    List<String> daysList = [];
    rows = [];
    List<Servidor> filaServidores = List.from(_servidoresList); // Cópia da lista original
    servidoresDeFerias = filaServidores.where((servidor) => servidor.diaDeRetorno != null).toList();
    int count = 0;

    if (filaServidores.isNotEmpty) {
      // Iterar sobre todos os dias do mês
      for (var j = 0; j < monthsToGenerate.length; j++) {
        int month = monthsToGenerate[j]["index"];
        int days = getDiasDoMes(month);
        for (int i = 0; i < days; i++) {
          DateTime currentDay = DateTime(2024, month, i + 1);
          String formattedDate = formatDateExtenso(currentDay);
          daysList.add(formattedDate);
          if (feriados.where((feriado) => feriado.month == currentDay.month && feriado.day == currentDay.day).isNotEmpty) {
            excelExportData.add({
              formattedDate: 'FERIADO',
              'raw': currentDay,
            });
          } else if (!isWeekend(currentDay)) {
            if(checkIfIsInVacation(filaServidores, currentDay)) {
              if(count > 0) {
                count--;
              }
            }

            for(var servidor in servidoresDeFerias) {
              if(currentDay.day == servidor.diaDeRetorno!.day && currentDay.month == servidor.diaDeRetorno!.month) {
                filaServidores.insert(count, servidor);
              }
            }
            //print(filaServidores);
            // Adiciona a linha na tabela
            excelExportData.add({
              formattedDate: filaServidores[count].nome,
              'raw': currentDay,
            });
            daysWorkedList.add({
              'Data': formattedDate,
              'Servidor': filaServidores[count].nome
            });

            if (count == filaServidores.length - 1) {
              count = 0;
            } else {
              count++;
            }
          } else {
            excelExportData.add({
              formattedDate: 'FIM DE SEMANA',
              'raw': currentDay,
            });
          }
        }
      }

      for(var (index, day) in excelExportData.indexed) {
        final dayKey = day.keys.first;
        rows.add(DataRow(cells: [
          DataCell(Text(daysList[index])),
          DataCell(Text(day[dayKey])),
        ]));
      }

      for (var data in daysWorkedList) {
        if (daysWorked.containsKey(data["Servidor"])) {
          daysWorked[data["Servidor"]] = daysWorked[data["Servidor"]]! + 1;
        } else {
          daysWorked[data["Servidor"]] = 1;
        }
      }
    }
    notifyListeners();
  }

  Future<void> pickAndReadExcel() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String excelJson = '';
      List<String> feriadosListString = [];
      // Cria um input de arquivo HTML
      final html.FileUploadInputElement uploadInput =
          html.FileUploadInputElement();
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
            List<String> headers = sheet.rows.first
                .map((cell) => cell?.value?.toString() ?? '')
                .toList();

            // Iterar sobre as linhas de dados (começando na segunda linha, ou seja, índice 1)
            for (var i = 1; i < sheet.rows.length; i++) {
              var row = sheet.rows[i];

              // Evitar adicionar objetos vazios
              if (row.every((cell) =>
                  cell?.value == null ||
                  (cell?.value.toString().isEmpty ?? true))) {
                continue;
              }

              Map<String, String> rowData = {};

              for (var j = 0; j < headers.length; j++) {
                String key = headers[j];

                // Ignorando a coluna de feriados/recesso
                if (key.toLowerCase().contains('feriado')) {
                  if (row[j]?.value?.toString().isNotEmpty ?? false) {
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
          String monthsToGenerateString = jsonEncode(monthsToGenerate);

          // // Salvando no SharedPreferences
          await Future.wait([
            prefs.setString('planilha', excelJson),
            prefs.setStringList('feriados', feriadosListString),
            prefs.setString('months', monthsToGenerateString),
          ]);
          await loadServidores(false);
        });
      });

      // Simula o clique no input de arquivo
      uploadInput.click();
    } catch (e) {
      await Sentry.captureException(e);
      return;
    }
  }

  Future<void> createExcelTable() async {
    try {
      if (excelExportData.isNotEmpty) {
        var excel = Excel.createExcel();
        String sheetName =
            'Escala mês de ${DateFormat('MMMM', 'pt_BR').format(DateTime.now().add(const Duration(days: 30)))}';
        Sheet sheet = excel[sheetName];
        sheet.setColumnWidth(0, 14);
        sheet.setColumnWidth(1, 18);
        sheet.setRowHeight(0, 20);
        excel.setDefaultSheet(sheetName);
        excel.delete('Sheet1');
        final c1 =
            sheet.cell(CellIndex.indexByColumnRow(rowIndex: 0, columnIndex: 0));
        final c2 =
            sheet.cell(CellIndex.indexByColumnRow(rowIndex: 0, columnIndex: 1));

        CellStyle boldStyle = CellStyle(
          bold: true,
          fontFamily: getFontFamily(
              FontFamily.Arial), // Define a fonte como Arial, por exemplo
        );

        c1.value = TextCellValue('Data');
        c2.value = TextCellValue('Servidor');
        c1.cellStyle = boldStyle;
        c2.cellStyle = boldStyle;

        for (int i = 0; i < excelExportData.length; i++) {
          var row = excelExportData[i];
          sheet
              .cell(CellIndex.indexByColumnRow(rowIndex: i + 1, columnIndex: 0))
              .value = TextCellValue(row['Data']);
          sheet
              .cell(CellIndex.indexByColumnRow(rowIndex: i + 1, columnIndex: 1))
              .value = TextCellValue(row['Servidor']);
        }

        // Salvar o arquivo Excel como bytes
        excel.save(fileName: '$sheetName.xlsx');
      }
    } catch (e) {
      await Sentry.captureException(e);
      return;
    }
  }

  Future<void> clearData(bool deletePersistence) async {
    rows = [];
    daysWorked = {};
    excelExportData = [];
    _servidoresList = [];
    servidoresDeFerias = [];
    monthsToGenerate = [];
    if (deletePersistence) {
      await Future.wait([
        _prefs!.remove('planilha'),
        _prefs!.remove('feriados'),
        _prefs!.remove('months')
      ]);
    }
    notifyListeners();
  }
}
