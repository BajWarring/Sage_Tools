import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Image } from 'react-native';
import MD3Icon from '../components/MD3Icon';

const DashboardTab = ({ theme, onOpenTools }: any) => {
  
  // Data matching your HTML
  const tools = [
    { id: 'pdf', title: 'PDF Tools', icon: 'file-pdf-box', count: 6 },
    { id: 'img', title: 'Image Editor', icon: 'camera', count: 5 },
    { id: 'vid', title: 'Video Studio', icon: 'video', count: 4 },
    { id: 'util', title: 'Utilities', icon: 'wrench', count: 8 }
  ];

  const files = [
    { name: 'Invoice_2026.pdf', date: '2h ago', size: '1.2MB', icon: 'file-document' },
    { name: 'Trip_Vlog.mp4', date: 'Yesterday', size: '142MB', icon: 'video' },
    { name: 'Avatar.png', date: 'Oct 24', size: '2.8MB', icon: 'image' },
    { name: 'Notes.txt', date: 'Oct 22', size: '12KB', icon: 'file-document-outline' }
  ];

  return (
    <ScrollView 
      style={[styles.container, { backgroundColor: theme.surface }]}
      contentContainerStyle={{ paddingBottom: 100 }}
      showsVerticalScrollIndicator={false}
    >
      {/* Header (replicates the <header> tag) */}
      <View style={styles.header}>
        <Text style={[styles.appName, { color: theme.onSurface }]}>Sage Tools</Text>
        <TouchableOpacity style={styles.profileBtn}>
           <MD3Icon name="account" size={28} color={theme.onSurfaceVariant} />
        </TouchableOpacity>
      </View>

      {/* 1. Continue Editing (Horizontal Scroll) */}
      <View style={styles.section}>
        <Text style={[styles.sectionTitle, { color: theme.onSurfaceVariant }]}>Continue Editing</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginLeft: -16 }}>
          <View style={{ width: 16 }} /> 
          {files.slice(0, 3).map((f, i) => (
            <TouchableOpacity 
              key={i} 
              style={[styles.jumpCard, { backgroundColor: theme.surfaceContainer }]}
            >
              <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
                <MD3Icon name="history" size={20} color={theme.primary} />
                <Text style={{ fontSize: 10, fontWeight: 'bold', color: theme.onSurfaceVariant }}>RESUME</Text>
              </View>
              <View>
                <Text numberOfLines={1} style={[styles.fileNameSmall, { color: theme.onSurface }]}>{f.name}</Text>
                <Text style={{ fontSize: 10, color: theme.onSurfaceVariant }}>Edited {f.date}</Text>
              </View>
            </TouchableOpacity>
          ))}
        </ScrollView>
      </View>

      {/* 2. Tools Grid */}
      <View style={styles.section}>
        <Text style={[styles.sectionTitle, { color: theme.onSurfaceVariant }]}>Tools</Text>
        <View style={styles.grid}>
          {tools.map((t) => (
            <TouchableOpacity 
              key={t.id}
              onPress={() => onOpenTools(t.id)} 
              style={[styles.toolCard, { backgroundColor: theme.surfaceContainerHigh }]}
            >
              <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <View style={[styles.iconBox, { backgroundColor: theme.primaryContainer }]}>
                  <MD3Icon name={t.icon} size={24} color={theme.onPrimaryContainer} />
                </View>
                <View style={[styles.badge, { backgroundColor: theme.surfaceContainer }]}>
                  <Text style={{ fontSize: 12, fontWeight: 'bold', color: theme.onSurfaceVariant }}>{t.count}</Text>
                </View>
              </View>
              <View>
                <Text style={[styles.toolTitle, { color: theme.onSurface }]}>{t.title}</Text>
                <Text style={{ fontSize: 11, color: theme.onSurfaceVariant }}>Tap to open</Text>
              </View>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* 3. Saved Files List */}
      <View style={styles.section}>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
          <Text style={[styles.sectionTitle, { marginBottom: 0, color: theme.onSurfaceVariant }]}>Saved Files</Text>
          <Text style={{ fontSize: 14, fontWeight: '600', color: theme.primary }}>View All</Text>
        </View>
        
        {files.map((f, i) => (
          <TouchableOpacity key={i} style={[styles.fileRow, { backgroundColor: theme.surfaceContainer }]}>
            <View style={[styles.fileIconCircle, { backgroundColor: theme.secondaryContainer }]}>
               <MD3Icon name={f.icon} size={22} color={theme.onSecondaryContainer} />
            </View>
            <View style={{ flex: 1, paddingHorizontal: 12 }}>
              <Text style={{ fontSize: 14, fontWeight: '500', color: theme.onSurface }}>{f.name}</Text>
              <Text style={{ fontSize: 12, color: theme.onSurfaceVariant }}>{f.size} • {f.date}</Text>
            </View>
            <MD3Icon name="dots-vertical" size={20} color={theme.onSurfaceVariant} />
          </TouchableOpacity>
        ))}
      </View>

    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, paddingHorizontal: 16 },
  header: { height: 60, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginTop: 10 },
  appName: { fontSize: 22, fontWeight: '400' },
  profileBtn: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
  
  section: { marginBottom: 24 },
  sectionTitle: { fontSize: 14, fontWeight: '500', marginBottom: 12, marginLeft: 4 },
  
  // Jump Back In
  jumpCard: { width: 140, height: 90, padding: 12, borderRadius: 16, marginRight: 8, justifyContent: 'space-between' },
  fileNameSmall: { fontSize: 12, fontWeight: '500', marginBottom: 2 },
  
  // Grid
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: 12 },
  toolCard: { width: '48%', height: 140, padding: 16, borderRadius: 24, justifyContent: 'space-between' },
  iconBox: { width: 48, height: 48, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
  badge: { paddingHorizontal: 8, paddingVertical: 4, borderRadius: 8 },
  toolTitle: { fontSize: 16, fontWeight: '500', marginBottom: 2 },
  
  // File List
  fileRow: { flexDirection: 'row', alignItems: 'center', padding: 12, borderRadius: 16, marginBottom: 8 },
  fileIconCircle: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' }
});

export default DashboardTab;
