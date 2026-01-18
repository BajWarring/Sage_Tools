import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core.dart';

class SettingsView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        ListTile(
          leading: Icon(Icons.palette),
          title: Text("Theme"),
          subtitle: Text(ref.watch(currentThemeProvider).name),
          onTap: () => showModalBottomSheet(
            context: context, 
            builder: (c) => ThemeSelectorSheet()
          ),
        ),
        ListTile(leading: Icon(Icons.folder), title: Text("Storage"), subtitle: Text("/Internal/SageTools")),
        ListTile(leading: Icon(Icons.info), title: Text("Version"), subtitle: Text("7.2.0 (Split)")),
      ],
    );
  }
}

class ThemeSelectorSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 200,
      padding: EdgeInsets.all(16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: themes.length,
        itemBuilder: (c, i) => GestureDetector(
          onTap: () => ref.read(currentThemeProvider.notifier).state = themes[i],
          child: Container(
            width: 80, margin: EdgeInsets.all(8),
            color: themes[i].primary,
          ),
        ),
      ),
    );
  }
}
