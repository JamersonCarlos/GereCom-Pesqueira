import React, { useState, useMemo } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { 
  Plus, 
  Calendar, 
  Filter, 
  AlertCircle 
} from 'lucide-react';
import { 
  startOfWeek, 
  endOfWeek, 
  isWithinInterval, 
  parseISO 
} from 'date-fns';
import { Planning, User, ServiceStatus } from '../../types';
import { cn } from '../../lib/utils';
import { PlanningCard } from '../PlanningCard';
import { PlanningModal } from '../PlanningModal';

interface PlanningViewProps {
  plannings: Planning[];
  onAdd: (p: any) => void;
  onUpdateStatus: (id: string, status: ServiceStatus, reason?: string) => void;
  user: User;
  onCreateService: (id: string, teamIds: string[]) => void;
  onDelete: (id: string) => void;
  onUpdate: (p: Planning) => void;
  teamMembers: User[];
  users: User[];
}

export const PlanningView = ({ 
  plannings, 
  onAdd, 
  onUpdateStatus,
  user,
  onCreateService,
  onDelete,
  onUpdate,
  teamMembers,
  users
}: PlanningViewProps) => {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingPlanning, setEditingPlanning] = useState<Planning | null>(null);
  const [viewMode, setViewMode] = useState<'WEEK' | 'MONTH'>('MONTH');
  const [filter, setFilter] = useState<ServiceStatus | 'ALL'>('ALL');
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);

  const handleDeleteClick = (id: string) => {
    const planning = plannings.find(p => p.id === id);
    if (planning && (planning.status === 'PENDING' || planning.status === 'IN_PROGRESS')) {
      setDeleteConfirmId(id);
    } else {
      onDelete(id);
    }
  };

  const filteredPlannings = useMemo(() => {
    let list = plannings;
    if (user.role === 'SECRETARY') {
      list = list.filter(p => p.secretaryId === user.id || p.responsibleSecretaryId === user.id);
    }
    
    const now = new Date();
    if (viewMode === 'WEEK') {
      const start = startOfWeek(now, { weekStartsOn: 0 });
      const end = endOfWeek(now, { weekStartsOn: 0 });
      list = list.filter(p => isWithinInterval(parseISO(p.date), { start, end }));
    } else {
      list = list.filter(p => {
        const d = parseISO(p.date);
        return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
      });
    }

    if (filter !== 'ALL') list = list.filter(p => p.status === filter);
    return list;
  }, [plannings, user, filter, viewMode]);

  return (
    <div className="space-y-6 pb-20">
      <div className="flex flex-col gap-4">
        <div className="flex items-center justify-between">
          <h3 className="text-xl font-bold text-secondary">Planejamentos</h3>
          <div className="flex bg-slate-100 p-1 rounded-xl">
            <button 
              onClick={() => setViewMode('WEEK')}
              className={cn(
                "px-4 py-1.5 text-xs font-bold rounded-lg transition-all",
                viewMode === 'WEEK' ? "bg-white text-primary shadow-sm" : "text-slate-500"
              )}
            >
              Semana
            </button>
            <button 
              onClick={() => setViewMode('MONTH')}
              className={cn(
                "px-4 py-1.5 text-xs font-bold rounded-lg transition-all",
                viewMode === 'MONTH' ? "bg-white text-primary shadow-sm" : "text-slate-500"
              )}
            >
              Mês
            </button>
          </div>
        </div>

        <div className="flex items-center gap-2 bg-white border rounded-xl px-3 py-2 shadow-sm">
          <Filter size={16} className="text-slate-400" />
          <select 
            value={filter} 
            onChange={(e) => setFilter(e.target.value as any)}
            className="text-sm font-medium bg-transparent outline-none flex-1"
          >
            <option value="ALL">Todos Status</option>
            <option value="PENDING">Pendentes</option>
            <option value="APPROVED">Aprovados</option>
            <option value="REJECTED">Rejeitados</option>
          </select>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4">
        {filteredPlannings.length > 0 ? (
          filteredPlannings.map((planning) => (
            <PlanningCard 
              key={planning.id} 
              planning={planning} 
              role={user.role} 
              onApprove={() => onCreateService(planning.id, planning.responsibleEmployeeIds || [])}
              onReject={(reason) => onUpdateStatus(planning.id, 'REJECTED', reason)}
              onDelete={() => handleDeleteClick(planning.id)}
              onEdit={() => {
                setEditingPlanning(planning);
                setIsModalOpen(true);
              }}
              users={users}
            />
          ))
        ) : (
          <div className="text-center py-20 bg-white border border-dashed rounded-2xl">
            <Calendar size={48} className="mx-auto text-slate-200 mb-4" />
            <p className="text-slate-500">Nenhum planejamento encontrado para este período.</p>
          </div>
        )}
      </div>

      <AnimatePresence>
        {deleteConfirmId && (
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
              <h3 className="text-xl font-bold text-secondary mb-2">Confirmar Exclusão</h3>
              <p className="text-slate-500 text-sm mb-8">
                Este serviço ainda está pendente ou em andamento. Tem certeza que deseja excluí-lo?
              </p>
              <div className="flex flex-col gap-3">
                <button 
                  onClick={() => {
                    onDelete(deleteConfirmId);
                    setDeleteConfirmId(null);
                  }}
                  className="w-full py-4 bg-red-500 text-white rounded-2xl font-bold hover:bg-red-600 transition-colors shadow-lg shadow-red-200"
                >
                  Excluir serviço
                </button>
                <button 
                  onClick={() => setDeleteConfirmId(null)}
                  className="w-full py-4 bg-slate-100 text-slate-600 rounded-2xl font-bold hover:bg-slate-200 transition-colors"
                >
                  Cancelar
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      {(user.role === 'SECRETARY' || user.role === 'MANAGER') && (
        <button 
          onClick={() => {
            setEditingPlanning(null);
            setIsModalOpen(true);
          }}
          className="fixed bottom-20 right-6 md:bottom-8 md:right-8 w-14 h-14 bg-secondary text-primary rounded-full flex items-center justify-center shadow-2xl shadow-secondary/40 hover:scale-110 transition-transform z-30"
        >
          <Plus size={28} />
        </button>
      )}

      {isModalOpen && (
        <PlanningModal 
          user={user}
          teamMembers={teamMembers}
          planning={editingPlanning}
          onClose={() => {
            setIsModalOpen(false);
            setEditingPlanning(null);
          }} 
          onSubmit={(data) => {
            if (editingPlanning) {
              onUpdate({ ...editingPlanning, ...data });
            } else {
              onAdd({ ...data, secretaryId: user.id, department: user.department || 'Geral' });
            }
            setIsModalOpen(false);
            setEditingPlanning(null);
          }} 
        />
      )}
    </div>
  );
};
