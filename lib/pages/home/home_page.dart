import 'package:escala_trabalho/controller/sheet_provider.dart';
import 'package:escala_trabalho/model/servidor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../helper/date_helper.dart';

List<DateTime> feriados = [];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final SheetProvider sheetProvider;

  @override
  void initState() {
    super.initState();
    sheetProvider = Provider.of<SheetProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => sheetProvider.loadServidores());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distribuição de Servidores'),
        actions: [
          TextButton.icon(
              onPressed: sheetProvider.pickAndReadExcel,
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
          if(value.servidoresList.isEmpty) {
            return const Center(
              child: Text('NADA AQUI'),
            );
          }

          return SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DataTable(
                  columns: const [
                    DataColumn(label: Text('Data')),
                    DataColumn(label: Text('Servidor')),
                  ],
                  rows: value.rows,
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
                        DataColumn(label: Text('Qtd. vezes na escala')),
                        DataColumn(label: Text('Trabalha até')),
                        DataColumn(label: Text('Volta em')),
                        DataColumn(label: Text('Período de férias')),
                        DataColumn(label: Text('Período de preparação')),
                      ],
                      rows: value.servidoresList.map((servidor) {
                        if(servidor.ultimoDiaUtil != null) {
                          DateFormat format = DateFormat('dd/MM/yyyy');
                          final inicioFerias = format.format(servidor.ferias![0]);
                          final fimFerias = format.format(servidor.ferias![1]);
                          return DataRow(cells: [
                            DataCell(Text(servidor.nome, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text((value.daysWorked[servidor.nome] ?? 0).toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(formatDateExtenso(calculate10DaysBefore(servidor.ultimoDiaUtil!)))),
                            DataCell(Text(formatDateExtenso(servidor.diaDeRetorno!))),
                            DataCell(Text('$inicioFerias à $fimFerias')),
                            DataCell(Text(formatDateExtenso(calculatePreparation(servidor.ferias![0])))),
                          ]);
                        }else {
                          return DataRow(cells: [
                            DataCell(Text(servidor.nome, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text((value.daysWorked[servidor.nome] ?? 0).toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton.large(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        onPressed: () => sheetProvider.clearData(),
        child: const Icon(Icons.delete, size: 48),
      ),
    );
  }
}
