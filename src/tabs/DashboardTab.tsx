import React from 'react';
import { ScrollView, View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { MD3Icon } from '../components/MD3Icon';
import { TOOLS, FILES } from '../data/appData';

export const DashboardTab = ({ theme: C, onToolPress }: any) => (
  <ScrollView contentContainerStyle={{ paddingBottom: 100, paddingTop: 8 }} showsVerticalScrollIndicator={false}>
    {/* Resume Section */}
    <View style={styles.sectionBox}>
      <Text style={[styles.title, { color: C.onSurfaceVariant }]}>Continue Editing</Text>
    </View>
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 16, paddingBottom: 12 }}>
      {FILES.slice(0, 3).map((f: any, i: number) => (
        <TouchableOpacity key={i} activeOpacity={0.7} style={[styles.resumeCard, { backgroundColor: C.surfaceContainer }]}>
          <View style={styles.rowBetween}>
            <MD3Icon symbol="⏱️" size={18} color={C.primary} />
            <Text style={[styles.tag, { color: C.onSurfaceVariant }]}>RESUME</Text>
          </View>
          <View>
            <Text numberOfLines={1} style={[styles.name, { color: C.onSurface }]}>{f.name}</Text>
            <Text style={[styles.meta, { color: C.onSurfaceVariant }]}>Edited {f.date}</Text>
          </View>
        </TouchableOpacity>
      ))}
    </ScrollView>

    {/* Tools Grid */}
    <View style={styles.sectionBox}>
      <Text style={[styles.title, { color: C.onSurfaceVariant }]}>Tools</Text>
    </View>
    <View style={styles.grid}>
      {TOOLS.map((tool: any) => (
        <TouchableOpacity key={tool.id} onPress={() => onToolPress(tool)} style={[styles.toolCard, { backgroundColor: C.surfaceContainerHigh }]}>
          <View style={styles.rowTop}>
            <View style={[styles.iconBox, { backgroundColor: C.primaryContainer }]}>
              <MD3Icon symbol={tool.icon} size={22} color={C.onPrimaryContainer} />
            </View>
            <View style={[styles.badge, { backgroundColor: C.surfaceContainer }]}>
              <Text style={[styles.count, { color: C.onSurfaceVariant }]}>{tool.count}</Text>
            </View>
          </View>
          <View>
            <Text style={[styles.toolTitle, { color: C.onSurface }]}>{tool.title}</Text>
            <Text style={[styles.meta, { color: C.onSurfaceVariant }]}>Tap to open</Text>
          </View>
        </TouchableOpacity>
      ))}
    </View>

    {/* Files List */}
    <View style={[styles.sectionBox, styles.rowBetween, { paddingRight: 16 }]}>
      <Text style={[styles.title, { color: C.onSurfaceVariant }]}>Saved Files</Text>
      <Text style={{ color: C.primary, fontWeight: '600' }}>View All</Text>
    </View>
    <View style={{ paddingHorizontal: 16 }}>
      {FILES.map((f: any, i: number) => (
        <TouchableOpacity key={i} style={[styles.fileRow, { backgroundColor: C.surfaceContainer }]}>
          <View style={[styles.fileIcon, { backgroundColor: C.secondaryContainer }]}>
            <MD3Icon symbol={f.icon} size={20} color={C.onSecondaryContainer} />
          </View>
          <View style={{ flex: 1, marginLeft: 16 }}>
            <Text style={[styles.name, { color: C.onSurface }]}>{f.name}</Text>
            <Text style={[styles.meta, { color: C.onSurfaceVariant }]}>{f.size} • {f.date}</Text>
          </View>
          <MD3Icon symbol="⋮" color={C.onSurfaceVariant} />
        </TouchableOpacity>
      ))}
    </View>
  </ScrollView>
);

const styles = StyleSheet.create({
  sectionBox: { paddingHorizontal: 20, marginBottom: 12, marginTop: 24 },
  title: { fontSize: 14, fontWeight: '500' },
  resumeCard: { width: 150, height: 85, marginRight: 12, borderRadius: 16, padding: 12, justifyContent: 'space-between' },
  rowBetween: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  rowTop: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  tag: { fontSize: 10, fontWeight: 'bold' },
  name: { fontSize: 13, fontWeight: '500' },
  meta: { fontSize: 11 },
  grid: { flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: 16, gap: 12 },
  toolCard: { width: '48%', height: 140, borderRadius: 24, padding: 16, justifyContent: 'space-between' },
  iconBox: { width: 48, height: 48, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
  badge: { paddingHorizontal: 8, paddingVertical: 4, borderRadius: 8 },
  count: { fontSize: 12, fontWeight: 'bold' },
  toolTitle: { fontSize: 16, fontWeight: '500', marginBottom: 2 },
  fileRow: { flexDirection: 'row', alignItems: 'center', padding: 12, borderRadius: 16, marginBottom: 8 },
  fileIcon: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
});
