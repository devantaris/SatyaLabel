import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'ui/home_screen.dart';
import 'ui/auth/login_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SatyaLabelApp());
}

class SatyaLabelApp extends StatelessWidget {
  const SatyaLabelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppState>(
      future: AppState.create(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: Text('Failed to start: ${snapshot.error}')),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: const Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        return ChangeNotifierProvider<AppState>.value(
          value: snapshot.data!,
          child: MaterialApp(
            title: 'SatyaLabel',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            routes: {
              '/': (context) => const HomeScreen(),
              '/login': (context) => const LoginScreen(),
            },
          ),
        );
      },
    );
  }
}
