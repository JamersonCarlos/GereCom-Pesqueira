import React from 'react';
import { motion } from 'motion/react';
import { cn } from '../../lib/utils';

interface MobileNavItemProps {
  icon: React.ReactNode;
  active: boolean;
  onClick: () => void;
  count?: number;
}

export const MobileNavItem = ({ icon, active, onClick, count }: MobileNavItemProps) => {
  return (
    <button
      onClick={onClick}
      className={cn(
        "flex flex-col items-center justify-center w-12 h-12 rounded-xl transition-all relative",
        active ? "text-primary bg-primary/10" : "text-primary/60 hover:text-primary"
      )}
    >
      {icon}
      {count !== undefined && count > 0 && (
        <span className="absolute top-2 right-2 w-2 h-2 bg-red-500 rounded-full border-2 border-secondary" />
      )}
      {active && <motion.div layoutId="mobile-nav-indicator" className="absolute -bottom-1 w-1 h-1 bg-primary rounded-full" />}
    </button>
  );
};
