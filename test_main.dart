import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TUK CU Test App',
      home: Scaffold(
        appBar: AppBar(
          title: Text('TUK CU Mass Messaging App'),
          backgroundColor: Colors.blue,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'TUK CU Mass Messaging App',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text(
                'App is running successfully!',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  print('Button pressed!');
                },
                child: Text('Test Button'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}