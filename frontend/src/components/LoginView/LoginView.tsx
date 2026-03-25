import React, { useState } from 'react';
import { motion } from 'motion/react';
import { Logo } from '../Logo';
import { AlertCircle } from 'lucide-react';

interface LoginViewProps {
  onLogin: (u: string, p: string) => boolean;
  onBack: () => void;
}

export const LoginView = ({ onLogin, onBack }: LoginViewProps) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (onLogin(username, password)) {
      // Success
    } else {
      setError(true);
    }
  };

  if (error) {
    return (
      <div className="min-h-screen bg-slate-50 flex flex-col items-center justify-center p-6">
        <div className="w-full max-w-md bg-white p-8 rounded-[32px] shadow-xl text-center space-y-6">
          <div className="w-20 h-20 bg-red-100 text-red-600 rounded-full flex items-center justify-center mx-auto">
            <AlertCircle size={40} />
          </div>
          <div className="space-y-2">
            <h3 className="text-2xl font-bold text-secondary">Usuário não cadastrado</h3>
            <p className="text-slate-500">Verifique suas credenciais ou crie uma nova conta.</p>
          </div>
          <div className="flex flex-col gap-3">
            <button 
              onClick={() => setError(false)}
              className="w-full py-4 bg-primary text-white rounded-2xl font-bold shadow-lg shadow-primary/20"
            >
              Tentar novamente
            </button>
            <button 
              onClick={onBack}
              className="w-full py-4 bg-slate-100 text-slate-600 rounded-2xl font-bold"
            >
              Voltar para a página de acesso
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col items-center justify-center p-6">
      <motion.div 
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        className="w-full max-w-md bg-white p-8 rounded-[32px] shadow-xl space-y-8"
      >
        <div className="text-center space-y-2">
          <Logo className="text-3xl justify-center mb-4" />
          <h2 className="text-2xl font-bold text-secondary">Login</h2>
          <p className="text-slate-500">Acesse sua conta para continuar</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-1.5">
            <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Nome de usuário</label>
            <input 
              type="text" 
              required
              className="w-full p-4 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 transition-all"
              placeholder="Digite seu usuário"
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
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>
          <button 
            type="submit"
            className="w-full py-4 bg-secondary text-primary rounded-2xl font-bold shadow-lg shadow-secondary/20 hover:bg-secondary/90 transition-all"
          >
            Entrar
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
