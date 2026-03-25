import React, { useState } from 'react';
import { motion } from 'motion/react';
import { Logo } from '../Logo';
import { AlertCircle } from 'lucide-react';
import { User, UserRole, Invitation } from '../../types';

interface RegisterViewProps {
  role: UserRole;
  onRegister: (u: string, p: string, r: UserRole, m?: string) => void;
  onBack: () => void;
  users: User[];
  invitations: Invitation[];
}

export const RegisterView = ({ role, onRegister, onBack, users, invitations }: RegisterViewProps) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [invitationToken, setInvitationToken] = useState('');
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    if (users.find(u => u.username === username)) {
      setError('Este nome de usuário já está em uso.');
      return;
    }

    if (role === 'MANAGER' || role === 'GENERAL_MANAGER') {
      onRegister(username, password, role);
    } else {
      const invite = invitations.find(i => i.token === invitationToken && i.role === role && i.username === username);
      if (invite) {
        onRegister(username, password, role, invite.managerId);
      } else {
        setError('Convite inválido ou não encontrado para este usuário.');
      }
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col items-center justify-center p-6">
      <motion.div 
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        className="w-full max-w-md bg-white p-8 rounded-[32px] shadow-xl space-y-8"
      >
        <div className="text-center space-y-2">
          <Logo className="text-3xl justify-center mb-4" />
          <h2 className="text-2xl font-bold text-secondary">Criar Conta</h2>
          <p className="text-slate-500">
            Cadastrando como <span className="font-bold text-primary">{
              role === 'MANAGER' ? 'Gerente' : 
              role === 'GENERAL_MANAGER' ? 'Gerente Geral' : 
              role === 'SECRETARY' ? 'Secretário' : 'Funcionário'
            }</span>
          </p>
        </div>

        {error && (
          <div className="p-4 bg-red-50 text-red-600 rounded-2xl text-sm font-medium flex items-center gap-2">
            <AlertCircle size={18} />
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Nome de usuário</label>
            <input 
              type="text" 
              required
              className="w-full p-4 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 transition-all"
              placeholder="Escolha um usuário"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
            />
          </div>
          <div className="space-y-1.5">
            <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Senha</label>
            <input 
              type="password" 
              required
              className="w-full p-4 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 transition-all"
              placeholder="Crie uma senha"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>

          {role !== 'MANAGER' && role !== 'GENERAL_MANAGER' && (
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Token de Convite / QR Code</label>
              <input 
                type="text" 
                required
                className="w-full p-4 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 transition-all"
                placeholder="Insira o código do convite"
                value={invitationToken}
                onChange={(e) => setInvitationToken(e.target.value)}
              />
              <p className="text-[10px] text-slate-400 ml-1 italic">
                * Secretários e Funcionários precisam de um convite do Gerente.
              </p>
            </div>
          )}

          <button 
            type="submit"
            className="w-full py-4 bg-secondary text-primary rounded-2xl font-bold shadow-lg shadow-secondary/20 hover:bg-secondary/90 transition-all"
          >
            Criar Conta
          </button>
        </form>

        <button 
          onClick={onBack}
          className="w-full text-slate-400 text-sm font-medium hover:text-slate-600 transition-colors"
        >
          Voltar
        </button>
      </motion.div>
    </div>
  );
};
