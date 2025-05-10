import 'package:blurspace/providers/media_provider.dart';
import 'package:blurspace/widget/media_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlurSpace', // atau nama lain yang lu pilih bro
      theme: ThemeData.dark(),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaList = ref.watch(mediaListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Album Media'),
      ),
      body: MediaGrid(mediaList: mediaList),
    );
  }
}
