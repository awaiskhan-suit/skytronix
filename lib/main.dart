import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'admin/add_customer.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Digi Khata',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CustomerScreen(),
    );
  }
}

