import React from 'react';
import { cn } from '../../lib/utils';

export const Logo = ({ className = "", variant = "default" }: { className?: string, variant?: 'default' | 'white' }) => (
  <div className={cn("flex items-center font-bold tracking-tighter", className)}>
    <span style={{ color: variant === 'white' ? '#FFFFFF' : '#2E51A4' }}>Gere</span>
    <span style={{ color: '#F1C62F' }}>Com</span>
  </div>
);
