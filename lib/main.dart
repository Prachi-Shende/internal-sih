import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'theme/app_theme.dart';
import 'services/app_state.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/auth/login_screen.dart';
import 'services/api_service.dart';

// Your web app's Firebase configuration
const firebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyAY0O94llv1TGlCNtlyE7SlENP9IWBV16E",
  authDomain: "tourist-safety-eaefa.firebaseapp.com",
  projectId: "tourist-safety-eaefa",
  storageBucket: "tourist-safety-eaefa.firebasestorage.app",
  messagingSenderId: "947102691762",
  appId: "1:947102691762:web:473fa3a13263a986f3b4ab",
  measurementId: "G-2Z3P5X0EB6",
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  await ApiService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const TravaraApp(),
    ),
  );
}

class TravaraApp extends StatelessWidget {
  const TravaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TRAVARA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const OnboardingScreen(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasData) {
          // User is logged in
          return const MainNavigationWrapper();
        }
        
        // User is not logged in
        return const LoginScreen();
      },
    );
  }
}
