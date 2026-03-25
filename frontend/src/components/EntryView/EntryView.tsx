import React from 'react';
import { motion } from 'motion/react';
import { Logo } from '../Logo';
import { ShieldCheck, ArrowRight, FileText, Briefcase, UserCircle } from 'lucide-react';
import { UserRole } from '../../types';

interface EntryViewProps {
  onSelectRole: (role: UserRole) => void;
  onGoToLogin: () => void;
}

export const EntryView = ({ onSelectRole, onGoToLogin }: EntryViewProps) => {
  return (
    <div className="min-h-screen bg-primary flex flex-col items-center justify-center p-6">
      <motion.div 
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="w-full max-w-md space-y-8 text-center"
      >
        <div className="space-y-4">
          <div className="w-32 h-32 flex items-center justify-center mx-auto">
            <Logo className="text-5xl" variant="white" />
          </div>
          <div className="space-y-2">
            <h1 className="text-3xl font-black text-white tracking-tight">Bem-vindo ao GereCom</h1>
            <p className="text-white/70 text-sm">Sua plataforma completa de gestão de comunicação</p>
          </div>
        </div>

        <div className="grid grid-cols-1 gap-3 pt-4">
          <div className="grid grid-cols-2 gap-3">
            <button 
              onClick={() => onSelectRole('MANAGER')}
              className="group p-4 bg-white/5 border border-white/10 hover:bg-white/10 rounded-2xl transition-all text-left"
            >
              <div className="w-8 h-8 bg-secondary text-primary rounded-lg flex items-center justify-center mb-2">
                <ShieldCheck size={16} />
              </div>
              <h3 className="font-bold text-white text-xs">Gerente</h3>
              <p className="text-[9px] text-white/40">Gerenciar equipe</p>
            </button>
            <button 
              onClick={() => onSelectRole('GENERAL_MANAGER')}
              className="group p-4 bg-white/5 border border-white/10 hover:bg-white/10 rounded-2xl transition-all text-left"
            >
              <div className="w-8 h-8 bg-blue-500/20 text-blue-500 rounded-lg flex items-center justify-center mb-2">
                <ShieldCheck size={16} />
              </div>
              <h3 className="font-bold text-white text-xs">Gerente Geral</h3>
              <p className="text-[9px] text-white/40">Visão estratégica</p>
            </button>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <button 
              onClick={() => onSelectRole('SECRETARY')}
              className="group p-4 bg-white/5 border border-white/10 hover:bg-white/10 rounded-2xl transition-all text-left"
            >
              <div className="w-8 h-8 bg-amber-500/20 text-amber-500 rounded-lg flex items-center justify-center mb-2">
                <FileText size={16} />
              </div>
              <h3 className="font-bold text-white text-xs">Secretário</h3>
              <p className="text-[9px] text-white/40">Tenho um convite</p>
            </button>
            <button 
              onClick={() => onSelectRole('EMPLOYEE')}
              className="group p-4 bg-white/5 border border-white/10 hover:bg-white/10 rounded-2xl transition-all text-left"
            >
              <div className="w-8 h-8 bg-emerald-500/20 text-emerald-500 rounded-lg flex items-center justify-center mb-2">
                <Briefcase size={16} />
              </div>
              <h3 className="font-bold text-white text-xs">Funcionário</h3>
              <p className="text-[9px] text-white/40">Tenho um convite</p>
            </button>
          </div>

          <button 
            onClick={onGoToLogin}
            className="group relative flex items-center gap-4 p-5 bg-secondary rounded-2xl transition-all hover:scale-[1.02] active:scale-[0.98] shadow-xl shadow-secondary/20 text-left mt-2"
          >
            <div className="w-12 h-12 bg-primary text-white rounded-xl flex items-center justify-center">
              <UserCircle size={24} />
            </div>
            <div>
              <h3 className="font-bold text-primary">Já tenho conta</h3>
              <p className="text-primary/60 text-xs">Acessar o sistema com seus dados</p>
            </div>
            <ArrowRight className="ml-auto text-primary/40 group-hover:text-primary transition-colors" size={20} />
          </button>
        </div>
      </motion.div>
    </div>
  );
};
