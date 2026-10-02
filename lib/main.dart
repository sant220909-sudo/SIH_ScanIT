import 'package:flutter/material.dart';
import 'package:cyber_nova/screens/home_screen.dart';
import 'package:cyber_nova/screens/analysis_screen.dart';
import 'package:cyber_nova/screens/report_screen.dart';
import 'package:cyber_nova/screens/pdf_preview_screen.dart';
import 'package:cyber_nova/utils/app_theme.dart';

void main() {
  runApp(const CyberNovaApp());
}

class CyberNovaApp extends StatelessWidget {
  const CyberNovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cyber Nova',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/analysis': (context) => const AnalysisScreen(),
        '/report': (context) => const ReportScreen(),
        '/pdf-preview': (context) => const PdfPreviewScreen(),
      },
    );
  }
}
