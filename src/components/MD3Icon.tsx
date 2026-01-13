import React from 'react';
import { Text, View } from 'react-native';

interface IconProps {
  name: string;
  size?: number;
  color?: string;
}

const MD3Icon: React.FC<IconProps> = ({ name, size = 24, color = '#000' }) => {
  let symbol = '•';
  
  switch (name) {
    case 'view-dashboard':
    case 'view-dashboard-outline': symbol = '⊞'; break;
    case 'cog':
    case 'cog-outline': symbol = '⚙'; break;
    case 'plus': symbol = '+'; break;
    case 'account': symbol = '👤'; break;
    case 'wallet': symbol = '💳'; break;
    case 'file-pdf-box':
    case 'file-document': symbol = '📄'; break;
    case 'file-document-outline': symbol = '📝'; break;
    case 'calculator': symbol = '🧮'; break;
    case 'chart-box': symbol = '📊'; break;
    case 'currency-usd': symbol = '$'; break;
    case 'check': symbol = '✓'; break;
    case 'tools':
    case 'wrench': symbol = '🛠'; break;
    case 'camera':
    case 'image': symbol = '📷'; break;
    case 'video': symbol = '🎥'; break;
    case 'dots-vertical': symbol = '⋮'; break;
    case 'history': symbol = '↺'; break;
    // New icons for PDF Tool
    case 'crop': symbol = '✂'; break; 
    case 'close': symbol = '✕'; break;
    default: symbol = '•';
  }

  return (
    <View style={{ width: size, height: size, alignItems: 'center', justifyContent: 'center' }}>
      <Text style={{ fontSize: size * 0.8, color: color, fontWeight: 'bold' }}>
        {symbol}
      </Text>
    </View>
  );
};

export default MD3Icon;
