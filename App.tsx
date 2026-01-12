import React, { useState, useEffect } from 'react';
import {
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  Dimensions,
  Modal,
  Animated,
} from 'react-native';

// --- 1. THEME DEFINITIONS (Exact match from HTML) ---
const THEMES = {
  sakura: {
    primary: '#984061', onPrimary: '#ffffff', primaryContainer: '#ffd9e2', onPrimaryContainer: '#3e001d',
    secondary: '#74565f', secondaryContainer: '#ffd9e2', onSecondaryContainer: '#2b151c',
    surface: '#fff8f8', surfaceContainer: '#fceaea', surfaceContainerHigh: '#fff0f3',
    onSurface: '#201a1b', onSurfaceVariant: '#514347', outline: '#837377', outlineVariant: '#d5c2c6',
  },
  lavender: {
    primary: '#6750a4', onPrimary: '#ffffff', primaryContainer: '#eaddff', onPrimaryContainer: '#21005d',
    secondary: '#625b71', secondaryContainer: '#e8def8', onSecondaryContainer: '#1d192b',
    surface: '#fff7fe', surfaceContainer: '#f3eefc', surfaceContainerHigh: '#f7f2fa',
    onSurface: '#1c1b1f', onSurfaceVariant: '#49454f', outline: '#79747e', outlineVariant: '#cac4d0',
  },
  mint: {
    primary: '#006c4c', onPrimary: '#ffffff', primaryContainer: '#89f8c7', onPrimaryContainer: '#002114',
    secondary: '#4c6358', secondaryContainer: '#cee9da', onSecondaryContainer: '#092016',
    surface: '#fbfdf9', surfaceContainer: '#edf5ef', surfaceContainerHigh: '#e7f0eb',
    onSurface: '#191c1a', onSurfaceVariant: '#404944', outline: '#707974', outlineVariant: '#bfc9c2',
  },
  ocean: {
    primary: '#006492', onPrimary: '#ffffff', primaryContainer: '#cae6ff', onPrimaryContainer: '#001e30',
    secondary: '#50606e', secondaryContainer: '#d3e4f5', onSecondaryContainer: '#0c1d29',
    surface: '#f8fdff', surfaceContainer: '#eaf2f8', surfaceContainerHigh: '#e4eff5',
    onSurface: '#191c1e', onSurfaceVariant: '#42474e', outline: '#72777f', outlineVariant: '#c2c7cf',
  },
};

// --- 2. DATA (Exact match from HTML) ---
const TOOLS = [
  { id: 'pdf', title: 'PDF Tools', icon: '📄', count: 6, items: ['Merge', 'Split', 'Sign', 'Compress', 'OCR'] },
  { id: 'img', title: 'Image Editor', icon: '📸', count: 5, items: ['Resize', 'Crop', 'Filter', 'Convert', 'Markup'] },
  { id: 'vid', title: 'Video Studio', icon: '🎬', count: 4, items: ['Trim', 'Audio', 'Speed', 'Mute'] },
  { id: 'util', title: 'Utilities', icon: '🛠️', count: 8, items: ['QR Gen', 'Scanner', 'Units', 'Time', 'Text'] }
];

const FILES = [
  { name: 'Invoice_2026.pdf', date: '2h ago', size: '1.2MB', icon: '📄' },
  { name: 'Trip_Vlog.mp4', date: 'Yesterday', size: '142MB', icon: '🎥' },
  { name: 'Avatar.png', date: 'Oct 24', size: '2.8MB', icon: '🖼️' },
  { name: 'Notes.txt', date: 'Oct 22', size: '12KB', icon: '📝' }
];

// --- 3. COMPONENTS ---

// Generic Icon Placeholder (Since we don't have vector icons linked)
const Icon = ({ name, color, size = 24 }: { name: string, color: string, size?: number }) => (
  <Text style={{ fontSize: size, color: color, fontFamily: 'sans-serif' }}>
    {/* Mapping material names to approximate emojis/symbols for robustness */}
    {name === 'grid_view' ? '🗂️' : 
     name === 'settings' ? '⚙️' : 
     name === 'account_circle' ? '👤' : 
     name === 'history' ? '⏱️' : 
     name === 'more_vert' ? '⋮' : 
     name === 'palette' ? '🎨' :
     name === 'folder' ? '📁' :
     name === 'delete' ? '🗑️' :
     name === 'info' ? 'ℹ️' :
     name === 'check_circle' ? '✅' :
     name === 'arrow_back' ? '⬅️' : 
     name === 'chevron_right' ? '›' : '•'}
  </Text>
);

function App(): React.JSX.Element {
  const [activeTheme, setActiveTheme] = useState<keyof typeof THEMES>('sakura');
  const [activeTab, setActiveTab] = useState('dashboard'); // 'dashboard' | 'settings'
  const [modalVisible, setModalVisible] = useState(false);
  const [activeTool, setActiveTool] = useState<any>(null);
  const [themeModalVisible, setThemeModalVisible] = useState(false);
  
  const C = THEMES[activeTheme]; // Current Colors

  // Animations
  const [fadeAnim] = useState(new Animated.Value(0));

  useEffect(() => {
    Animated.timing(fadeAnim, {
      toValue: 1,
      duration: 300,
      useNativeDriver: true,
    }).start();
  }, [activeTab]);

  const openTool = (tool: any) => {
    setActiveTool(tool);
    setModalVisible(true);
  };

  // --- RENDER DASHBOARD ---
  const renderDashboard = () => (
    <Animated.View style={{ opacity: fadeAnim, paddingBottom: 100 }}>
      {/* Resume Section */}
      <Text style={[styles.sectionTitle, { color: C.onSurfaceVariant }]}>Continue Editing</Text>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.horizontalScroll}>
        {FILES.slice(0, 3).map((f, i) => (
          <TouchableOpacity key={i} style={[styles.resumeCard, { backgroundColor: C.surfaceContainer }]}>
            <View style={styles.resumeHeader}>
              <Icon name="history" color={C.primary} size={18} />
              <Text style={[styles.resumeTag, { color: C.onSurfaceVariant }]}>RESUME</Text>
            </View>
            <View>
              <Text numberOfLines={1} style={[styles.resumeName, { color: C.onSurface }]}>{f.name}</Text>
              <Text style={[styles.resumeTime, { color: C.onSurfaceVariant }]}>Edited {f.date}</Text>
            </View>
          </TouchableOpacity>
        ))}
      </ScrollView>

      {/* Tools Grid */}
      <Text style={[styles.sectionTitle, { color: C.onSurfaceVariant }]}>Tools</Text>
      <View style={styles.gridContainer}>
        {TOOLS.map((t) => (
          <TouchableOpacity 
            key={t.id} 
            onPress={() => openTool(t)}
            style={[styles.toolCard, { backgroundColor: C.surfaceContainerHigh }]}
          >
            <View style={styles.toolHeader}>
              <View style={[styles.toolIconBox, { backgroundColor: C.primaryContainer }]}>
                <Text style={{ fontSize: 22 }}>{t.icon}</Text>
              </View>
              <View style={[styles.toolCountBadge, { backgroundColor: C.surfaceContainer }]}>
                <Text style={[styles.toolCountText, { color: C.onSurfaceVariant }]}>{t.count}</Text>
              </View>
            </View>
            <View>
              <Text style={[styles.toolTitle, { color: C.onSurface }]}>{t.title}</Text>
              <Text style={[styles.toolSub, { color: C.onSurfaceVariant }]}>Tap to open</Text>
            </View>
          </TouchableOpacity>
        ))}
      </View>

      {/* Files List */}
      <View style={styles.fileHeader}>
        <Text style={[styles.sectionTitle, { marginBottom: 0, color: C.onSurfaceVariant }]}>Saved Files</Text>
        <TouchableOpacity><Text style={[styles.viewAllBtn, { color: C.primary }]}>View All</Text></TouchableOpacity>
      </View>
      <View style={styles.fileList}>
        {FILES.map((f, i) => (
          <TouchableOpacity key={i} style={[styles.fileRow, { backgroundColor: C.surfaceContainer }]}>
            <View style={[styles.fileIcon, { backgroundColor: C.secondaryContainer }]}>
              <Text style={{ fontSize: 20 }}>{f.icon}</Text>
            </View>
            <View style={styles.fileInfo}>
              <Text style={[styles.fileName, { color: C.onSurface }]}>{f.name}</Text>
              <Text style={[styles.fileMeta, { color: C.onSurfaceVariant }]}>{f.size} • {f.date}</Text>
            </View>
            <Icon name="more_vert" color={C.onSurfaceVariant} />
          </TouchableOpacity>
        ))}
      </View>
    </Animated.View>
  );

  // --- RENDER SETTINGS ---
  const renderSettings = () => (
    <Animated.View style={{ opacity: fadeAnim, paddingBottom: 100 }}>
      {/* Appearance Section */}
      <View style={[styles.settingsCard, { backgroundColor: C.surfaceContainerHigh }]}>
        <TouchableOpacity 
          onPress={() => setThemeModalVisible(true)}
          style={[styles.settingRow, { borderBottomWidth: 1, borderBottomColor: C.outlineVariant }]}
        >
          <Icon name="palette" color={C.primary} size={28} />
          <View style={styles.settingText}>
            <Text style={[styles.settingTitle, { color: C.onSurface }]}>Theme</Text>
            <Text style={[styles.settingSub, { color: C.onSurfaceVariant }]}>{activeTheme.charAt(0).toUpperCase() + activeTheme.slice(1)}</Text>
          </View>
          <Icon name="chevron_right" color={C.onSurfaceVariant} />
        </TouchableOpacity>
        <TouchableOpacity style={styles.settingRow}>
          <Text style={{ fontSize: 24 }}>🌐</Text>
          <View style={styles.settingText}>
            <Text style={[styles.settingTitle, { color: C.onSurface }]}>Language</Text>
            <Text style={[styles.settingSub, { color: C.onSurfaceVariant }]}>English (US)</Text>
          </View>
        </TouchableOpacity>
      </View>

      <Text style={[styles.sectionHeader, { color: C.primary }]}>Data & Storage</Text>
      <View style={[styles.settingsCard, { backgroundColor: C.surfaceContainerHigh }]}>
        <TouchableOpacity style={styles.settingRow}>
          <Icon name="folder" color={C.onSurfaceVariant} size={28} />
          <View style={styles.settingText}>
            <Text style={[styles.settingTitle, { color: C.onSurface }]}>Storage Location</Text>
            <Text style={[styles.settingSub, { color: C.onSurfaceVariant }]}>/Internal/SageTools</Text>
          </View>
        </TouchableOpacity>
        <TouchableOpacity style={styles.settingRow}>
          <Icon name="delete" color={C.onSurfaceVariant} size={28} />
          <View style={styles.settingText}>
            <Text style={[styles.settingTitle, { color: C.onSurface }]}>Clear Cache</Text>
            <Text style={[styles.settingSub, { color: C.onSurfaceVariant }]}>14 MB</Text>
          </View>
        </TouchableOpacity>
      </View>

      <Text style={[styles.sectionHeader, { color: C.primary }]}>About</Text>
      <View style={[styles.settingsCard, { backgroundColor: C.surfaceContainerHigh }]}>
        <TouchableOpacity style={styles.settingRow}>
          <Icon name="info" color={C.onSurfaceVariant} size={28} />
          <View style={styles.settingText}>
            <Text style={[styles.settingTitle, { color: C.onSurface }]}>Version</Text>
            <Text style={[styles.settingSub, { color: C.onSurfaceVariant }]}>7.1.0 (Material You)</Text>
          </View>
        </TouchableOpacity>
      </View>
    </Animated.View>
  );

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: C.surface }]}>
      <StatusBar backgroundColor={C.surface} barStyle="dark-content" />

      {/* TOP BAR */}
      <View style={[styles.header, { backgroundColor: C.surface }]}>
        <Text style={[styles.headerTitle, { color: C.onSurface }]}>Sage Tools</Text>
        <TouchableOpacity style={styles.profileBtn}>
          <Icon name="account_circle" color={C.onSurfaceVariant} size={32} />
        </TouchableOpacity>
      </View>

      {/* MAIN CONTENT */}
      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        {activeTab === 'dashboard' ? renderDashboard() : renderSettings()}
      </ScrollView>

      {/* BOTTOM NAV */}
      <View style={[styles.navBar, { backgroundColor: C.surfaceContainer, borderColor: C.outlineVariant + '33' }]}>
        <TouchableOpacity 
          onPress={() => setActiveTab('dashboard')} 
          style={styles.navItem}
        >
          <View style={[styles.navPill, activeTab === 'dashboard' && { backgroundColor: C.secondaryContainer }]}>
            <Icon name="grid_view" color={activeTab === 'dashboard' ? C.onSecondaryContainer : C.onSurfaceVariant} />
          </View>
          <Text style={[styles.navLabel, { color: C.onSurfaceVariant }, activeTab === 'dashboard' && { color: C.onSurface, opacity: 1 }]}>Dashboard</Text>
        </TouchableOpacity>

        <TouchableOpacity 
          onPress={() => setActiveTab('settings')} 
          style={styles.navItem}
        >
          <View style={[styles.navPill, activeTab === 'settings' && { backgroundColor: C.secondaryContainer }]}>
            <Icon name="settings" color={activeTab === 'settings' ? C.onSecondaryContainer : C.onSurfaceVariant} />
          </View>
          <Text style={[styles.navLabel, { color: C.onSurfaceVariant }, activeTab === 'settings' && { color: C.onSurface, opacity: 1 }]}>Settings</Text>
        </TouchableOpacity>
      </View>

      {/* TOOL MODAL (SHEET) */}
      <Modal visible={modalVisible} transparent animationType="slide" onRequestClose={() => setModalVisible(false)}>
        <View style={styles.modalOverlay}>
          <View style={[styles.modalSheet, { backgroundColor: C.surfaceContainer }]}>
            <View style={styles.dragHandle} />
            {activeTool && (
              <>
                <View style={styles.modalHeader}>
                  <View style={[styles.modalIconBox, { backgroundColor: C.primaryContainer }]}>
                    <Text style={{ fontSize: 32 }}>{activeTool.icon}</Text>
                  </View>
                  <Text style={[styles.modalTitle, { color: C.onSurface }]}>{activeTool.title}</Text>
                </View>
                <View style={styles.modalGrid}>
                  {activeTool.items.map((item: string, i: number) => (
                    <TouchableOpacity key={i} style={[styles.modalItem, { backgroundColor: C.surfaceContainerHigh }]}>
                      <Text style={{ fontSize: 24, marginBottom: 8 }}>🧩</Text>
                      <Text style={[styles.modalItemText, { color: C.onSurface }]}>{item}</Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </>
            )}
            <TouchableOpacity onPress={() => setModalVisible(false)} style={[styles.closeBtn, { backgroundColor: C.primary }]}>
              <Text style={{ color: C.onPrimary, fontWeight: 'bold' }}>Close</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      {/* THEME SELECTOR MODAL */}
      <Modal visible={themeModalVisible} animationType="slide" onRequestClose={() => setThemeModalVisible(false)}>
        <View style={[styles.themePage, { backgroundColor: C.surface }]}>
          <View style={[styles.header, { borderBottomWidth: 1, borderColor: C.outlineVariant }]}>
            <TouchableOpacity onPress={() => setThemeModalVisible(false)}>
              <Icon name="arrow_back" color={C.onSurface} size={28} />
            </TouchableOpacity>
            <Text style={[styles.headerTitle, { marginLeft: 16, color: C.onSurface }]}>Appearance</Text>
          </View>
          <ScrollView contentContainerStyle={{ padding: 20 }}>
            <Text style={[styles.sectionTitle, { color: C.onSurfaceVariant }]}>Select Theme</Text>
            <View style={styles.themeGrid}>
              {Object.keys(THEMES).map((key) => {
                const t = THEMES[key as keyof typeof THEMES];
                const isActive = activeTheme === key;
                return (
                  <TouchableOpacity 
                    key={key} 
                    onPress={() => setActiveTheme(key as any)}
                    style={[styles.themeCard, { borderColor: isActive ? t.primary : 'transparent', backgroundColor: t.surfaceContainerHigh }]}
                  >
                    <View style={{ height: 40, backgroundColor: t.primaryContainer, width: '100%' }} />
                    <View style={{ padding: 10 }}>
                      <View style={{ height: 10, width: 40, backgroundColor: t.secondary, borderRadius: 5, marginBottom: 5 }} />
                      <View style={{ height: 10, width: 20, backgroundColor: t.tertiary || t.outline, borderRadius: 5 }} />
                    </View>
                    <Text style={[styles.themeName, { color: t.onSurface }]}>{key.toUpperCase()}</Text>
                    {isActive && <View style={[styles.checkBadge, { backgroundColor: t.primary }]}><Icon name="check_circle" color={t.onPrimary} size={16} /></View>}
                  </TouchableOpacity>
                );
              })}
            </View>
          </ScrollView>
        </View>
      </Modal>

    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: { height: 70, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 20, justifyContent: 'space-between' },
  headerTitle: { fontSize: 22, fontWeight: '400' },
  profileBtn: { width: 40, height: 40, alignItems: 'center', justifyContent: 'center' },
  content: { flex: 1, paddingHorizontal: 16, paddingTop: 10 },
  
  // Sections
  sectionTitle: { fontSize: 14, fontWeight: '500', marginBottom: 12, marginLeft: 4 },
  sectionHeader: { fontSize: 14, fontWeight: '500', marginBottom: 8, marginTop: 16, marginLeft: 16 },
  
  // Horizontal Scroll (Resume)
  horizontalScroll: { marginBottom: 24, flexDirection: 'row' },
  resumeCard: { width: 140, padding: 12, borderRadius: 16, marginRight: 12, height: 80, justifyContent: 'space-between' },
  resumeHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  resumeTag: { fontSize: 10, fontWeight: 'bold' },
  resumeName: { fontSize: 12, fontWeight: '500' },
  resumeTime: { fontSize: 10 },

  // Grid
  gridContainer: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', marginBottom: 24 },
  toolCard: { width: '48%', borderRadius: 24, padding: 16, marginBottom: 12, height: 140, justifyContent: 'space-between' },
  toolHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  toolIconBox: { width: 48, height: 48, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
  toolCountBadge: { paddingHorizontal: 8, paddingVertical: 4, borderRadius: 8 },
  toolCountText: { fontSize: 12, fontWeight: 'bold' },
  toolTitle: { fontSize: 16, fontWeight: '500', marginBottom: 4 },
  toolSub: { fontSize: 12 },

  // File List
  fileHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12, paddingHorizontal: 4 },
  viewAllBtn: { fontSize: 14, fontWeight: '500' },
  fileList: { marginBottom: 20 },
  fileRow: { flexDirection: 'row', alignItems: 'center', padding: 12, borderRadius: 16, marginBottom: 8 },
  fileIcon: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center', marginRight: 16 },
  fileInfo: { flex: 1 },
  fileName: { fontSize: 14, fontWeight: '500' },
  fileMeta: { fontSize: 12 },

  // Nav Bar
  navBar: { height: 80, flexDirection: 'row', justifyContent: 'space-around', alignItems: 'center', borderTopWidth: 1, paddingBottom: 10 },
  navItem: { alignItems: 'center', width: 80 },
  navPill: { width: 64, height: 32, borderRadius: 16, alignItems: 'center', justifyContent: 'center', marginBottom: 4 },
  navLabel: { fontSize: 12, fontWeight: '600', opacity: 0 },

  // Modal
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
  modalSheet: { borderTopLeftRadius: 28, borderTopRightRadius: 28, padding: 24, minHeight: '50%' },
  dragHandle: { width: 32, height: 4, backgroundColor: '#ccc', borderRadius: 2, alignSelf: 'center', marginBottom: 20, opacity: 0.5 },
  modalHeader: { alignItems: 'center', marginBottom: 24 },
  modalIconBox: { width: 64, height: 64, borderRadius: 20, alignItems: 'center', justifyContent: 'center', marginBottom: 12 },
  modalTitle: { fontSize: 20, fontWeight: '500' },
  modalGrid: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between' },
  modalItem: { width: '30%', aspectRatio: 1, borderRadius: 16, alignItems: 'center', justifyContent: 'center', marginBottom: 12 },
  modalItemText: { fontSize: 12 },
  closeBtn: { marginTop: 20, padding: 16, borderRadius: 30, alignItems: 'center' },

  // Settings
  settingsCard: { borderRadius: 24, overflow: 'hidden', marginBottom: 16 },
  settingRow: { flexDirection: 'row', alignItems: 'center', padding: 16 },
  settingText: { flex: 1, marginLeft: 16 },
  settingTitle: { fontSize: 16 },
  settingSub: { fontSize: 14 },

  // Theme Page
  themePage: { flex: 1 },
  themeGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 12 },
  themeCard: { width: '47%', borderRadius: 16, overflow: 'hidden', borderWidth: 2, marginBottom: 12, position: 'relative' },
  themeName: { textAlign: 'center', fontSize: 12, fontWeight: 'bold', paddingBottom: 8 },
  checkBadge: { position: 'absolute', bottom: 8, right: 8, borderRadius: 10, padding: 2 },
});

export default App;
