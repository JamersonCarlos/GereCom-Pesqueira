import React, { useState } from 'react';
import { motion } from 'motion/react';
import { 
  Calendar, 
  MapPin, 
  UserCircle, 
  User as UserIcon, 
  Settings, 
  X, 
  CheckCircle2, 
  XCircle, 
  AlertCircle 
} from 'lucide-react';
import { format, parseISO } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import { Planning, User, UserRole } from '../../types';
import { cn } from '../../lib/utils';

interface PlanningCardProps {
  planning: Planning;
  role: UserRole;
  onApprove: () => void;
  onReject: (reason: string) => void;
  onDelete: () => void;
  onEdit: () => void;
  users: User[];
}

export const PlanningCard: React.FC<PlanningCardProps> = ({ planning, role, onApprove, onReject, onDelete, onEdit, users }) => {
  const [showRejectInput, setShowRejectInput] = useState(false);
  const [reason, setReason] = useState('');
  const secretary = users.find(u => u.id === planning.secretaryId);

  const statusColors = {
    PENDING: 'bg-amber-100 text-amber-700',
    APPROVED: 'bg-emerald-100 text-emerald-700',
    REJECTED: 'bg-red-100 text-red-700',
    IN_PROGRESS: 'bg-blue-100 text-blue-700',
    COMPLETED: 'bg-emerald-100 text-emerald-700',
    CANCELLED: 'bg-slate-100 text-slate-700',
    RESCHEDULED: 'bg-purple-100 text-purple-700',
  };

  const urgencyColors = {
    LOW: 'bg-slate-100 text-slate-600',
    MEDIUM: 'bg-blue-100 text-blue-600',
    HIGH: 'bg-orange-100 text-orange-600',
    URGENT: 'bg-red-100 text-red-600',
  };

  return (
    <motion.div 
      layout
      className="glass-card rounded-2xl p-5 shadow-sm hover:shadow-md transition-shadow relative overflow-hidden"
    >
      <div className="flex flex-col gap-4">
        <div className="flex items-start justify-between">
          <div className="flex flex-wrap gap-2">
            <span className={cn("px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider", statusColors[planning.status])}>
              {planning.status === 'PENDING' ? 'Pendente' : 
               planning.status === 'APPROVED' ? 'Aprovado' :
               planning.status === 'REJECTED' ? 'Rejeitado' :
               planning.status === 'IN_PROGRESS' ? 'Em Andamento' :
               planning.status === 'COMPLETED' ? 'Concluído' :
               planning.status === 'CANCELLED' ? 'Cancelado' :
               planning.status === 'RESCHEDULED' ? 'Reagendado' :
               planning.status}
            </span>
            <span className={cn("px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider", urgencyColors[planning.urgency])}>
              {planning.urgency === 'LOW' ? 'Baixa' :
               planning.urgency === 'MEDIUM' ? 'Média' :
               planning.urgency === 'HIGH' ? 'Alta' :
               planning.urgency === 'URGENT' ? 'Urgente' :
               planning.urgency}
            </span>
          </div>
          
          {role === 'MANAGER' && (
            <div className="flex gap-1">
              <button onClick={onEdit} className="p-2 text-primary hover:text-primary hover:bg-slate-100 rounded-lg transition-colors">
                <Settings size={16} />
              </button>
              <button onClick={onDelete} className="p-2 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors">
                <X size={16} />
              </button>
            </div>
          )}
        </div>
        
        <div className="space-y-1">
          <h4 className="text-lg font-bold text-secondary leading-tight">{planning.serviceType}</h4>
          <p className="text-xs text-slate-400 font-bold uppercase tracking-widest">{planning.department}</p>
        </div>

        <p className="text-slate-600 text-sm line-clamp-2">{planning.description}</p>
        
        <div className="grid grid-cols-1 gap-2 pt-2 border-t border-slate-50">
          <div className="flex items-center gap-2 text-sm text-slate-500">
            <Calendar size={14} className="text-primary" />
            <span>{format(parseISO(planning.date), "dd/MM/yyyy", { locale: ptBR })} às {planning.time}</span>
          </div>
          <div className="flex items-center gap-2 text-sm text-slate-500">
            <MapPin size={14} className="text-primary" />
            <span className="truncate">{planning.location.address}</span>
          </div>
          <div className="flex items-center gap-2 text-sm text-slate-500">
            <UserCircle size={14} className="text-primary" />
            <span className="truncate">Solicitante: {secretary?.name || 'N/A'}</span>
          </div>
          {planning.responsibleEmployeeIds && planning.responsibleEmployeeIds.length > 0 && (
            <div className="flex flex-col gap-1 mt-1">
              <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Responsáveis:</p>
              <div className="flex flex-wrap gap-2">
                {planning.responsibleEmployeeIds.map(id => {
                  const emp = users.find(u => u.id === id);
                  return (
                    <div key={id} className="flex items-center gap-1.5 bg-slate-50 px-2 py-1 rounded-lg border border-slate-100">
                      <UserIcon size={10} className="text-primary" />
                      <span className="text-[10px] font-bold text-slate-700">{emp?.name}</span>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>

        {role === 'MANAGER' && planning.status === 'PENDING' && !showRejectInput && (
          <div className="flex gap-2 pt-2">
            <button 
              onClick={onApprove}
              className="flex-1 py-2.5 bg-emerald-500 text-white rounded-xl text-sm font-bold hover:bg-emerald-600 transition-colors flex items-center justify-center gap-2 shadow-lg shadow-emerald-500/20"
            >
              <CheckCircle2 size={16} /> Aprovar
            </button>
            <button 
              onClick={() => setShowRejectInput(true)}
              className="flex-1 py-2.5 bg-white border border-red-200 text-red-500 rounded-xl text-sm font-bold hover:bg-red-50 transition-colors flex items-center justify-center gap-2"
            >
              <XCircle size={16} /> Rejeitar
            </button>
          </div>
        )}

        {showRejectInput && (
          <div className="space-y-2 pt-2">
            <textarea 
              placeholder="Motivo da rejeição..."
              className="w-full p-3 text-sm border rounded-xl outline-none focus:ring-2 focus:ring-red-500/20"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
            />
            <div className="flex gap-2">
              <button 
                onClick={() => onReject(reason)}
                className="flex-1 py-2 bg-red-500 text-white rounded-xl text-sm font-bold"
              >
                Confirmar
              </button>
              <button 
                onClick={() => setShowRejectInput(false)}
                className="flex-1 py-2 bg-slate-100 text-slate-600 rounded-xl text-sm font-bold"
              >
                Cancelar
              </button>
            </div>
          </div>
        )}

        {planning.status === 'REJECTED' && planning.rejectionReason && (
          <div className="mt-2 p-3 bg-red-50 border border-red-100 rounded-xl flex gap-3 items-start">
            <AlertCircle size={14} className="text-red-500 mt-0.5 shrink-0" />
            <p className="text-xs text-red-600"><span className="font-bold uppercase">Rejeitado:</span> {planning.rejectionReason}</p>
          </div>
        )}
      </div>
    </motion.div>
  );
};
