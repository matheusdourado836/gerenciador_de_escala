import 'dart:convert';
import 'dart:html' as html;
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/servidor.dart';
import '../pages/home/home_page_desktop.dart';

class SheetProvider extends ChangeNotifier {
  List<Servidor> _servidoresList = [];
  List<List<Data?>> excelData = [];
  List<Map<String, dynamic>> excelExportData = [];
  Map<String, int> daysWorked = {};
  List<Map<String, dynamic>> monthsToGenerate = [];
  SharedPreferences? _prefs;
  String selectedOption = 'Janeiro';
  bool oneMonthOnly = false;
  bool loadRows = false;
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

      return;
    } catch (e, stack) {
      print('Erro ao carergar servidores $e /// $stack');
      //await Sentry.captureException(e);
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
      selectedOption = monthsList.first.values.first;
      monthsToGenerate = monthsList;
    }
  }

  void setFeriados() {
    final feriadosList = _prefs!.getStringList('feriados') ?? [];
    if (feriadosList.isNotEmpty) {
      feriados = feriadosList.map((f) => DateTime.parse(f)).toList();
    }
  }

  bool checkIfIsInVacation(Servidor servidor, DateTime currentDay) {
    if (servidor.ferias != null && servidor.ferias!.isNotEmpty) {
      final difference = servidor.ferias![1].difference(servidor.ferias![0]).inDays;
      DateTime firstVacationDay = (difference >= 11) ? calculate10DaysBefore(servidor.ultimoDiaUtil!) : servidor.ferias![0];
      final lastVacationDay = DateTime(servidor.ferias![1].year, servidor.ferias![1].month, servidor.ferias![1].day);
      bool isAfter = currentDay.isAfter(firstVacationDay);
      bool isBefore = currentDay.isBefore(lastVacationDay);
      bool isSameAsFirstDay = currentDay == firstVacationDay;
      bool isSameAsLastDay = currentDay == lastVacationDay;
      if((isSameAsFirstDay || isSameAsLastDay) || (isAfter && isBefore)) {
        return true;
      }
    }

    return false;
  }

  Servidor getFirstAvailable(List<Servidor> servidores, DateTime currentDay, int count) {
    if (count == servidores.length) {
      count = 0;
    }
    if(checkIfIsInVacation(servidores[count], currentDay)) {
      return getFirstAvailable(servidores, currentDay, count + 1);
    }else {
      count = servidores.indexOf(servidores[count]);
      return servidores[count];
    }
  }

  Future<void> pickAndReadExcel() async {
    try {
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

          final key = excel.tables.keys.first;
          var sheet = excel.tables[key]!;

          // A primeira linha contém os nomes das colunas (headers)
          List<String> headers = sheet.rows.first
              .map((cell) => cell?.value?.toString() ?? '')
              .toList();

          // Iterar sobre as linhas de dados (começando na segunda linha, ou seja, índice 1)
          for (var i = 1; i < sheet.rows.length; i++) {
            var row = sheet.rows[i];

            // Evitar adicionar objetos vazios
            if (row.every((cell) =>
            cell?.value == null || (cell?.value.toString().isEmpty ?? true))) {
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
          serializeExcelData(rowsData, feriadosListString);
        });
      });

      // Simula o clique no input de arquivo
      uploadInput.click();
    } catch (e) {
      await Sentry.captureException(e);
      return;
    }
  }

  Future<void> serializeExcelData(List<Map<String, String>> rowsData, List<String> feriadosListString) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String excelJson = '';
    // Serializando os dados mapeados
    excelJson = jsonEncode(rowsData);
    String monthsToGenerateString = jsonEncode(monthsToGenerate);
    await clearData(true);

    // // Salvando no SharedPreferences
    await Future.wait([
      prefs.setString('planilha', excelJson),
      prefs.setStringList('feriados', feriadosListString),
      prefs.setString('months', monthsToGenerateString),
    ]);
    loadServidores(false);
    loadRows = true;
    notifyListeners();
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
          fontFamily: getFontFamily(FontFamily.Arial)
        );

        c1.value = TextCellValue('Data');
        c2.value = TextCellValue('Servidor');
        c1.cellStyle = boldStyle;
        c2.cellStyle = boldStyle;

        for (int i = 0; i < excelExportData.length; i++) {
          var row = excelExportData[i];
          final key = row.keys.first;
          sheet.cell(CellIndex.indexByColumnRow(rowIndex: i + 1, columnIndex: 0)).value = TextCellValue(key);
          sheet.cell(CellIndex.indexByColumnRow(rowIndex: i + 1, columnIndex: 1)).value = TextCellValue(row[key]);
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
    daysWorked = {};
    excelExportData = [];
    _servidoresList = [];
    monthsToGenerate = [];
    loadRows = false;
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
