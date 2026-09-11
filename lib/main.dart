import 'package:flutter/material.dart';
import 'package:kids_church_mobile/api/kids_church_api.dart';
import 'package:kids_church_mobile/state/app_controller.dart';
import 'package:kids_church_mobile/storage/mobile_storage.dart';
import 'package:kids_church_mobile/ui/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(
    api: KidsChurchApi(),
    storage: MobileStorage(),
  );
  runApp(KidsChurchMobileApp(controller: controller));
}

class KidsChurchMobileApp extends StatefulWidget {
  const KidsChurchMobileApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<KidsChurchMobileApp> createState() => _KidsChurchMobileAppState();
}

class _KidsChurchMobileAppState extends State<KidsChurchMobileApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.onAppResumed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xff315b7d);
    return MaterialApp(
      title: 'Kids Church',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: AppShell(controller: widget.controller),
    );
  }
}
