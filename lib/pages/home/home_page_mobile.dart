import 'package:escala_trabalho/pages/home/select_month_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../controller/sheet_provider.dart';
import '../../helper/date_helper.dart';
import '../../model/servidor.dart';
import 'home_page_desktop.dart';

class HomePageMobile extends StatefulWidget {
  const HomePageMobile({super.key});

  @override
  State<HomePageMobile> createState() => _HomePageMobileState();
}

class _HomePageMobileState extends State<HomePageMobile> {
  late final SheetProvider sheetProvider;
  final PageController _controller = PageController();
  List<Widget> rows = [];
  List<List<Widget>> rowsDivided = [];
  int i = 0;
  bool _nextPage = false;

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
    rowsDivided = [];
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
              formattedDate: 'FIM DE SEMANA',
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
          rows.add(Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 24),
                child: Text(dayList[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),),
              ),
              Text(daysOfTheMonth[i][key], style: const TextStyle(fontSize: 12),)
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

  Widget textFont12(String text) => Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12),);
  
  Widget textBold(String text) => Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distribuição de Servidores'),
          actions: [
            IconButton(
                onPressed: () => showDialog(context: context, builder: (context) => const SelectMonthDialog()).then((res) {
                  if(res ?? false) {
                    sheetProvider.pickAndReadExcel();
                  }
                }),
                icon: const Icon(Icons.add),
              tooltip: 'Adicionar planilha',
            ),
            IconButton(onPressed: () => sheetProvider.createExcelTable(), icon: const Icon(Icons.download), tooltip: 'Baixar planilha',)
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
              value.loadRows = false;
            }
          }
          if(value.servidoresList.isEmpty || rowsDivided.isEmpty) {
            return const Center(
              child: Text('NADA AQUI'),
            );
          }

          return PageView(
            controller: _controller,
            allowImplicitScrolling: false,
            onPageChanged: (page) => setState(() => _nextPage = (page == 0) ? false : true),
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    DropdownButton<String>(
                        isExpanded: true,
                        value: value.selectedOption,
                        items: value.monthsToGenerate.map((Map<String, dynamic> option) =>
                          DropdownMenuItem<String>(value: option.values.first, child: Text(option.values.first, style: const TextStyle(fontSize: 16),))
                        ).toList(),
                        onChanged: value.oneMonthOnly ? null : (String? newValue) {
                          if(newValue != null) {
                            value.selectedOption = newValue;
                            final option = value.monthsToGenerate.firstWhere((e) => e.values.first == newValue);
                            setState(() => i = value.monthsToGenerate.indexOf(option));
                          }
                        }
                    ),
                    ListView.separated(
                      itemCount: rowsDivided[i].length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                          child: rowsDivided[i][index],
                        );
                      }
                    )
                  ],
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(8.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DataTable(
                          horizontalMargin: 8,
                          columnSpacing: 8,
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
                          columns: [
                            DataColumn(label: textFont12('Nome')),
                            DataColumn(label: textFont12('Qtd. na escala')),
                            DataColumn(label: textFont12('Trabalha até')),
                            DataColumn(label: textFont12('Volta em'), headingRowAlignment: MainAxisAlignment.center),
                            DataColumn(label: textFont12('Férias'), headingRowAlignment: MainAxisAlignment.center),
                            DataColumn(label: textFont12('Preparação'), headingRowAlignment: MainAxisAlignment.center),
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
                                DataCell(textBold(servidor.nome)),
                                DataCell(Center(child: textBold((value.daysWorked[servidor.nome] ?? 0).toString()))),
                                DataCell(textFont12(workUntil)),
                                DataCell(textFont12(formatDateExtenso(servidor.diaDeRetorno!))),
                                DataCell(textFont12('$inicioFerias à $fimFerias')),
                                DataCell(textFont12(preparation)),
                              ]);
                            }else {
                              return DataRow(cells: [
                                DataCell(textBold(servidor.nome)),
                                DataCell(Center(child: textBold((value.daysWorked[servidor.nome] ?? 0).toString()))),
                                DataCell(textFont12('SEM FÉRIAS')),
                                DataCell(textFont12('SEM FÉRIAS')),
                                DataCell(Center(child: textFont12('SEM FÉRIAS'))),
                                DataCell(Center(child: textFont12('SEM FÉRIAS'))),
                              ]);
                            }
                          }).toList()
                      ),
                      const SizedBox(width: 16),
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
              )
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            onPressed: () {
              if(rows.isNotEmpty) {
                setState(() => _nextPage = !_nextPage);
                (_nextPage)
                    ? _controller.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)
                    : _controller.previousPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
              }
            },
            child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return RotationTransition(turns: animation, child: child);
                },
              child: Icon(
                key: ValueKey<bool>(_nextPage),
                !_nextPage ? Icons.info : Icons.arrow_back_ios_new_rounded
              )
            ),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            onPressed: () {
              sheetProvider.clearData(true).whenComplete(() => setState(() {
                rows = [];
                rowsDivided = [];
                _nextPage = false;
              }));
            },
            child: const Icon(Icons.delete),
          ),
        ],
      ),
    );
  }
}
