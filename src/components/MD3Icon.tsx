import React from 'react';
import { Text, View } from 'react-native';

interface IconProps {
  name: string;
  size?: number;
  color?: string;
}

const MD3Icon: React.FC<IconProps> = ({ name, size = 24, color = '#000' }) => {
  // Mapping names to simple Unicode characters so we don't need an external library
  let symbol = '•';
  
  switch (name) {
    case 'view-dashboard':
    case 'view-dashboard-outline':
      symbol = '⊞'; 
      break;
    case 'cog':
    case 'cog-outline':
      symbol = '⚙'; 
      break;
    case 'plus':
      symbol = '+'; 
      break;
    case 'account':
      symbol = '👤'; 
      break;
    case 'wallet':
      symbol = '💳'; 
      break;
    case 'file-pdf-box':
      symbol = '📄'; 
      break;
    case 'calculator':
      symbol = '🧮'; 
      break;
    case 'chart-box':
      symbol = '📊'; 
      break;
    case 'currency-usd':
      symbol = '$'; 
      break;
    case 'check':
      symbol = '✓'; 
      break;
    case 'tools':
      symbol = '🛠';
      break;
    default:
      symbol = '•';
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
