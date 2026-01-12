import React, { useState, useRef } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  StatusBar,
  Dimensions,
  Animated,
  SafeAreaView
} from 'react-native';
import { 
  UserCircle, 
  Grid, 
  Settings, 
  ArrowLeft, 
  CheckCircle, 
  FolderOpen, 
  Star, 
  Download, 
  MoreVertical, 
  History, 
  FileText, 
  Image as ImageIcon, 
  Video, 
  Palette, 
  Globe, 
  Trash2, 
  Info,
  Files,
  Wrench,
  Maximize,
  LucideIcon
} from 'lucide-react-native';

// --- 1. Type Definitions ---

interface ThemeColors {
  primary: string;
  onPrimary: string;
  primaryContainer: string;
  onPrimaryContainer: string;
  secondary: string;
  secondaryContainer: string;
  onSecondaryContainer: string;
  surface: string;
  surfaceContainer: string;
  surfaceContainerHigh: string;
  onSurface: string;
  onSurfaceVariant: string;
  outline: string;
  outlineVariant: string;
}

interface Theme {
  id: string;
  name: string;
  colors: ThemeColors;
}

interface ToolItem {
  id: string;
  title: string;
  icon: LucideIcon;
  count: number;
  items: string[];
}

interface FileItem {
  id: number;
  name: string;
  date: string;
  size: string;
  icon: LucideIcon;
}

// --- 2. Data Constants ---

const THEMES: Theme[] = [
  {
    id: 'sakura', name: 'Sakura',
    colors: {
      primary: '#984061', onPrimary: '#ffffff', primaryContainer: '#ffd9e2', onPrimaryContainer: '#3e001d',
      secondary: '#74565f', secondaryContainer: '#ffd9e2', onSecondaryContainer: '#2b151c',
      surface: '#fff8f8', surfaceContainer: '#fceaea', surfaceContainerHigh: '#fff0f3',
      onSurface: '#201a1b', onSurfaceVariant: '#514347', outline: '#837377', outlineVariant: '#d5c2c6'
    }
  },
  {
    id: 'lavender', name: 'Lavender',
    colors: {
      primary: '#6750a4', onPrimary: '#ffffff', primaryContainer: '#eaddff', onPrimaryContainer: '#21005d',
      secondary: '#625b71', secondaryContainer: '#e8def8', onSecondaryContainer: '#1d192b',
      surface: '#fff7fe', surfaceContainer: '#f3eefc', surfaceContainerHigh: '#f7f2fa',
      onSurface: '#1c1b1f', onSurfaceVariant: '#49454f', outline: '#79747e', outlineVariant: '#cac4d0'
    }
  },
  {
    id: 'mint', name: 'Mint',
    colors: {
      primary: '#006c4c', onPrimary: '#ffffff', primaryContainer: '#89f8c7', onPrimaryContainer: '#002114',
      secondary: '#4c6358', secondaryContainer: '#cee9da', onSecondaryContainer: '#092016',
      surface: '#fbfdf9', surfaceContainer: '#edf5ef', surfaceContainerHigh: '#e7f0eb',
      onSurface: '#191c1a', onSurfaceVariant: '#404944', outline: '#707974', outlineVariant: '#bfc9c2'
    }
  },
  {
    id: 'ocean', name: 'Ocean',
    colors: {
      primary: '#006492', onPrimary: '#ffffff', primaryContainer: '#cae6ff', onPrimaryContainer: '#001e30',
      secondary: '#50606e', secondaryContainer: '#d3e4f5', onSecondaryContainer: '#0c1d29',
      surface: '#f8fdff', surfaceContainer: '#eaf2f8', surfaceContainerHigh: '#e4eff5',
      onSurface: '#191c1e', onSurfaceVariant: '#42474e', outline: '#72777f', outlineVariant: '#c2c7cf'
    }
  },
  {
    id: 'lemon', name: 'Lemon',
    colors: {
      primary: '#685e0e', onPrimary: '#ffffff', primaryContainer: '#f1e386', onPrimaryContainer: '#1f1b00',
      secondary: '#645f41', secondaryContainer: '#ebe3be', onSecondaryContainer: '#1f1c05',
      surface: '#fffbf3', surfaceContainer: '#f5f0e4', surfaceContainerHigh: '#efeadd',
      onSurface: '#1d1c16', onSurfaceVariant: '#49473a', outline: '#7a7768', outlineVariant: '#cbc6b5'
    }
  },
  {
    id: 'tangerine', name: 'Tangerine',
    colors: {
      primary: '#8c4f00', onPrimary: '#ffffff', primaryContainer: '#ffdcbe', onPrimaryContainer: '#2d1600',
      secondary: '#745845', secondaryContainer: '#ffdcc0', onSecondaryContainer: '#2b1708',
      surface: '#fff8f5', surfaceContainer: '#ffede6', surfaceContainerHigh: '#fae7de',
      onSurface: '#211a15', onSurfaceVariant: '#51443a', outline: '#837469', outlineVariant: '#d6c3b5'
    }
  },
  {
    id: 'royal', name: 'Royal',
    colors: {
      primary: '#4355b9', onPrimary: '#ffffff', primaryContainer: '#deellf', onPrimaryContainer: '#00105c',
      secondary: '#5a5d72', secondaryContainer: '#dfe1f9', onSecondaryContainer: '#171a2c',
      surface: '#fefbff', surfaceContainer: '#f1eff4', surfaceContainerHigh: '#ebeef3',
      onSurface: '#1b1b1f', onSurfaceVariant: '#46464f', outline: '#777680', outlineVariant: '#c7c5d0'
    }
  },
  {
    id: 'oled', name: 'OLED',
    colors: {
      primary: '#bfc2ff', onPrimary: '#15216f', primaryContainer: '#2d3a87', onPrimaryContainer: '#e0e0ff',
      secondary: '#c4c5dd', secondaryContainer: '#434659', onSecondaryContainer: '#e1e1f9',
      surface: '#000000', surfaceContainer: '#121212', surfaceContainerHigh: '#1e1e1e',
      onSurface: '#e4e1e6', onSurfaceVariant: '#c7c5d0', outline: '#91909a', outlineVariant: '#46464f'
    }
  }
];

const TOOLS: ToolItem[] = [
  { id: 'pdf', title: 'PDF Tools', icon: Files, count: 6, items: ['Merge', 'Split', 'Sign', 'Compress', 'OCR'] },
  { id: 'img', title: 'Image Editor', icon: ImageIcon, count: 5, items: ['Resize', 'Crop', 'Filter', 'Convert', 'Markup'] },
  { id: 'vid', title: 'Video Studio', icon: Video, count: 4, items: ['Trim', 'Audio', 'Speed', 'Mute'] },
  { id: 'util', title: 'Utilities', icon: Wrench, count: 8, items: ['QR Gen', 'Scanner', 'Units', 'Time', 'Text'] }
];

const FILES: FileItem[] = [
  { id: 1, name: 'Invoice_2026.pdf', date: '2h ago', size: '1.2MB', icon: FileText },
  { id: 2, name: 'Trip_Vlog.mp4', date: 'Yesterday', size: '142MB', icon: Video },
  { id: 3, name: 'Avatar.png', date: 'Oct 24', size: '2.8MB', icon: ImageIcon },
  { id: 4, name: 'Notes.txt', date: 'Oct 22', size: '12KB', icon: FileText }
];

// --- 3. Main Component ---

export default function SageToolsApp() {
  const [currentTheme, setCurrentTheme] = useState<Theme>(THEMES[0]);
  const [activeTab, setActiveTab] = useState<'dashboard' | 'settings'>('dashboard');
  const [storagePath, setStoragePath] = useState<string>('/Internal/SageTools');
  
  // Modals/Sheets State
  const [isThemeOpen, setIsThemeOpen] = useState<boolean>(false);
  const [isStorageOpen, setIsStorageOpen] = useState<boolean>(false);
  const [activeTool, setActiveTool] = useState<ToolItem | null>(null);

  // Animations
  const themeSlideAnim = useRef(new Animated.Value(Dimensions.get('window').width)).current;
  const storageSlideAnim = useRef(new Animated.Value(300)).current;
  const toolSlideAnim = useRef(new Animated.Value(300)).current;

  // Shortcuts to current colors
  const C = currentTheme.colors;

  // --- Animation Handlers ---
  const openTheme = () => {
    setIsThemeOpen(true);
    Animated.timing(themeSlideAnim, { toValue: 0, duration: 300, useNativeDriver: true }).start();
  };
  const closeTheme = () => {
    Animated.timing(themeSlideAnim, { toValue: Dimensions.get('window').width, duration: 300, useNativeDriver: true }).start(() => setIsThemeOpen(false));
  };

  const openStorage = () => {
    setIsStorageOpen(true);
    Animated.spring(storageSlideAnim, { toValue: 0, useNativeDriver: true }).start();
  };
  const closeStorage = () => {
    Animated.timing(storageSlideAnim, { toValue: 300, duration: 200, useNativeDriver: true }).start(() => setIsStorageOpen(false));
  };

  const openTool = (tool: ToolItem) => {
    setActiveTool(tool);
    Animated.spring(toolSlideAnim, { toValue: 0, useNativeDriver: true }).start();
  };
  const closeTool = () => {
    Animated.timing(toolSlideAnim, { toValue: Dimensions.get('window').height, duration: 200, useNativeDriver: true }).start(() => setActiveTool(null));
  };

  // --- Views ---

  const renderDashboard = () => (
    <ScrollView contentContainerStyle={{ paddingBottom: 100, paddingTop: 10, paddingHorizontal: 16 }} showsVerticalScrollIndicator={false}>
      
      {/* Resume Section */}
      <View style={{ marginBottom: 24 }}>
        <Text style={[styles.sectionHeader, { color: C.onSurfaceVariant }]}>Continue Editing</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginLeft: -4 }}>
          {FILES.slice(0,3).map((f) => (
            <View key={'resume-'+f.id} style={[styles.cardFlat, { backgroundColor: C.surfaceContainer, width: 140, marginRight: 8 }]}>
              <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 8 }}>
                <History size={20} color={C.primary} />
                <Text style={{ fontSize: 10, fontWeight: 'bold', color: C.onSurfaceVariant }}>RESUME</Text>
              </View>
              <View>
                <Text numberOfLines={1} style={{ fontSize: 12, fontWeight: '500', color: C.onSurface, marginBottom: 2 }}>{f.name}</Text>
                <Text style={{ fontSize: 10, color: C.onSurfaceVariant }}>Edited {f.date}</Text>
              </View>
            </View>
          ))}
        </ScrollView>
      </View>

      {/* Tools Grid */}
      <Text style={[styles.sectionHeader, { color: C.onSurfaceVariant }]}>Tools</Text>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', marginBottom: 24 }}>
        {TOOLS.map((t) => (
          <TouchableOpacity 
            key={t.id} 
            onPress={() => openTool(t)}
            activeOpacity={0.9}
            style={[styles.card, { backgroundColor: C.surfaceContainerHigh, width: '48%', height: 144, marginBottom: 12, justifyContent: 'space-between' }]}
          >
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <View style={{ width: 48, height: 48, borderRadius: 16, backgroundColor: C.primaryContainer, alignItems: 'center', justifyContent: 'center' }}>
                <t.icon size={24} color={C.onPrimaryContainer} />
              </View>
              <View style={{ paddingHorizontal: 8, paddingVertical: 4, borderRadius: 8, backgroundColor: C.surfaceContainer }}>
                <Text style={{ fontSize: 12, fontWeight: '500', color: C.onSurfaceVariant }}>{t.count}</Text>
              </View>
            </View>
            <View>
              <Text style={{ fontSize: 16, fontWeight: '500', color: C.onSurface }}>{t.title}</Text>
              <Text style={{ fontSize: 12, color: C.onSurfaceVariant }}>Tap to open</Text>
            </View>
          </TouchableOpacity>
        ))}
      </View>

      {/* Saved Files */}
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
        <Text style={[styles.sectionHeader, { color: C.onSurfaceVariant, marginBottom: 0 }]}>Saved Files</Text>
        <TouchableOpacity><Text style={{ fontSize: 14, fontWeight: '500', color: C.primary }}>View All</Text></TouchableOpacity>
      </View>
      
      {FILES.map((f) => (
        <View key={f.id} style={[styles.cardFlat, { backgroundColor: C.surfaceContainer, flexDirection: 'row', alignItems: 'center', marginBottom: 8 }]}>
          <View style={{ width: 40, height: 40, borderRadius: 20, backgroundColor: C.secondaryContainer, alignItems: 'center', justifyContent: 'center', marginRight: 16 }}>
            <f.icon size={20} color={C.onSecondaryContainer} />
          </View>
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 14, fontWeight: '500', color: C.onSurface }}>{f.name}</Text>
            <Text style={{ fontSize: 12, color: C.onSurfaceVariant }}>{f.size} • {f.date}</Text>
          </View>
          <MoreVertical size={20} color={C.onSurfaceVariant} />
        </View>
      ))}

    </ScrollView>
  );

  const renderSettings = () => (
    <ScrollView contentContainerStyle={{ padding: 16 }} showsVerticalScrollIndicator={false}>
      
      <View style={[styles.card, { backgroundColor: C.surfaceContainerHigh, padding: 0, overflow: 'hidden', marginBottom: 24 }]}>
        <TouchableOpacity onPress={openTheme} style={styles.listItem}>
          <Palette size={24} color={C.primary} style={{ marginRight: 16 }} />
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 16, color: C.onSurface }}>Theme</Text>
            <Text style={{ fontSize: 14, color: C.onSurfaceVariant, textTransform: 'capitalize' }}>{currentTheme.name}</Text>
          </View>
        </TouchableOpacity>
        <View style={{ height: 1, backgroundColor: C.outlineVariant }} />
        <TouchableOpacity style={styles.listItem}>
          <Globe size={24} color={C.onSurfaceVariant} style={{ marginRight: 16 }} />
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 16, color: C.onSurface }}>Language</Text>
            <Text style={{ fontSize: 14, color: C.onSurfaceVariant }}>English (US)</Text>
          </View>
        </TouchableOpacity>
      </View>

      <Text style={{ fontSize: 14, fontWeight: '500', color: C.primary, marginBottom: 8, marginLeft: 16 }}>Data & Storage</Text>
      <View style={[styles.card, { backgroundColor: C.surfaceContainerHigh, padding: 0, overflow: 'hidden', marginBottom: 24 }]}>
        <TouchableOpacity onPress={openStorage} style={styles.listItem}>
          <FolderOpen size={24} color={C.onSurfaceVariant} style={{ marginRight: 16 }} />
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 16, color: C.onSurface }}>Storage Location</Text>
            <Text style={{ fontSize: 14, color: C.onSurfaceVariant }}>{storagePath}</Text>
          </View>
        </TouchableOpacity>
        <View style={{ height: 1, backgroundColor: C.outlineVariant }} />
        <TouchableOpacity style={styles.listItem}>
          <Trash2 size={24} color={C.onSurfaceVariant} style={{ marginRight: 16 }} />
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 16, color: C.onSurface }}>Clear Cache</Text>
            <Text style={{ fontSize: 14, color: C.onSurfaceVariant }}>14 MB</Text>
          </View>
        </TouchableOpacity>
      </View>

      <Text style={{ fontSize: 14, fontWeight: '500', color: C.primary, marginBottom: 8, marginLeft: 16 }}>About</Text>
      <View style={[styles.card, { backgroundColor: C.surfaceContainerHigh, padding: 0, overflow: 'hidden' }]}>
        <TouchableOpacity style={styles.listItem}>
          <Info size={24} color={C.onSurfaceVariant} style={{ marginRight: 16 }} />
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 16, color: C.onSurface }}>Version</Text>
            <Text style={{ fontSize: 14, color: C.onSurfaceVariant }}>7.1.0 (Material You)</Text>
          </View>
        </TouchableOpacity>
      </View>
    </ScrollView>
  );

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: C.surface }}>
      <StatusBar barStyle={currentTheme.id === 'oled' ? 'light-content' : 'dark-content'} backgroundColor={C.surface} />
      
      {/* Top App Bar */}
      <View style={{ height: 60, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 16, backgroundColor: C.surface }}>
        <Text style={{ fontSize: 22, color: C.onSurface }}>Sage Tools</Text>
        <TouchableOpacity style={{ padding: 8 }}>
           <UserCircle size={28} color={C.onSurfaceVariant} />
        </TouchableOpacity>
      </View>

      {/* Main Content */}
      <View style={{ flex: 1 }}>
        {activeTab === 'dashboard' ? renderDashboard() : renderSettings()}
      </View>

      {/* Navigation Bar */}
      <View style={{ height: 80, flexDirection: 'row', backgroundColor: C.surfaceContainer, borderTopWidth: 1, borderTopColor: C.outlineVariant + '20', alignItems: 'flex-start', paddingTop: 12 }}>
        
        {/* Dash Tab */}
        <TouchableOpacity 
          onPress={() => setActiveTab('dashboard')}
          style={{ flex: 1, alignItems: 'center' }}
        >
           <View style={{ 
             width: 64, height: 32, borderRadius: 16, alignItems: 'center', justifyContent: 'center',
             backgroundColor: activeTab === 'dashboard' ? C.secondaryContainer : 'transparent'
           }}>
             <Grid size={24} color={activeTab === 'dashboard' ? C.onSecondaryContainer : C.onSurfaceVariant} />
           </View>
           {activeTab === 'dashboard' && (
             <Text style={{ fontSize: 12, fontWeight: '600', marginTop: 4, color: C.onSurface }}>Dashboard</Text>
           )}
        </TouchableOpacity>

        {/* Settings Tab */}
        <TouchableOpacity 
          onPress={() => setActiveTab('settings')}
          style={{ flex: 1, alignItems: 'center' }}
        >
           <View style={{ 
             width: 64, height: 32, borderRadius: 16, alignItems: 'center', justifyContent: 'center',
             backgroundColor: activeTab === 'settings' ? C.secondaryContainer : 'transparent'
           }}>
             <Settings size={24} color={activeTab === 'settings' ? C.onSecondaryContainer : C.onSurfaceVariant} />
           </View>
           {activeTab === 'settings' && (
             <Text style={{ fontSize: 12, fontWeight: '600', marginTop: 4, color: C.onSurface }}>Settings</Text>
           )}
        </TouchableOpacity>

      </View>

      {/* --- Theme Selector Modal (Full Screen Slide) --- */}
      {isThemeOpen && (
        <Animated.View style={[StyleSheet.absoluteFill, { backgroundColor: C.surface, transform: [{ translateX: themeSlideAnim }], zIndex: 50 }]}>
           <SafeAreaView style={{ flex: 1 }}>
             <View style={{ height: 64, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, borderBottomWidth: 1, borderBottomColor: C.outlineVariant }}>
               <TouchableOpacity onPress={closeTheme} style={{ marginRight: 16 }}>
                 <ArrowLeft size={24} color={C.onSurface} />
               </TouchableOpacity>
               <Text style={{ fontSize: 20, color: C.onSurface }}>Appearance</Text>
             </View>
             
             <View style={{ padding: 24 }}>
                <Text style={{ fontSize: 14, fontWeight: '500', color: C.onSurfaceVariant, marginBottom: 16 }}>Select Theme</Text>
                
                <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingRight: 24 }}>
                  {THEMES.map((t) => {
                    const isActive = t.id === currentTheme.id;
                    const TC = t.colors;
                    return (
                      <TouchableOpacity 
                        key={t.id}
                        onPress={() => setCurrentTheme(t)}
                        style={{ width: 140, aspectRatio: 9/16, marginRight: 16, borderRadius: 24, borderWidth: isActive ? 3 : 1, borderColor: isActive ? C.primary : '#e5e5e5', backgroundColor: TC.surface, overflow: 'hidden', position: 'relative' }}
                      >
                         {/* Mini UI Mockup */}
                         <View style={{ flex: 1 }}>
                           <View style={{ height: 32, backgroundColor: TC.surfaceContainer, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 8 }}>
                             <View style={{ width: 12, height: 12, borderRadius: 6, backgroundColor: TC.onSurface, opacity: 0.5, marginRight: 4 }} />
                             <View style={{ width: 40, height: 8, borderRadius: 4, backgroundColor: TC.onSurface, opacity: 0.2 }} />
                           </View>
                           <View style={{ padding: 8 }}>
                             <View style={{ height: 48, borderRadius: 12, backgroundColor: TC.secondaryContainer, marginBottom: 8 }} />
                             <View style={{ flexDirection: 'row', gap: 8 }}>
                               <View style={{ flex: 1, height: 40, borderRadius: 12, backgroundColor: TC.surfaceContainer }} />
                               <View style={{ flex: 1, height: 40, borderRadius: 12, backgroundColor: TC.surfaceContainer }} />
                             </View>
                           </View>
                           <View style={{ position: 'absolute', bottom: 12, right: 12, width: 32, height: 32, borderRadius: 8, backgroundColor: TC.primary, alignItems: 'center', justifyContent: 'center' }}>
                             <View style={{ width: 12, height: 12, backgroundColor: 'white', borderRadius: 2 }} />
                           </View>
                         </View>
                         {/* Label */}
                         <View style={{ position: 'absolute', bottom: 0, width: '100%', paddingVertical: 4, backgroundColor: 'rgba(0,0,0,0.05)', alignItems: 'center' }}>
                            <Text style={{ fontSize: 10, fontWeight: 'bold', color: TC.onSurface, textTransform: 'uppercase' }}>{t.name}</Text>
                         </View>
                         {isActive && (
                           <View style={{ position: 'absolute', bottom: 30, right: 8, backgroundColor: C.primary, borderRadius: 12 }}>
                             <CheckCircle size={20} color={C.onPrimary} />
                           </View>
                         )}
                      </TouchableOpacity>
                    );
                  })}
                </ScrollView>
             </View>
           </SafeAreaView>
        </Animated.View>
      )}

      {/* --- Storage Modal (Bottom Sheet) --- */}
      {isStorageOpen && (
        <View style={StyleSheet.absoluteFill}>
           <TouchableOpacity onPress={closeStorage} style={[StyleSheet.absoluteFill, { backgroundColor: 'rgba(0,0,0,0.5)' }]} />
           <Animated.View style={{ 
             position: 'absolute', bottom: 0, left: 0, right: 0, 
             backgroundColor: C.surfaceContainer, borderTopLeftRadius: 28, borderTopRightRadius: 28,
             paddingBottom: 40, transform: [{ translateY: storageSlideAnim }] 
           }}>
              <View style={{ alignItems: 'center', paddingTop: 16, paddingBottom: 16 }}>
                <View style={{ width: 32, height: 4, borderRadius: 2, backgroundColor: C.outlineVariant, opacity: 0.4 }} />
              </View>
              <View style={{ paddingHorizontal: 24 }}>
                 <View style={{ alignItems: 'center', marginBottom: 24 }}>
                    <FolderOpen size={48} color={C.primary} />
                    <Text style={{ fontSize: 20, color: C.onSurface, marginTop: 8 }}>Select Storage</Text>
                 </View>
                 
                 <TouchableOpacity onPress={() => { setStoragePath('/Internal/SageTools'); closeStorage(); }} style={{ flexDirection: 'row', alignItems: 'center', padding: 16, borderRadius: 24, backgroundColor: C.secondaryContainer, marginBottom: 8 }}>
                    <Star size={24} color={C.onSecondaryContainer} />
                    <View style={{ flex: 1, marginLeft: 16 }}>
                       <Text style={{ fontSize: 14, fontWeight: '500', color: C.onSecondaryContainer }}>SageTools Default</Text>
                       <Text style={{ fontSize: 12, color: C.onSecondaryContainer, opacity: 0.7 }}>Recommended</Text>
                    </View>
                    <CheckCircle size={24} color={C.onSecondaryContainer} />
                 </TouchableOpacity>

                 <TouchableOpacity onPress={() => { setStoragePath('/Internal/Downloads'); closeStorage(); }} style={{ flexDirection: 'row', alignItems: 'center', padding: 16, borderRadius: 24, borderColor: C.outlineVariant, borderWidth: 1 }}>
                    <Download size={24} color={C.onSurfaceVariant} />
                    <View style={{ flex: 1, marginLeft: 16 }}>
                       <Text style={{ fontSize: 14, fontWeight: '500', color: C.onSurfaceVariant }}>Downloads Folder</Text>
                    </View>
                 </TouchableOpacity>
              </View>
           </Animated.View>
        </View>
      )}

      {/* --- Tool Detail Modal (Bottom Sheet) --- */}
      {activeTool && (
        <View style={[StyleSheet.absoluteFill, { zIndex: 100 }]}>
           <TouchableOpacity onPress={closeTool} style={[StyleSheet.absoluteFill, { backgroundColor: 'rgba(0,0,0,0.5)' }]} />
           <Animated.View style={{ 
             position: 'absolute', bottom: 0, left: 0, right: 0, maxHeight: '85%',
             backgroundColor: C.surfaceContainer, borderTopLeftRadius: 28, borderTopRightRadius: 28,
             paddingBottom: 40, transform: [{ translateY: toolSlideAnim }] 
           }}>
             <View style={{ alignItems: 'center', paddingTop: 16, paddingBottom: 8 }}>
                <View style={{ width: 32, height: 4, borderRadius: 2, backgroundColor: C.outlineVariant, opacity: 0.4 }} />
              </View>
              <ScrollView contentContainerStyle={{ padding: 24 }}>
                 <View style={{ alignItems: 'center', marginBottom: 24 }}>
                    <View style={{ width: 64, height: 64, borderRadius: 16, backgroundColor: C.primaryContainer, alignItems: 'center', justifyContent: 'center', marginBottom: 12 }}>
                       <activeTool.icon size={32} color={C.onPrimaryContainer} />
                    </View>
                    <Text style={{ fontSize: 20, color: C.onSurface }}>{activeTool.title}</Text>
                 </View>
                 <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 12 }}>
                    {activeTool.items.map((item, idx) => (
                      <TouchableOpacity key={idx} style={{ width: '30%', backgroundColor: C.surfaceContainerHigh, borderRadius: 16, padding: 12, alignItems: 'center', marginBottom: 8 }}>
                         <Maximize size={24} color={C.primary} style={{ marginBottom: 8 }} />
                         <Text style={{ fontSize: 12, color: C.onSurface, textAlign: 'center' }}>{item}</Text>
                      </TouchableOpacity>
                    ))}
                 </View>
              </ScrollView>
           </Animated.View>
        </View>
      )}

    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: 24,
    padding: 16,
  },
  cardFlat: {
    borderRadius: 16,
    padding: 12,
  },
  sectionHeader: {
    fontSize: 14,
    fontWeight: '500',
    marginBottom: 12,
    marginLeft: 4,
  },
  listItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
  }
});
