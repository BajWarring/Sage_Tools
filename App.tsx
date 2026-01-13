import React, { useState, useRef } from 'react';
import { SafeAreaView, StatusBar, View, Text, TouchableOpacity, Modal, Animated, StyleSheet, Dimensions, TouchableWithoutFeedback } from 'react-native';
import { THEMES } from './src/theme/themes';
import { DashboardTab } from './src/tabs/DashboardTab';
import { SettingsTab } from './src/tabs/SettingsTab';
import { MD3Icon } from './src/components/MD3Icon';

const { height: SCREEN_HEIGHT, width: SCREEN_WIDTH } = Dimensions.get('window');

export default function App() {
  const [themeName, setThemeName] = useState<keyof typeof THEMES>('sakura');
  const C = THEMES[themeName];
  const [activeTab, setActiveTab] = useState('dashboard');
  
  // Modal States
  const [modalType, setModalType] = useState<'none'|'tool'|'storage'|'theme'>('none');
  const [selectedTool, setSelectedTool] = useState<any>(null);
  const [storagePath, setStoragePath] = useState('/Internal/SageTools');

  // Animations
  const slideAnim = useRef(new Animated.Value(SCREEN_HEIGHT)).current;
  const themeSlideAnim = useRef(new Animated.Value(SCREEN_WIDTH)).current;
  const fadeAnim = useRef(new Animated.Value(0)).current;

  const openModal = (type: 'tool'|'storage') => {
    setModalType(type);
    Animated.parallel([
      Animated.timing(fadeAnim, { toValue: 1, duration: 200, useNativeDriver: true }),
      Animated.spring(slideAnim, { toValue: 0, useNativeDriver: true, bounciness: 0 })
    ]).start();
  };

  const closeModal = () => {
    Animated.parallel([
      Animated.timing(fadeAnim, { toValue: 0, duration: 200, useNativeDriver: true }),
      Animated.timing(slideAnim, { toValue: SCREEN_HEIGHT, duration: 250, useNativeDriver: true })
    ]).start(() => setModalType('none'));
  };

  const openThemePage = () => {
    setModalType('theme');
    Animated.timing(themeSlideAnim, { toValue: 0, duration: 300, useNativeDriver: true }).start();
  };

  const closeThemePage = () => {
    Animated.timing(themeSlideAnim, { toValue: SCREEN_WIDTH, duration: 250, useNativeDriver: true }).start(() => setModalType('none'));
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: C.surface }}>
      <StatusBar barStyle="dark-content" backgroundColor={C.surface} />

      {/* Header */}
      <View style={[styles.header, { backgroundColor: C.surface }]}>
        <Text style={{ fontSize: 22, color: C.onSurface, marginLeft: 8 }}>Sage Tools</Text>
        <View style={{ width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' }}>
          <MD3Icon symbol="👤" size={28} color={C.onSurfaceVariant} />
        </View>
      </View>

      {/* Tab Content */}
      {activeTab === 'dashboard' ? (
        <DashboardTab theme={C} onToolPress={(t: any) => { setSelectedTool(t); openModal('tool'); }} />
      ) : (
        <SettingsTab 
          theme={C} 
          themeName={themeName.toUpperCase()} 
          onThemePress={openThemePage} 
          storagePath={storagePath}
          onStoragePress={() => openModal('storage')}
        />
      )}

      {/* Bottom Nav */}
      <View style={[styles.nav, { backgroundColor: C.surfaceContainer, borderTopColor: C.outlineVariant + '20' }]}>
        <TouchableOpacity onPress={() => setActiveTab('dashboard')} style={{ alignItems: 'center', width: 80 }}>
          <View style={[styles.pill, activeTab === 'dashboard' && { backgroundColor: C.secondaryContainer }]}>
            <MD3Icon symbol="🗂️" color={activeTab === 'dashboard' ? C.onSecondaryContainer : C.onSurfaceVariant} />
          </View>
          <Text style={{ fontSize: 12, fontWeight: '600', color: activeTab === 'dashboard' ? C.onSurface : C.onSurfaceVariant }}>Dashboard</Text>
        </TouchableOpacity>

        <TouchableOpacity onPress={() => setActiveTab('settings')} style={{ alignItems: 'center', width: 80 }}>
          <View style={[styles.pill, activeTab === 'settings' && { backgroundColor: C.secondaryContainer }]}>
            <MD3Icon symbol="⚙️" color={activeTab === 'settings' ? C.onSecondaryContainer : C.onSurfaceVariant} />
          </View>
          <Text style={{ fontSize: 12, fontWeight: '600', color: activeTab === 'settings' ? C.onSurface : C.onSurfaceVariant }}>Settings</Text>
        </TouchableOpacity>
      </View>

      {/* Modal Backdrop */}
      {(modalType === 'tool' || modalType === 'storage') && (
        <TouchableWithoutFeedback onPress={closeModal}>
          <Animated.View style={{ position: 'absolute', inset: 0, backgroundColor: 'rgba(0,0,0,0.5)', opacity: fadeAnim }} />
        </TouchableWithoutFeedback>
      )}

      {/* Bottom Sheet */}
      <Animated.View style={[styles.sheet, { backgroundColor: C.surfaceContainer, transform: [{ translateY: slideAnim }] }]}>
        <View style={{ width: 32, height: 4, backgroundColor: '#79747e', opacity: 0.4, borderRadius: 2, alignSelf: 'center', marginTop: 16, marginBottom: 24 }} />
        
        {modalType === 'tool' && selectedTool && (
          <View style={{ padding: 24, paddingTop: 0 }}>
             <View style={{ alignItems: 'center', marginBottom: 24 }}>
                <View style={{ width: 64, height: 64, borderRadius: 20, alignItems: 'center', justifyContent: 'center', backgroundColor: C.primaryContainer }}>
                  <MD3Icon symbol={selectedTool.icon} size={32} color={C.onPrimaryContainer} />
                </View>
                <Text style={{ fontSize: 22, marginTop: 8, color: C.onSurface }}>{selectedTool.title}</Text>
             </View>
             <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 12 }}>
                {selectedTool.items.map((item: string, i: number) => (
                  <View key={i} style={{ width: '31%', aspectRatio: 1, borderRadius: 16, alignItems: 'center', justifyContent: 'center', padding: 8, backgroundColor: C.surfaceContainerHigh }}>
                    <MD3Icon symbol="🧩" size={24} color={C.primary} />
                    <Text style={{ fontSize: 11, textAlign: 'center', marginTop: 8, color: C.onSurface }}>{item}</Text>
                  </View>
                ))}
             </View>
          </View>
        )}

        {modalType === 'storage' && (
          <View style={{ padding: 24, paddingTop: 0 }}>
            <View style={{ alignItems: 'center', marginBottom: 24 }}>
              <MD3Icon symbol="📂" size={40} color={C.primary} />
              <Text style={{ fontSize: 22, marginTop: 8, color: C.onSurface }}>Select Storage</Text>
            </View>
            <TouchableOpacity onPress={() => { setStoragePath('/Internal/SageTools'); closeModal(); }} style={{ flexDirection: 'row', alignItems: 'center', padding: 16, borderRadius: 24, backgroundColor: C.secondaryContainer }}>
              <MD3Icon symbol="⭐" color={C.onSecondaryContainer} />
              <View style={{ flex: 1, marginLeft: 16 }}>
                 <Text style={{ fontWeight: '600', color: C.onSecondaryContainer }}>SageTools Default</Text>
                 <Text style={{ fontSize: 12, opacity: 0.7, color: C.onSecondaryContainer }}>Recommended</Text>
              </View>
              <MD3Icon symbol="✅" color={C.onSecondaryContainer} />
            </TouchableOpacity>
            <TouchableOpacity onPress={() => { setStoragePath('/Internal/Downloads'); closeModal(); }} style={{ flexDirection: 'row', alignItems: 'center', padding: 16, borderRadius: 24, borderColor: C.outlineVariant, borderWidth: 1, marginTop: 12 }}>
              <MD3Icon symbol="📥" color={C.onSurfaceVariant} />
              <View style={{ flex: 1, marginLeft: 16 }}>
                 <Text style={{ fontWeight: '600', color: C.onSurfaceVariant }}>Downloads Folder</Text>
              </View>
            </TouchableOpacity>
          </View>
        )}
      </Animated.View>

      {/* Theme Page */}
      {modalType === 'theme' && (
        <Animated.View style={{ position: 'absolute', inset: 0, zIndex: 50, backgroundColor: C.surface, transform: [{ translateX: themeSlideAnim }] }}>
          <View style={[styles.header, { borderBottomWidth: 1, borderBottomColor: C.outlineVariant }]}>
             <TouchableOpacity onPress={closeThemePage} style={{ width: 40, height: 40, alignItems: 'center', justifyContent: 'center' }}>
                <MD3Icon symbol="⬅️" size={24} color={C.onSurface} />
             </TouchableOpacity>
             <Text style={{ fontSize: 22, marginLeft: 0, color: C.onSurface }}>Appearance</Text>
          </View>
          <View style={{ padding: 24, flexDirection: 'row', flexWrap: 'wrap', gap: 12 }}>
              {Object.keys(THEMES).map((k) => {
                 const t = (THEMES as any)[k];
                 const isActive = themeName === k;
                 return (
                    <TouchableOpacity key={k} onPress={() => setThemeName(k as any)} style={{ width: '48%', aspectRatio: 0.6, borderRadius: 16, overflow: 'hidden', borderWidth: 2, marginBottom: 12, borderColor: isActive ? t.primary : 'transparent', backgroundColor: t.surfaceContainerHigh }}>
                        <View style={{ height: 40, backgroundColor: t.primaryContainer }} />
                        <View style={{ padding: 10, gap: 4 }}>
                           <View style={{ width: 40, height: 8, borderRadius: 4, backgroundColor: t.secondary }} />
                           <View style={{ width: 20, height: 8, borderRadius: 4, backgroundColor: t.outline }} />
                        </View>
                        <Text style={{ position: 'absolute', bottom: 0, width: '100%', textAlign: 'center', fontSize: 10, fontWeight: 'bold', backgroundColor: 'rgba(0,0,0,0.05)', paddingVertical: 4, color: t.onSurface }}>{k.toUpperCase()}</Text>
                        {isActive && <View style={{ position: 'absolute', bottom: 8, right: 8, width: 20, height: 20, borderRadius: 10, alignItems: 'center', justifyContent: 'center', backgroundColor: t.primary }}><MD3Icon symbol="✅" size={12} color={t.onPrimary} /></View>}
                    </TouchableOpacity>
                 )
              })}
          </View>
        </Animated.View>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  header: { height: 64, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, justifyContent: 'space-between' },
  nav: { position: 'absolute', bottom: 0, width: '100%', height: 80, flexDirection: 'row', justifyContent: 'space-around', alignItems: 'center', paddingBottom: 16, borderTopWidth: 1 },
  pill: { width: 64, height: 32, borderRadius: 16, alignItems: 'center', justifyContent: 'center', marginBottom: 4 },
  sheet: { position: 'absolute', bottom: 0, width: '100%', borderTopLeftRadius: 28, borderTopRightRadius: 28, zIndex: 20, paddingBottom: 20, maxHeight: '85%' },
});
