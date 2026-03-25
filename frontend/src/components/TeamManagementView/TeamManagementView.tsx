import React, { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { 
  Plus, 
  Users, 
  Clock, 
  User as UserIcon, 
  X, 
  QrCode, 
  AlertCircle 
} from 'lucide-react';
import { User, UserRole, Invitation } from '../../types';
import { cn } from '../../lib/utils';

interface InvitationModalProps {
  onClose: () => void;
  onSubmit: (i: any) => void;
}

const InvitationModal = ({ onClose, onSubmit }: InvitationModalProps) => {
  const [formData, setFormData] = useState({
    username: '',
    role: 'EMPLOYEE' as UserRole,
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const token = Math.random().toString(36).substring(2, 8).toUpperCase();
    onSubmit({
      ...formData,
      token,
      managerId: 'current-manager-id',
    });
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <motion.div 
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        className="bg-white rounded-3xl w-full max-w-md overflow-hidden shadow-2xl"
      >
        <div className="p-6 border-b flex items-center justify-between bg-secondary text-primary">
          <h3 className="text-xl font-bold">Gerar Novo Convite</h3>
          <button onClick={onClose} className="p-1 hover:bg-black/10 rounded-full transition-colors">
            <X size={24} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-8 space-y-6">
          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-400 uppercase tracking-wider">Nome de Usuário para o Membro</label>
            <input 
              type="text" 
              required
              className="w-full p-4 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20"
              value={formData.username}
              onChange={(e) => setFormData({ ...formData, username: e.target.value })}
              placeholder="Ex: joao.silva"
            />
            <p className="text-[10px] text-slate-400 italic">O membro deverá usar este nome de usuário ao se cadastrar.</p>
          </div>

          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-400 uppercase tracking-wider">Nível de Acesso</label>
            <select 
              className="w-full p-4 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20"
              value={formData.role}
              onChange={(e) => setFormData({ ...formData, role: e.target.value as any })}
            >
              <option value="SECRETARY">Secretário</option>
              <option value="EMPLOYEE">Funcionário</option>
              <option value="GESTOR">Gestor</option>
            </select>
          </div>

          <div className="pt-4 flex gap-4">
            <button 
              type="button"
              onClick={onClose}
              className="flex-1 py-4 border border-slate-200 text-slate-600 rounded-2xl font-bold hover:bg-slate-50 transition-colors"
            >
              Cancelar
            </button>
            <button 
              type="submit"
              className="flex-1 py-4 bg-secondary text-primary rounded-2xl font-bold hover:bg-secondary/90 transition-all shadow-lg shadow-secondary/20"
            >
              Gerar Convite
            </button>
          </div>
        </form>
      </motion.div>
    </div>
  );
};

interface TeamMemberModalProps {
  user: User | null;
  onClose: () => void;
  onSubmit: (data: any) => void;
}

const TeamMemberModal = ({ user, onClose, onSubmit }: TeamMemberModalProps) => {
  const [formData, setFormData] = useState({
    name: user?.name || '',
    username: user?.username || '',
    password: user?.password || '',
    role: user?.role || 'EMPLOYEE' as UserRole,
    function: user?.function || '',
    email: user?.email || '',
    phone: user?.phone || '',
    department: user?.department || '',
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <motion.div 
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        className="bg-white rounded-3xl w-full max-w-lg overflow-hidden shadow-2xl"
      >
        <div className="p-6 border-b flex items-center justify-between bg-primary text-white">
          <h3 className="text-xl font-bold">{user ? 'Editar Membro' : 'Cadastrar Membro'}</h3>
          <button onClick={onClose} className="p-1 hover:bg-white/10 rounded-full transition-colors">
            <X size={24} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-8 space-y-4 max-h-[70vh] overflow-y-auto">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Nome Completo</label>
              <input 
                type="text" 
                required
                className="w-full p-3.5 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 text-sm"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Usuário</label>
              <input 
                type="text" 
                required
                className="w-full p-3.5 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 text-sm"
                value={formData.username}
                onChange={(e) => setFormData({ ...formData, username: e.target.value })}
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Senha</label>
              <input 
                type="password" 
                required={!user}
                className="w-full p-3.5 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 text-sm"
                value={formData.password}
                onChange={(e) => setFormData({ ...formData, password: e.target.value })}
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Nível de Acesso</label>
              <select 
                className="w-full p-3.5 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 text-sm"
                value={formData.role}
                onChange={(e) => setFormData({ ...formData, role: e.target.value as any })}
              >
                <option value="SECRETARY">Secretário</option>
                <option value="EMPLOYEE">Funcionário</option>
                <option value="GESTOR">Gestor</option>
                <option value="MANAGER">Gerente</option>
              </select>
            </div>
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Função / Cargo</label>
              <input 
                type="text" 
                className="w-full p-3.5 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 text-sm"
                value={formData.function}
                onChange={(e) => setFormData({ ...formData, function: e.target.value })}
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Departamento</label>
              <input 
                type="text" 
                className="w-full p-3.5 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 text-sm"
                value={formData.department}
                onChange={(e) => setFormData({ ...formData, department: e.target.value })}
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">E-mail</label>
              <input 
                type="email" 
                className="w-full p-3.5 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 text-sm"
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Telefone</label>
              <input 
                type="tel" 
                className="w-full p-3.5 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 text-sm"
                value={formData.phone}
                onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
              />
            </div>
          </div>

          <div className="pt-6 flex gap-4">
            <button 
              type="button"
              onClick={onClose}
              className="flex-1 py-4 border border-slate-200 text-slate-600 rounded-2xl font-bold hover:bg-slate-50 transition-colors"
            >
              Cancelar
            </button>
            <button 
              type="submit"
              className="flex-1 py-4 bg-primary text-white rounded-2xl font-bold hover:bg-primary/90 transition-all shadow-lg shadow-primary/20"
            >
              {user ? 'Salvar Alterações' : 'Cadastrar Membro'}
            </button>
          </div>
        </form>
      </motion.div>
    </div>
  );
};

interface TeamManagementViewProps {
  team: User[];
  onUpdate: (user: User) => void;
  onAdd: (user: Omit<User, 'id' | 'createdAt' | 'managerId'>) => void;
  onDelete: (id: string) => void;
  role: UserRole;
  invitations: Invitation[];
  onAddInvitation: (i: Omit<Invitation, 'id' | 'createdAt' | 'managerId'>) => void;
  onRemoveInvitation: (token: string) => void;
  allUsers: User[];
  currentUser: User;
}

export const TeamManagementView = ({ 
  team, 
  onUpdate, 
  onAdd, 
  onDelete, 
  role, 
  invitations, 
  onAddInvitation, 
  onRemoveInvitation,
  allUsers,
  currentUser
}: TeamManagementViewProps) => {
  const [activeView, setActiveView] = useState<'TEAM' | 'INVITATIONS'>('TEAM');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isInviteModalOpen, setIsInviteModalOpen] = useState(false);
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);

  const handleSave = (userData: Partial<User>) => {
    if (editingUser) {
      onUpdate({ ...editingUser, ...userData } as User);
    } else {
      onAdd(userData as any);
    }
    setIsModalOpen(false);
    setEditingUser(null);
  };

  const toggleStatus = (id: string) => {
    const user = team.find(u => u.id === id);
    if (user) {
      onUpdate({ ...user, status: user.status === 'ACTIVE' ? 'INACTIVE' : 'ACTIVE' });
    }
  };

  return (
    <div className="space-y-6 pb-24">
      <AnimatePresence>
        {confirmDeleteId && (
          <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-[100] flex items-center justify-center p-4">
            <motion.div 
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.9, opacity: 0 }}
              className="bg-white rounded-[32px] p-8 max-w-sm w-full shadow-2xl text-center"
            >
              <div className="w-20 h-20 bg-red-50 text-red-500 rounded-full flex items-center justify-center mx-auto mb-6">
                <AlertCircle size={40} />
              </div>
              <h3 className="text-xl font-bold text-secondary mb-2">Remover Membro?</h3>
              <p className="text-slate-500 text-sm mb-8">
                Tem certeza que deseja remover este usuário da equipe? Esta ação não pode ser desfeita.
              </p>
              <div className="flex flex-col gap-3">
                <button 
                  onClick={() => {
                    onDelete(confirmDeleteId);
                    setConfirmDeleteId(null);
                  }}
                  className="w-full py-4 bg-red-500 text-white rounded-2xl font-bold hover:bg-red-600 transition-colors shadow-lg shadow-red-200"
                >
                  Confirmar exclusão
                </button>
                <button 
                  onClick={() => setConfirmDeleteId(null)}
                  className="w-full py-4 bg-slate-100 text-slate-600 rounded-2xl font-bold hover:bg-slate-200 transition-colors"
                >
                  Cancelar
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
      <div className="flex flex-col gap-4">
        <div className="flex items-center justify-between">
          <h3 className="text-xl font-bold text-secondary">Equipe & Convites</h3>
          {role === 'MANAGER' && (
            <div className="flex gap-2">
              <button 
                onClick={() => setIsInviteModalOpen(true)}
                className="flex items-center gap-2 bg-secondary text-primary px-4 py-2 rounded-xl font-bold hover:bg-secondary/90 transition-colors shadow-lg shadow-secondary/20"
              >
                <QrCode size={20} />
                <span className="hidden sm:inline">Gerar Convite</span>
              </button>
              <button 
                onClick={() => { setEditingUser(null); setIsModalOpen(true); }}
                className="flex items-center gap-2 bg-secondary text-primary px-4 py-2 rounded-xl font-bold hover:bg-secondary/90 transition-colors shadow-lg shadow-secondary/20"
              >
                <Plus size={20} />
                <span className="hidden sm:inline">Cadastrar Membro</span>
              </button>
            </div>
          )}
        </div>

        {role === 'MANAGER' && (
          <div className="flex bg-slate-100 p-1 rounded-xl w-fit">
            <button 
              onClick={() => setActiveView('TEAM')}
              className={cn(
                "px-6 py-2 text-xs font-bold rounded-lg transition-all flex items-center gap-2",
                activeView === 'TEAM' ? "bg-white text-primary shadow-sm" : "text-slate-500"
              )}
            >
              <Users size={16} />
              Equipe Ativa
            </button>
            <button 
              onClick={() => setActiveView('INVITATIONS')}
              className={cn(
                "px-6 py-2 text-xs font-bold rounded-lg transition-all flex items-center gap-2",
                activeView === 'INVITATIONS' ? "bg-white text-primary shadow-sm" : "text-slate-500"
              )}
            >
              <Clock size={16} />
              Convites Pendentes
              {invitations.length > 0 && (
                <span className="bg-primary text-white text-[10px] w-4 h-4 rounded-full flex items-center justify-center">
                  {invitations.length}
                </span>
              )}
            </button>
          </div>
        )}
      </div>

      {activeView === 'TEAM' ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {team.map((member) => (
            <motion.div 
              layout
              key={member.id}
              className="glass-card rounded-2xl p-6 shadow-sm hover:shadow-md transition-shadow relative overflow-hidden bg-white border"
            >
              <div className={cn(
                "absolute top-0 right-0 w-2 h-full",
                member.status === 'ACTIVE' ? "bg-emerald-500" : "bg-slate-300"
              )} />
              
              <div className="flex items-start gap-4">
                <div className="w-12 h-12 rounded-full bg-slate-100 flex items-center justify-center text-primary font-bold text-lg">
                  <UserIcon size={24} />
                </div>
                <div className="flex-1 min-w-0">
                  <h4 className="font-bold text-secondary truncate">{member.name}</h4>
                  <p className="text-xs text-slate-500 font-medium uppercase tracking-wider">{member.function || member.role}</p>
                  <p className="text-[10px] text-slate-400 font-mono mt-1">@{member.username}</p>
                  
                  <div className="mt-4 space-y-2">
                    {member.email && (
                      <p className="text-xs text-slate-600 flex items-center gap-2">
                        <span className="w-1 h-1 rounded-full bg-slate-400" />
                        {member.email}
                      </p>
                    )}
                    {member.phone && (
                      <p className="text-xs text-slate-600 flex items-center gap-2">
                        <span className="w-1 h-1 rounded-full bg-slate-400" />
                        {member.phone}
                      </p>
                    )}
                  </div>
                </div>
              </div>

              {role === 'MANAGER' && (
                <div className="mt-6 flex gap-2">
                  <button 
                    onClick={() => { setEditingUser(member); setIsModalOpen(true); }}
                    className="flex-1 py-2 bg-slate-50 text-slate-600 rounded-lg text-xs font-bold hover:bg-slate-100 transition-colors"
                  >
                    Editar
                  </button>
                  <button 
                    onClick={() => toggleStatus(member.id)}
                    className={cn(
                      "flex-1 py-2 rounded-lg text-xs font-bold transition-colors",
                      member.status === 'ACTIVE' 
                        ? "bg-red-50 text-red-600 hover:bg-red-100" 
                        : "bg-emerald-50 text-emerald-600 hover:bg-emerald-100"
                    )}
                  >
                    {member.status === 'ACTIVE' ? 'Desativar' : 'Ativar'}
                  </button>
                  {(member.role === 'EMPLOYEE' || member.role === 'SECRETARY') && (
                    <button 
                      onClick={() => setConfirmDeleteId(member.id)}
                      className="p-2 bg-red-50 text-red-600 rounded-lg hover:bg-red-100 transition-colors"
                      title="Excluir membro"
                    >
                      <X size={16} />
                    </button>
                  )}
                </div>
              )}
            </motion.div>
          ))}
        </div>
      ) : (
        <div className="space-y-4">
          {invitations.length > 0 ? (
            invitations.map((invite) => (
              <div key={invite.token} className="glass-card rounded-2xl p-6 flex flex-col sm:flex-row sm:items-center justify-between gap-4 shadow-sm bg-white border">
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 bg-amber-50 text-amber-600 rounded-full flex items-center justify-center">
                    <QrCode size={24} />
                  </div>
                  <div>
                    <h4 className="font-bold text-secondary">Convite para @{invite.username}</h4>
                    <p className="text-xs text-slate-500">Nível: <span className="font-bold text-primary">{invite.role}</span></p>
                    <p className="text-[10px] text-slate-400 mt-1 font-mono">Token: {invite.token}</p>
                  </div>
                </div>
                <div className="flex gap-2">
                  <button 
                    onClick={() => onRemoveInvitation(invite.token)}
                    className="flex-1 sm:flex-none px-6 py-2 bg-red-50 text-red-600 rounded-xl text-xs font-bold hover:bg-red-100 transition-colors"
                  >
                    Cancelar Convite
                  </button>
                  <button 
                    onClick={() => {
                      const link = `${window.location.origin}?token=${invite.token}&user=${invite.username}&role=${invite.role}`;
                      navigator.clipboard.writeText(link);
                      alert('Link de convite copiado para a área de transferência!');
                    }}
                    className="flex-1 sm:flex-none px-6 py-2 bg-primary/10 text-primary rounded-xl text-xs font-bold hover:bg-primary/20 transition-colors"
                  >
                    Copiar Link
                  </button>
                </div>
              </div>
            ))
          ) : (
            <div className="text-center py-20 bg-white border border-dashed rounded-2xl">
              <Clock size={48} className="mx-auto text-slate-200 mb-4" />
              <p className="text-slate-500">Nenhum convite pendente.</p>
            </div>
          )}
        </div>
      )}

      {isModalOpen && (
        <TeamMemberModal 
          user={editingUser}
          onClose={() => { setIsModalOpen(false); setEditingUser(null); }}
          onSubmit={handleSave}
        />
      )}

      {isInviteModalOpen && (
        <InvitationModal 
          onClose={() => setIsInviteModalOpen(false)}
          onSubmit={(invite) => {
            onAddInvitation(invite);
            setIsInviteModalOpen(false);
          }}
        />
      )}
    </div>
  );
};
