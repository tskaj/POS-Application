import 'package:flutter/material.dart';

class TaxReportPage extends StatefulWidget {
  const TaxReportPage({super.key});

  @override
  State<TaxReportPage> createState() => _TaxReportPageState();
}

class _TaxReportPageState extends State<TaxReportPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Tax Report')));
  }
}
