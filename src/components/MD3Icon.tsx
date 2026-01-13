import React from 'react';
import { Text } from 'react-native';

type Props = { symbol: string; size?: number; color: string };

export const MD3Icon = ({ symbol, size = 24, color }: Props) => (
  <Text style={{ fontSize: size, color: color, textAlign: 'center', lineHeight: size }}>
    {symbol}
  </Text>
);
