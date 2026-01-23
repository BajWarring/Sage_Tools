import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../core.dart';

class SettingsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final storage = ref.watch(storagePathProvider);
    final p = theme.primary;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 60, 16, 100),
      children: [
        Text("GENERAL", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 1.0)),
        SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[100]!)),
          child: Column(
            children: [
              _SettingTile(
                icon: Icons.palette, color: p, title: "Appearance", value: theme.name,
                onTap: () => _showThemeModal(context, ref),
              ),
              Divider(height: 1, indent: 60),
              _SettingTile(
                icon: Icons.storage, color: p, title: "Storage Location", value: storage.split('/').last,
                onTap: () => _showStorageModal(context, ref),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 32),
        Text("ABOUT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 1.0)),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[100]!)),
          child: Column(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: p[500], borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text("S", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 12),
              Text("Sage Tools", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              Text("Version 1.0.3", style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text("Check for Updates", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
              )
            ],
          ),
        )
      ],
    );
  }

  void _showThemeModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close)),
                  Text("Appearance", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: themes.length,
                itemBuilder: (ctx, i) {
                  final t = themes[i];
                  final isActive = t.id == ref.read(currentThemeProvider).id;
                  return GestureDetector(
                    onTap: () {
                      ref.read(currentThemeProvider.notifier).state = t;
                      Navigator.pop(context); // Optional: close on select or stay open
                    },
                    child: Container(
                      width: 180, margin: EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: isActive ? Border.all(color: t.primary[500]!, width: 4) : Border.all(color: Colors.transparent, width: 4),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0,5))]
                      ),
                      child: Stack(
                        children: [
                          Column(children: [
                            Container(height: 60, color: t.primary[50]),
                            Expanded(child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(children: [
                                Container(height: 60, decoration: BoxDecoration(color: t.primary[50], borderRadius: BorderRadius.circular(12))),
                                SizedBox(height: 8),
                                Row(children: [Expanded(child: Container(height: 40, color: t.primary[50]))]),
                              ]),
                            ))
                          ]),
                          if (isActive) Positioned(top: 12, right: 12, child: CircleAvatar(radius: 12, backgroundColor: t.primary[500], child: Icon(Icons.check, size: 14, color: Colors.white))),
                          Positioned(bottom: 0, left: 0, right: 0, child: Container(padding: EdgeInsets.all(12), child: Text(t.name, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))))
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showStorageModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Storage Location", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            _StorageOption(
              icon: Icons.smartphone,
              title: "Internal Storage",
              sub: "/storage/emulated/0/SageTools",
              isSelected: ref.read(storagePathProvider).contains("emulated"),
              onTap: () {
                ref.read(storagePathProvider.notifier).state = "/storage/emulated/0/SageTools";
                Navigator.pop(context);
              }
            ),
            SizedBox(height: 12),
            _StorageOption(
              icon: Icons.sd_card,
              title: "SD Card",
              sub: "/storage/extSdCard/SageTools",
              isSelected: ref.read(storagePathProvider).contains("extSdCard"),
              onTap: () {
                 ref.read(storagePathProvider.notifier).state = "/storage/extSdCard/SageTools";
                 Navigator.pop(context);
              }
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  String? path = await FilePicker.platform.getDirectoryPath();
                  if (path != null) {
                    ref.read(storagePathProvider.notifier).state = path;
                    Navigator.pop(context);
                  }
                },
                child: Text("Add Custom Path"),
              ),
            )
          ],
        ),
      ),
    );
  }
}

Widget _SettingTile({required IconData icon, required MaterialColor color, required String title, required String value, required VoidCallback onTap}) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: color[100], borderRadius: BorderRadius.circular(20)), child: Icon(icon, size: 16, color: color[600])),
          SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          Spacer(),
          Text(value, style: TextStyle(fontSize: 12, color: color[600], fontWeight: FontWeight.w500)),
          SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 14, color: Colors.grey[300]),
        ],
      ),
    ),
  );
}

Widget _StorageOption({required IconData icon, required String title, required String sub, required bool isSelected, required VoidCallback onTap}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green[50] : Colors.white,
        border: Border.all(color: isSelected ? Colors.green[200]! : Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: isSelected ? Colors.green[700] : Colors.grey[500]),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[800])),
            Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
          ])),
          if (isSelected) Icon(Icons.check_circle, color: Colors.green[600], size: 20),
        ],
      ),
    ),
  );
}
