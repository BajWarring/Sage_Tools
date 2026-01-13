import React, { useState } from 'react';
import { 
  SafeAreaView, 
  StatusBar, 
  View, 
  StyleSheet, 
  TouchableOpacity, 
  Text 
} from 'react-native';

// 1. Imports based on your structure
import { themes } from './theme/themes'; 
import DashboardTab from './tabs/DashboardTab';
import SettingsTab from './tabs/SettingsTab';
import Sheets from './components/Sheets';
import MD3Icon from './components/MD3Icon';

// Define available tabs
type TabName = 'dashboard' | 'settings';

const App = () => {
  // --- STATE MANAGEMENT ---
  const [activeTab, setActiveTab] = useState<TabName>('dashboard');
  const [activeThemeId, setActiveThemeId] = useState<string>('sakura'); // Default theme
  const [isSheetVisible, setSheetVisible] = useState(false);
  const [sheetType, setSheetType] = useState<'tools' | 'storage'>('tools');

  // Load current theme colors
  // Assuming themes export looks like: { sakura: { primary: '...', background: '...' } }
  const theme = themes[activeThemeId as keyof typeof themes];

  // --- HANDLERS ---
  const handleOpenSheet = (type: 'tools' | 'storage') => {
    setSheetType(type);
    setSheetVisible(true);
  };

  const handleCloseSheet = () => {
    setSheetVisible(false);
  };

  // --- RENDERERS ---
  
  // Decides which Tab component to show
  const renderContent = () => {
    if (activeTab === 'dashboard') {
      return (
        <DashboardTab 
          theme={theme} 
          onOpenTools={() => handleOpenSheet('tools')} 
        />
      );
    }
    return (
      <SettingsTab 
        theme={theme} 
        currentThemeId={activeThemeId} 
        onChangeTheme={setActiveThemeId} 
      />
    );
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: theme.background }]}>
      <StatusBar 
        barStyle="dark-content" 
        backgroundColor={theme.background} 
      />

      {/* 1. Main Content Area */}
      <View style={styles.contentContainer}>
        {renderContent()}
      </View>

      {/* 2. Custom Bottom Navigation Bar */}
      <View style={[styles.navBar, { backgroundColor: theme.surface, borderTopColor: theme.outlineVariant }]}>
        
        {/* Dashboard Tab Button */}
        <TouchableOpacity 
          style={styles.navItem} 
          onPress={() => setActiveTab('dashboard')}
        >
          <MD3Icon 
            name={activeTab === 'dashboard' ? 'view-dashboard' : 'view-dashboard-outline'} 
            size={24} 
            color={activeTab === 'dashboard' ? theme.primary : theme.onSurfaceVariant} 
          />
          <Text style={{ 
            color: activeTab === 'dashboard' ? theme.primary : theme.onSurfaceVariant,
            fontSize: 12,
            marginTop: 4,
            fontWeight: activeTab === 'dashboard' ? 'bold' : 'normal'
          }}>
            Home
          </Text>
        </TouchableOpacity>

        {/* Central Action Button (Optional - e.g., Quick Add or Open Tools) */}
        <TouchableOpacity 
          style={[styles.fab, { backgroundColor: theme.primaryContainer }]}
          onPress={() => handleOpenSheet('tools')}
        >
           <MD3Icon name="plus" size={28} color={theme.onPrimaryContainer} />
        </TouchableOpacity>

        {/* Settings Tab Button */}
        <TouchableOpacity 
          style={styles.navItem} 
          onPress={() => setActiveTab('settings')}
        >
          <MD3Icon 
            name={activeTab === 'settings' ? 'cog' : 'cog-outline'} 
            size={24} 
            color={activeTab === 'settings' ? theme.primary : theme.onSurfaceVariant} 
          />
          <Text style={{ 
            color: activeTab === 'settings' ? theme.primary : theme.onSurfaceVariant,
            fontSize: 12,
            marginTop: 4,
            fontWeight: activeTab === 'settings' ? 'bold' : 'normal'
          }}>
            Settings
          </Text>
        </TouchableOpacity>
      </View>

      {/* 3. Global Sheets Overlay */}
      {/* This sits on top of everything when visible */}
      {isSheetVisible && (
        <Sheets 
          visible={isSheetVisible}
          type={sheetType}
          theme={theme}
          onClose={handleCloseSheet}
        />
      )}

    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  contentContainer: {
    flex: 1, // Takes up all space above the navbar
  },
  navBar: {
    flexDirection: 'row',
    height: 80,
    borderTopWidth: 1,
    alignItems: 'center',
    justifyContent: 'space-around',
    paddingBottom: 20, // Padding for iOS Home Indicator
    elevation: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: -2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  navItem: {
    alignItems: 'center',
    justifyContent: 'center',
    width: 60,
  },
  fab: {
    width: 56,
    height: 56,
    borderRadius: 28,
    justifyContent: 'center',
    alignItems: 'center',
    top: -20, // Moves it slightly above the navbar
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 4,
  }
});

export default App;
