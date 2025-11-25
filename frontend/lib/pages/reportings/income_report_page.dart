import 'package:flutter/material.dart';

class IncomeReportPage extends StatefulWidget {
  const IncomeReportPage({super.key});

  @override
  State<IncomeReportPage> createState() => _IncomeReportPageState();
}

class _IncomeReportPageState extends State<IncomeReportPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Income Report')));
  }
}
