import React from 'react';
// Check which library you have installed. Usually it's this:
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';

interface IconProps {
  name: string;
  size?: number;
  color?: string;
}

const MD3Icon: React.FC<IconProps> = ({ name, size = 24, color = '#000' }) => {
  return <Icon name={name} size={size} color={color} />;
};

export default MD3Icon;
