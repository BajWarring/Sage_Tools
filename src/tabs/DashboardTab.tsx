import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native';
import MD3Icon from '../components/MD3Icon';

// Define the Theme type (simplified based on your usage)
interface Theme {
  primary: string;
  onPrimary: string;
  primaryContainer: string;
  onPrimaryContainer: string;
  background: string;
  surface: string;
  surfaceVariant: string;
  onSurface: string;
  onSurfaceVariant: string;
  outline: string;
}

interface DashboardTabProps {
  theme: Theme;
  onOpenTools: () => void;
}

const DashboardTab: React.FC<DashboardTabProps> = ({ theme, onOpenTools }) => {
  return (
    <ScrollView 
      style={[styles.container, { backgroundColor: theme.background }]}
      contentContainerStyle={styles.contentContainer}
    >
      {/* Header Section */}
      <View style={styles.header}>
        <View>
          <Text style={[styles.greeting, { color: theme.onSurfaceVariant }]}>Welcome back,</Text>
          <Text style={[styles.title, { color: theme.onSurface }]}>Dashboard</Text>
        </View>
        <TouchableOpacity style={[styles.profileButton, { backgroundColor: theme.surfaceVariant }]}>
           <MD3Icon name="account" size={24} color={theme.onSurfaceVariant} />
        </TouchableOpacity>
      </View>

      {/* Summary Card */}
      <View style={[styles.card, { backgroundColor: theme.primaryContainer }]}>
        <View style={styles.cardRow}>
          <View>
            <Text style={[styles.cardLabel, { color: theme.onPrimaryContainer }]}>Total Balance</Text>
            <Text style={[styles.cardValue, { color: theme.onPrimaryContainer }]}>$12,450.00</Text>
          </View>
          <View style={[styles.iconCircle, { backgroundColor: 'rgba(255,255,255,0.2)' }]}>
            <MD3Icon name="wallet" size={24} color={theme.onPrimaryContainer} />
          </View>
        </View>
      </View>

      {/* Quick Actions Grid */}
      <Text style={[styles.sectionTitle, { color: theme.onSurface }]}>Quick Tools</Text>
      
      <View style={styles.grid}>
        <TouchableOpacity 
          style={[styles.gridItem, { backgroundColor: theme.surface, borderColor: theme.outline }]}
          onPress={onOpenTools}
        >
          <MD3Icon name="file-pdf-box" size={32} color={theme.primary} />
          <Text style={[styles.gridLabel, { color: theme.onSurface }]}>PDF Tools</Text>
        </TouchableOpacity>

        <TouchableOpacity 
          style={[styles.gridItem, { backgroundColor: theme.surface, borderColor: theme.outline }]}
        >
          <MD3Icon name="calculator" size={32} color={theme.primary} />
          <Text style={[styles.gridLabel, { color: theme.onSurface }]}>Calculator</Text>
        </TouchableOpacity>
        
         <TouchableOpacity 
          style={[styles.gridItem, { backgroundColor: theme.surface, borderColor: theme.outline }]}
        >
          <MD3Icon name="chart-box" size={32} color={theme.primary} />
          <Text style={[styles.gridLabel, { color: theme.onSurface }]}>Reports</Text>
        </TouchableOpacity>
        
         <TouchableOpacity 
          style={[styles.gridItem, { backgroundColor: theme.surface, borderColor: theme.outline }]}
        >
          <MD3Icon name="currency-usd" size={32} color={theme.primary} />
          <Text style={[styles.gridLabel, { color: theme.onSurface }]}>Payroll</Text>
        </TouchableOpacity>
      </View>

      {/* Recent Activity Placeholder */}
      <Text style={[styles.sectionTitle, { color: theme.onSurface, marginTop: 24 }]}>Recent Activity</Text>
      <View style={[styles.activityCard, { backgroundColor: theme.surface }]}>
         <Text style={{ color: theme.onSurfaceVariant, textAlign: 'center', padding: 20 }}>
           No recent activity found.
         </Text>
      </View>

    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  contentContainer: {
    padding: 20,
    paddingBottom: 100, // Space for bottom nav
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 24,
  },
  greeting: {
    fontSize: 14,
    fontWeight: '500',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
  },
  profileButton: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
  },
  card: {
    borderRadius: 20,
    padding: 24,
    marginBottom: 24,
    elevation: 2,
  },
  cardRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  cardLabel: {
    fontSize: 14,
    fontWeight: '600',
    opacity: 0.9,
    marginBottom: 4,
  },
  cardValue: {
    fontSize: 32,
    fontWeight: 'bold',
  },
  iconCircle: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 12,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  gridItem: {
    width: '48%', // Roughly half width
    padding: 20,
    borderRadius: 16,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 12,
  },
  gridLabel: {
    marginTop: 8,
    fontSize: 14,
    fontWeight: '600',
  },
  activityCard: {
    borderRadius: 16,
    padding: 10,
  }
});

export default DashboardTab;
