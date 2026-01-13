import React, { useState, useRef } from 'react';
import { View, Text, StyleSheet, Dimensions, TouchableOpacity, PanResponder, Alert } from 'react-native';
import Pdf from 'react-native-pdf';
import { PDFDocument } from 'pdf-lib';
import RNFS from 'react-native-fs';
import MD3Icon from './MD3Icon';

const SCREEN_WIDTH = Dimensions.get('window').width;

interface Props {
  fileUri: string;
  onClose: () => void;
  onSave: (newPath: string) => void;
  theme: any;
}

const PdfCropEditor: React.FC<Props> = ({ fileUri, onClose, onSave, theme }) => {
  const [pdfSize, setPdfSize] = useState({ width: 0, height: 0, pageCount: 0 });
  
  // Crop Box State (Visual coordinates in pixels relative to screen)
  const [box, setBox] = useState({ x: 50, y: 100, w: 200, h: 200 });

  // 1. Touch Handlers for Draggable/Resizable Box
  const panResponder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onPanResponderMove: (_, gestureState) => {
        setBox(prev => ({
          ...prev,
          x: Math.max(0, prev.x + gestureState.dx), // Simple move logic (could be improved to resize)
          y: Math.max(0, prev.y + gestureState.dy),
        }));
      },
      onPanResponderRelease: () => {
        // Snap to bounds if needed
      }
    })
  ).current;

  // 2. The Vector Crop Logic
  const handleCrop = async () => {
    try {
      // Load the PDF
      const existingPdfBytes = await RNFS.readFile(fileUri, 'base64');
      const pdfDoc = await PDFDocument.load(existingPdfBytes);
      const pages = pdfDoc.getPages();
      const firstPage = pages[0]; // Currently cropping only page 1 for MVP

      // Get PDF Dimensions
      const { width, height } = firstPage.getSize();

      // 3. Map Screen Coordinates to PDF Coordinates (Vector math)
      // Screen PDF View is likely scaled to fit width.
      const scaleFactor = width / SCREEN_WIDTH; 
      
      // PDF Coordinate System (Bottom-Left is 0,0) vs Screen (Top-Left is 0,0)
      // We must invert Y.
      const cropX = box.x * scaleFactor;
      const cropW = box.w * scaleFactor;
      const cropH = box.h * scaleFactor;
      const cropY = height - ((box.y * scaleFactor) + cropH);

      // Set the "MediaBox" and "CropBox" (This is non-destructive vector cropping)
      firstPage.setCropBox(cropX, cropY, cropW, cropH);
      firstPage.setMediaBox(cropX, cropY, cropW, cropH);

      // Save
      const base64Uri = await pdfDoc.saveAsBase64();
      const newPath = `${RNFS.DocumentDirectoryPath}/cropped_${Date.now()}.pdf`;
      await RNFS.writeFile(newPath, base64Uri, 'base64');

      Alert.alert('Success', 'Vector crop complete!', [
        { text: 'OK', onPress: () => onSave(newPath) }
      ]);

    } catch (error) {
      console.error(error);
      Alert.alert('Error', 'Failed to crop PDF');
    }
  };

  return (
    <View style={[styles.container, { backgroundColor: '#000' }]}>
      {/* Header */}
      <View style={[styles.header, { backgroundColor: theme.surface }]}>
        <TouchableOpacity onPress={onClose}>
          <MD3Icon name="close" size={24} color={theme.onSurface} />
        </TouchableOpacity>
        <Text style={{ color: theme.onSurface, fontWeight: 'bold' }}>Crop PDF (Vector)</Text>
        <TouchableOpacity onPress={handleCrop}>
          <MD3Icon name="check" size={24} color={theme.primary} />
        </TouchableOpacity>
      </View>

      {/* PDF View - Locked (No scroll) so we can draw over it */}
      <View style={styles.editorArea}>
        <Pdf
          source={{ uri: fileUri, cache: true }}
          style={styles.pdf}
          fitPolicy={0} // Fit Width
          singlePage={true} // Focus on one page for cropping
          onLoadComplete={(numberOfPages, filePath, { width, height }) => {
            setPdfSize({ width, height, pageCount: numberOfPages });
          }}
        />

        {/* The Crop Box Overlay */}
        <View
          style={[
            styles.cropBox,
            { left: box.x, top: box.y, width: box.w, height: box.h, borderColor: theme.primary }
          ]}
          {...panResponder.panHandlers}
        >
          {/* Visual Handles */}
          <View style={[styles.handle, { backgroundColor: theme.primary, top: -5, left: -5 }]} />
          <View style={[styles.handle, { backgroundColor: theme.primary, bottom: -5, right: -5 }]} />
          
          <View style={{ backgroundColor: 'rgba(255,255,255,0.3)', flex: 1 }}>
            <Text style={{ color: theme.primary, fontWeight: 'bold', textAlign: 'center', marginTop: 10 }}>
              Drag to Move
            </Text>
          </View>
        </View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: { height: 60, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 16 },
  editorArea: { flex: 1, position: 'relative' },
  pdf: { flex: 1, width: Dimensions.get('window').width, backgroundColor: '#333' },
  cropBox: { position: 'absolute', borderWidth: 2, zIndex: 10 },
  handle: { width: 10, height: 10, position: 'absolute' }
});

export default PdfCropEditor;
