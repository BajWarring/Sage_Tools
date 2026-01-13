import React, { useState } from 'react';
import { SafeAreaView, StatusBar, View, StyleSheet, TouchableOpacity, Text } from 'react-native';

// Imports
import { themes } from './theme/themes'; 
import DashboardTab from './tabs/DashboardTab';
import SettingsTab from './tabs/SettingsTab';
import Sheets from './components/Sheets'; 
import MD3Icon from './components/MD3Icon';

const App = () => {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [activeThemeId, setActiveThemeId] = useState('sakura'); 
  const [isSheetVisible, setSheetVisible] = useState(false);
  const [sheetType, setSheetType] = useState('tools');
  const [selectedToolId, setSelectedToolId] = useState('');

  // Get current theme object
  const theme = themes[activeThemeId as keyof typeof themes];

  const handleOpenTool = (toolId: string) => {
    setSelectedToolId(toolId);
    setSheetType('tools');
    setSheetVisible(true);
  };

  const handleOpenStorage = () => {
    setSheetType('storage');
    setSheetVisible(true);
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: theme.surface }]}>
      <StatusBar barStyle="dark-content" backgroundColor={theme.surface} />

      {/* Main Content */}
      <View style={{ flex: 1 }}>
        {activeTab === 'dashboard' ? (
          <DashboardTab theme={theme} onOpenTools={handleOpenTool} />
        ) : (
          <SettingsTab 
            theme={theme} 
            currentThemeId={activeThemeId} 
            onChangeTheme={setActiveThemeId} 
            onOpenStorage={handleOpenStorage}
          />
        )}
      </View>

      {/* Navigation Bar */}
      <View style={[styles.navBar, { backgroundColor: theme.surfaceContainer, borderTopColor: theme.outlineVariant }]}>
        <TouchableOpacity 
          style={[styles.navItem, activeTab === 'dashboard' && styles.navItemActive]} 
          onPress={() => setActiveTab('dashboard')}
        >
          <View style={[styles.navIndicator, activeTab === 'dashboard' && { backgroundColor: theme.secondaryContainer }]}>
            <MD3Icon name={activeTab === 'dashboard' ? 'view-dashboard' : 'view-dashboard-outline'} 
                     size={24} 
                     color={activeTab === 'dashboard' ? theme.onSecondaryContainer : theme.onSurfaceVariant} />
          </View>
          <Text style={[styles.navLabel, { color: theme.onSurface }]}>Dashboard</Text>
        </TouchableOpacity>

        <TouchableOpacity 
          style={[styles.navItem, activeTab === 'settings' && styles.navItemActive]} 
          onPress={() => setActiveTab('settings')}
        >
           <View style={[styles.navIndicator, activeTab === 'settings' && { backgroundColor: theme.secondaryContainer }]}>
            <MD3Icon name={activeTab === 'settings' ? 'cog' : 'cog-outline'} 
                     size={24} 
                     color={activeTab === 'settings' ? theme.onSecondaryContainer : theme.onSurfaceVariant} />
          </View>
          <Text style={[styles.navLabel, { color: theme.onSurface }]}>Settings</Text>
        </TouchableOpacity>
      </View>

      {/* Actual Sheets Component - This was missing before! */}
      {isSheetVisible && (
        <Sheets 
          visible={isSheetVisible}
          type={sheetType} // This passes 'tools' or 'storage'
          theme={theme}
          onClose={() => setSheetVisible(false)}
        />
      )}

    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1 },
  navBar: {
    height: 80,
    flexDirection: 'row',
    justifyContent: 'space-around',
    alignItems: 'center',
    borderTopWidth: 1,
    paddingBottom: 10
  },
  navItem: { alignItems: 'center', width: 64 },
  navItemActive: {},
  navIndicator: { width: 64, height: 32, borderRadius: 16, alignItems: 'center', justifyContent: 'center', marginBottom: 4 },
  navLabel: { fontSize: 12, fontWeight: '600' }
});

export default App;
