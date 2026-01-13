import React from 'react';
import { ScrollView, View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { MD3Icon } from '../components/MD3Icon';

export const SettingsTab = ({ theme: C, themeName, onThemePress, storagePath, onStoragePress }: any) => (
  <ScrollView contentContainerStyle={{ paddingBottom: 100, paddingTop: 8 }} showsVerticalScrollIndicator={false}>
    <View style={[styles.group, { backgroundColor: C.surfaceContainerHigh }]}>
      <TouchableOpacity onPress={onThemePress} style={[styles.row, { borderBottomWidth: 1, borderBottomColor: C.outlineVariant }]}>
        <MD3Icon symbol="🎨" size={24} color={C.primary} />
        <View style={styles.textCtx}>
          <Text style={[styles.head, { color: C.onSurface }]}>Theme</Text>
          <Text style={[styles.sub, { color: C.onSurfaceVariant }]}>{themeName}</Text>
        </View>
        <MD3Icon symbol="›" color={C.onSurfaceVariant} />
      </TouchableOpacity>
      <TouchableOpacity style={styles.row}>
        <MD3Icon symbol="🌐" size={24} color={C.onSurfaceVariant} />
        <View style={styles.textCtx}>
          <Text style={[styles.head, { color: C.onSurface }]}>Language</Text>
          <Text style={[styles.sub, { color: C.onSurfaceVariant }]}>English (US)</Text>
        </View>
      </TouchableOpacity>
    </View>

    <Text style={[styles.header, { color: C.primary }]}>Data & Storage</Text>
    <View style={[styles.group, { backgroundColor: C.surfaceContainerHigh }]}>
      <TouchableOpacity onPress={onStoragePress} style={styles.row}>
        <MD3Icon symbol="📁" size={24} color={C.onSurfaceVariant} />
        <View style={styles.textCtx}>
          <Text style={[styles.head, { color: C.onSurface }]}>Storage Location</Text>
          <Text style={[styles.sub, { color: C.onSurfaceVariant }]}>{storagePath}</Text>
        </View>
      </TouchableOpacity>
      <TouchableOpacity style={styles.row}>
        <MD3Icon symbol="🗑️" size={24} color={C.onSurfaceVariant} />
        <View style={styles.textCtx}>
          <Text style={[styles.head, { color: C.onSurface }]}>Clear Cache</Text>
          <Text style={[styles.sub, { color: C.onSurfaceVariant }]}>14 MB</Text>
        </View>
      </TouchableOpacity>
    </View>

    <Text style={[styles.header, { color: C.primary }]}>About</Text>
    <View style={[styles.group, { backgroundColor: C.surfaceContainerHigh }]}>
      <TouchableOpacity style={styles.row}>
        <MD3Icon symbol="ℹ️" size={24} color={C.onSurfaceVariant} />
        <View style={styles.textCtx}>
          <Text style={[styles.head, { color: C.onSurface }]}>Version</Text>
          <Text style={[styles.sub, { color: C.onSurfaceVariant }]}>7.1.0 (Native)</Text>
        </View>
      </TouchableOpacity>
    </View>
  </ScrollView>
);

const styles = StyleSheet.create({
  group: { marginHorizontal: 16, borderRadius: 24, overflow: 'hidden', marginBottom: 16 },
  row: { flexDirection: 'row', alignItems: 'center', padding: 16 },
  textCtx: { flex: 1, marginLeft: 16 },
  head: { fontSize: 16, marginBottom: 2 },
  sub: { fontSize: 14 },
  header: { fontSize: 14, fontWeight: '500', marginLeft: 32, marginBottom: 8, marginTop: 8 },
});
