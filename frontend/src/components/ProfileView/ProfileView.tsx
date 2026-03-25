import React from 'react';
import { 
  User as UserIcon, 
  Settings, 
  LogOut, 
  ChevronRight 
} from 'lucide-react';
import { User } from '../../types';

interface ProfileViewProps {
  user: User;
  onLogout: () => void;
}

export function ProfileView({ user, onLogout }: ProfileViewProps) {
  return (
    <div className="max-w-2xl mx-auto space-y-8">
      <div className="bg-white/80 backdrop-blur-sm p-8 rounded-[32px] border shadow-sm text-center">
        <div className="w-24 h-24 rounded-full bg-primary/10 text-primary flex items-center justify-center font-bold text-3xl border-2 border-primary/20 mx-auto mb-6">
          <UserIcon size={48} />
        </div>
        <h3 className="text-2xl font-bold text-primary mb-1">{user.name}</h3>
        <p className="text-slate-500 font-medium mb-6">{user.email}</p>
        
        <div className="grid grid-cols-2 gap-4 text-left max-w-md mx-auto">
          <div className="p-4 bg-slate-50 rounded-2xl">
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">Nível de Acesso</p>
            <p className="font-bold text-primary">{user.role}</p>
          </div>
          <div className="p-4 bg-slate-50 rounded-2xl">
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">Departamento</p>
            <p className="font-bold text-primary">{user.department || 'N/A'}</p>
          </div>
        </div>
      </div>

      <div className="bg-white/80 backdrop-blur-sm p-6 rounded-[32px] border shadow-sm">
        <h4 className="text-sm font-bold text-secondary uppercase tracking-wider mb-6 flex items-center gap-2">
          <Settings size={18} className="text-primary" />
          Configurações da Conta
        </h4>
        
        <div className="space-y-4">
          <button 
            onClick={onLogout}
            className="w-full flex items-center justify-between p-4 bg-red-50 text-red-600 rounded-2xl font-bold hover:bg-red-100 transition-all"
          >
            <div className="flex items-center gap-3">
              <LogOut size={20} />
              <span>Sair da Conta</span>
            </div>
            <ChevronRight size={20} />
          </button>
        </div>
      </div>
    </div>
  );
}
