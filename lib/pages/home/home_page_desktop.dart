import 'package:escala_trabalho/controller/sheet_provider.dart';
import 'package:escala_trabalho/model/servidor.dart';
import 'package:escala_trabalho/pages/home/select_month_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../helper/date_helper.dart';

List<DateTime> feriados = [];

class HomePageDesktop extends StatefulWidget {
  const HomePageDesktop({super.key});

  @override
  State<HomePageDesktop> createState() => _HomePageDesktopState();
}

class _HomePageDesktopState extends State<HomePageDesktop> {
  late final SheetProvider sheetProvider;
  List<Widget> rows = [];
  List<List<Widget>> rowsDivided = [];

  @override
  void initState() {
    super.initState();
    sheetProvider = Provider.of<SheetProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => sheetProvider.loadServidores(false).whenComplete(() => setRows()));
  }

  void setRows() {
    List<Map<String, dynamic>> daysWorkedList = [];
    List<String> daysList = [];
    rows = [];
    List<Servidor> filaServidores = List.from(sheetProvider.servidoresList); // Cópia da lista original
    int count = 0;

    if (filaServidores.isNotEmpty) {
      // Iterar sobre todos os dias do mês
      for(var j = 0; j < sheetProvider.monthsToGenerate.length; j++) {
        int month = sheetProvider.monthsToGenerate[j]["index"];
        int days = getDiasDoMes(month);
        count = 0;
        for(int i = 0; i < days; i++) {
          DateTime currentDay = DateTime(2024, month, i + 1);
          String formattedDate = formatDateExtenso(currentDay);
          daysList.add(formattedDate);
          if (feriados.where((feriado) => feriado.month == currentDay.month && feriado.day == currentDay.day).isNotEmpty) {
            sheetProvider.excelExportData.add({
              formattedDate: 'FERIADO',
              'raw': currentDay,
            });
          } else if (!isWeekend(currentDay)) {
            if(sheetProvider.checkIfIsInVacation(filaServidores[count], currentDay)) {
              count = filaServidores.indexOf(sheetProvider.getFirstAvailable(filaServidores, currentDay, count));
            }

            // Adiciona a linha na tabela
            sheetProvider.excelExportData.add({
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
            sheetProvider.excelExportData.add({
              formattedDate: '',
              'raw': currentDay,
            });
          }
        }
      }

      for(var month in sheetProvider.monthsToGenerate) {
        rows = [];
        final dayList = daysList.where((day) => day.contains(month["mes"].toLowerCase().trim())).toList();
        final daysOfTheMonth = sheetProvider.excelExportData.where((day) => day.keys.first.contains(month["mes"].toLowerCase().trim())).toList();
        for(var i = 0; i < daysOfTheMonth.length; i++) {
          final key = daysOfTheMonth[i].keys.first;
          if(i == 0) {
            final index = month["index"] - 1 == 0 ? 12 : month["index"] - 1;
            final pastMonth = monthsMap.entries.firstWhere((v) => v.value == index);
            int days = getDiasDoMes(pastMonth.value) - getWeekdayIndex(key) + 2;
            for(var j = 0; j < getWeekdayIndex(key) - 1; j++) {
              rows.add(Text('${days++}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black45),));
            }
          }
          rows.add(Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dayList[i].split('de')[0], style: const TextStyle(fontWeight: FontWeight.bold),),
              Text(daysOfTheMonth[i][key])
            ],
          ));
        }
        rowsDivided.add(rows);
      }

      for (var data in daysWorkedList) {
        if (sheetProvider.daysWorked.containsKey(data["Servidor"])) {
          sheetProvider.daysWorked[data["Servidor"]] = sheetProvider.daysWorked[data["Servidor"]]! + 1;
        } else {
          sheetProvider.daysWorked[data["Servidor"]] = 1;
        }
      }
    }
  }

  Widget _dayOfTheWeek(String text) => Padding(
    padding: const EdgeInsets.only(left: 16, right: 4),
    child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center,)
  );


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distribuição de Servidores'),
        actions: [
          TextButton.icon(
              onPressed: () => showDialog(context: context, builder: (context) => const SelectMonthDialog()).then((res) {
                if(res ?? false) {
                  sheetProvider.pickAndReadExcel();
                }
              }),
              label: const Text('Adicionar planilha', style: TextStyle(fontSize: 20)),
              icon: const Icon(Icons.add, size: 32)
          ),
          TextButton.icon(onPressed: () => sheetProvider.createExcelTable(), label: const Text('Exportar planilha', style: TextStyle(fontSize: 20)), icon: const Icon(CupertinoIcons.table, size: 28),)
        ]
      ),
      body: Consumer<SheetProvider>(
        builder: (context, value, _) {
          if(value.loading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if(value.loadRows) {
            if(context.mounted) {
              setRows();
            }
          }
          if(value.servidoresList.isEmpty || rowsDivided.isEmpty) {
            return const Center(
              child: Text('NADA AQUI'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Column(
                    children: [
                      for(var i = 0; i < value.monthsToGenerate.length; i++)
                        ExpansionTile(
                          initiallyExpanded: i == 0,
                          childrenPadding: const EdgeInsets.fromLTRB(0, 8, 24, 8),
                          title: Text(value.monthsToGenerate[i]["mes"]),
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width * .7,
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _dayOfTheWeek('Segunda'),
                                      _dayOfTheWeek('Terça'),
                                      _dayOfTheWeek('Quarta'),
                                      _dayOfTheWeek('Quinta'),
                                      _dayOfTheWeek('Sexta'),
                                      _dayOfTheWeek('Sábado'),
                                      _dayOfTheWeek('Domingo')
                                    ],
                                  ),
                                  GridView.count(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.only(left: 16, bottom: 16),
                                    crossAxisCount: 7,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 1,
                                    children: List.generate(rowsDivided[i].length, (index) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(width: 2),
                                          borderRadius: BorderRadius.circular(8)
                                        ),
                                        child: rowsDivided[i][index],
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            )
                          ],
                        )
                    ],
                  ),
                ),
                Flexible(
                  flex: 0,
                  fit: FlexFit.tight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DataTable(
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
                              DataColumn(label: Text('Qtd. vezes na escala')),
                              DataColumn(label: Text('Trabalha até')),
                              DataColumn(label: Text('Volta em'), headingRowAlignment: MainAxisAlignment.center),
                              DataColumn(label: Text('Férias'), headingRowAlignment: MainAxisAlignment.center),
                              DataColumn(label: Text('Preparação'), headingRowAlignment: MainAxisAlignment.center),
                            ],
                            rows: value.servidoresList.map((servidor) {
                              if(servidor.ultimoDiaUtil != null) {
                                DateFormat format = DateFormat('dd/MM/yyyy');
                                final inicioFerias = format.format(servidor.ferias![0]);
                                final fimFerias = format.format(servidor.ferias![1]);
                                final difference = servidor.ferias![1].difference(servidor.ferias![0]).inDays;
                                final workUntil = difference >= 11 ? formatDateExtenso(calculate10DaysBefore(servidor.ultimoDiaUtil!)) : formatDateExtenso(servidor.ferias![0]);
                                final preparation = difference >= 11 ? formatDateExtenso(calculate10DaysBefore(servidor.ultimoDiaUtil!)) : 'FÉRIAS < 11 DIAS';
                                return DataRow(cells: [
                                  DataCell(Text(servidor.nome, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Center(child: Text((value.daysWorked[servidor.nome] ?? 0).toString(), style: const TextStyle(fontWeight: FontWeight.bold)))),
                                  DataCell(Text(workUntil)),
                                  DataCell(Text(formatDateExtenso(servidor.diaDeRetorno!))),
                                  DataCell(Text('$inicioFerias à $fimFerias')),
                                  DataCell(Text(preparation)),
                                ]);
                              }else {
                                return DataRow(cells: [
                                  DataCell(Text(servidor.nome, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Center(child: Text((value.daysWorked[servidor.nome] ?? 0).toString(), style: const TextStyle(fontWeight: FontWeight.bold)))),
                                  const DataCell(Text('SEM FÉRIAS', textAlign: TextAlign.center,)),
                                  const DataCell(Text('SEM FÉRIAS', textAlign: TextAlign.center,)),
                                  const DataCell(Center(child: Text('SEM FÉRIAS'))),
                                  const DataCell(Center(child: Text('SEM FÉRIAS', textAlign: TextAlign.center,))),
                                ]);
                              }
                            }).toList()
                        ),
                        const SizedBox(height: 24),
                        DataTable(
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.large(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        onPressed: () {
          sheetProvider.clearData(true).whenComplete(() => setState(() {
            rows = [];
            rowsDivided = [];
          }));
        },
        child: const Icon(Icons.delete, size: 48),
      ),
    );
  }
}
