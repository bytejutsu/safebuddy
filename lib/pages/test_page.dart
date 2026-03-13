import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {

  final _future = Supabase.instance.client
      .from('instruments')
      .select();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final List instruments = snapshot.data as List;

          return ListView.builder(
            itemCount: instruments.length,
            itemBuilder: (context, index) {

              final instrument = instruments[index];

              return ListTile(
                title: Text(instrument['name']),
              );
            },
          );
        },
      ),
    );
  }
}