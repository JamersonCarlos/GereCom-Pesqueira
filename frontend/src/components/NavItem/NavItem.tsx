import React from 'react';
import { cn } from '../../lib/utils';

interface NavItemProps {
  icon: React.ReactNode;
  label: string;
  active?: boolean;
  onClick: () => void;
  collapsed?: boolean;
  count?: number;
}

export const NavItem = ({ icon, label, active, onClick, collapsed, count }: NavItemProps) => (
  <button
    onClick={onClick}
    className={cn(
      "w-full flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all duration-200 group relative",
      active 
        ? "bg-secondary text-primary shadow-lg shadow-black/5" 
        : "text-white/60 hover:bg-white/10 hover:text-white"
    )}
  >
    <div className={cn("shrink-0 transition-transform duration-200", active && "scale-110")}>
      {icon}
    </div>
    {!collapsed && (
      <span className="text-sm font-bold tracking-wide flex-1 text-left">{label}</span>
    )}
    {count !== undefined && count > 0 && (
      <span className={cn(
        "absolute right-2 top-2 w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold",
        active ? "bg-primary text-white" : "bg-red-500 text-white"
      )}>
        {count}
      </span>
    )}
    {collapsed && (
      <div className="absolute left-full ml-2 px-2 py-1 bg-secondary text-primary text-xs font-bold rounded opacity-0 group-hover:opacity-100 pointer-events-none transition-opacity whitespace-nowrap z-50 shadow-xl border border-primary/10">
        {label}
      </div>
    )}
  </button>
);
