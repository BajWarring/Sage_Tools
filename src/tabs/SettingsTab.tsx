import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native';
import MD3Icon from '../components/MD3Icon';

// Matches the Theme interface used in App.tsx
interface Theme {
  primary: string;
  background: string;
  surface: string;
  onSurface: string;
  outline: string;
}

interface SettingsTabProps {
  theme: Theme;
  currentThemeId: string;
  onChangeTheme: (id: string) => void;
}

const SettingsTab: React.FC<SettingsTabProps> = ({ theme, currentThemeId, onChangeTheme }) => {
  
  const themesList = [
    { id: 'sakura', name: 'Sakura Pink', color: '#FFB7C5' },
    { id: 'mint', name: 'Fresh Mint', color: '#98FF98' },
    { id: 'ocean', name: 'Ocean Blue', color: '#0077BE' },
  ];

  return (
    <ScrollView style={[styles.container, { backgroundColor: theme.background }]}>
      <View style={styles.header}>
        <Text style={[styles.title, { color: theme.onSurface }]}>Settings</Text>
      </View>

      <Text style={[styles.sectionTitle, { color: theme.onSurface }]}>Appearance</Text>
      <View style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.outline }]}>
        {themesList.map((t) => (
          <TouchableOpacity 
            key={t.id}
            style={styles.themeRow}
            onPress={() => onChangeTheme(t.id)}
          >
            <View style={{ flexDirection: 'row', alignItems: 'center' }}>
              <View style={[styles.colorPreview, { backgroundColor: t.color }]} />
              <Text style={[styles.themeName, { color: theme.onSurface }]}>{t.name}</Text>
            </View>
            {currentThemeId === t.id && (
              <MD3Icon name="check" size={20} color={theme.primary} />
            )}
          </TouchableOpacity>
        ))}
      </View>

      <Text style={[styles.sectionTitle, { color: theme.onSurface }]}>About</Text>
      <View style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.outline }]}>
        <Text style={{ color: theme.onSurface, padding: 16 }}>Version 1.0.0</Text>
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, padding: 20 },
  header: { marginBottom: 30 },
  title: { fontSize: 32, fontWeight: 'bold' },
  sectionTitle: { fontSize: 18, fontWeight: '600', marginBottom: 12, marginTop: 10 },
  card: { borderRadius: 12, borderWidth: 1, overflow: 'hidden', marginBottom: 20 },
  themeRow: { 
    flexDirection: 'row', 
    justifyContent: 'space-between', 
    alignItems: 'center', 
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#eee' 
  },
  colorPreview: { width: 24, height: 24, borderRadius: 12, marginRight: 12 },
  themeName: { fontSize: 16 },
});

export default SettingsTab;
