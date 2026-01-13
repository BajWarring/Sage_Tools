import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Modal, ScrollView } from 'react-native';
import DocumentPicker from 'react-native-document-picker';
import MD3Icon from './MD3Icon';
import PdfCropEditor from './PdfCropEditor'; // Import the new editor

interface SheetsProps {
  visible: boolean;
  type: string; // 'tools' or 'storage'
  theme: any;
  onClose: () => void;
}

const Sheets: React.FC<SheetsProps> = ({ visible, type, theme, onClose }) => {
  const [selectedFile, setSelectedFile] = useState<string | null>(null);

  // 1. Handle File Selection
  const handlePickPdf = async () => {
    try {
      const res = await DocumentPicker.pickSingle({
        type: [DocumentPicker.types.pdf],
      });
      setSelectedFile(res.uri);
    } catch (err) {
      if (DocumentPicker.isCancel(err)) {
        // User cancelled
      } else {
        console.error('Unknown Error: ', err);
      }
    }
  };

  // 2. Render The Tool Grid
  const renderTools = () => {
    return (
      <View style={styles.grid}>
        {/* The PDF Crop Tool */}
        <TouchableOpacity 
          style={[styles.toolItem, { backgroundColor: theme.secondaryContainer }]}
          onPress={handlePickPdf}
        >
          <MD3Icon name="crop" size={32} color={theme.onSecondaryContainer} />
          <Text style={[styles.toolLabel, { color: theme.onSurface }]}>PDF Crop</Text>
        </TouchableOpacity>

        {/* 6 Placeholders */}
        {Array.from({ length: 6 }).map((_, i) => (
          <TouchableOpacity 
            key={i} 
            style={[styles.toolItem, { backgroundColor: theme.surfaceContainerHigh, opacity: 0.6 }]}
            disabled={true}
          >
            <MD3Icon name="plus" size={24} color={theme.outline} />
            <Text style={[styles.toolLabel, { color: theme.outline, fontSize: 10 }]}>Coming Soon</Text>
          </TouchableOpacity>
        ))}
      </View>
    );
  };

  // 3. If a file is selected, show the Editor (Hijack the modal)
  if (selectedFile) {
    return (
      <Modal visible={true} animationType="slide" onRequestClose={() => setSelectedFile(null)}>
        <PdfCropEditor 
          fileUri={selectedFile} 
          theme={theme}
          onClose={() => setSelectedFile(null)}
          onSave={(path) => {
            console.log('Saved to:', path);
            setSelectedFile(null);
            onClose(); // Close sheet after save
          }}
        />
      </Modal>
    );
  }

  // 4. Default Sheet UI
  if (!visible) return null;

  return (
    <View style={styles.overlay}>
      <TouchableOpacity style={styles.backdrop} onPress={onClose} />
      
      <View style={[styles.sheet, { backgroundColor: theme.surfaceContainer }]}>
        <View style={[styles.handle, { backgroundColor: theme.outlineVariant }]} />
        
        <View style={styles.content}>
          <Text style={[styles.title, { color: theme.onSurface }]}>
            {type === 'tools' ? 'PDF Tools' : 'Select Storage'}
          </Text>

          {type === 'tools' ? (
             renderTools()
          ) : (
            <View>
               <Text style={{color: theme.onSurfaceVariant, padding: 20, textAlign: 'center'}}>
                 Storage options would go here...
               </Text>
            </View>
          )}
        </View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  overlay: { position: 'absolute', inset: 0, zIndex: 100, justifyContent: 'flex-end' },
  backdrop: { position: 'absolute', inset: 0, backgroundColor: 'rgba(0,0,0,0.4)' },
  sheet: { borderTopLeftRadius: 28, borderTopRightRadius: 28, paddingBottom: 40, maxHeight: '80%' },
  handle: { width: 32, height: 4, borderRadius: 2, alignSelf: 'center', marginTop: 12, opacity: 0.5 },
  content: { padding: 24 },
  title: { fontSize: 22, fontWeight: '400', marginBottom: 20, textAlign: 'center' },
  
  // Grid Styles
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: 12 },
  toolItem: { 
    width: '30%', // 3 per row roughly
    aspectRatio: 1, 
    borderRadius: 16, 
    alignItems: 'center', 
    justifyContent: 'center',
    marginBottom: 8
  },
  toolLabel: { marginTop: 8, fontSize: 12, fontWeight: '500', textAlign: 'center' }
});

export default Sheets;
