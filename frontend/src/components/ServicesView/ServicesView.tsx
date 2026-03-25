import React, { useState, useMemo } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { 
  Filter, 
  Briefcase, 
  Calendar, 
  MapPin, 
  UserCircle, 
  Users, 
  CheckCircle2, 
  AlertCircle, 
  X 
} from 'lucide-react';
import { 
  format, 
  parseISO, 
  isSameWeek, 
  isSameMonth, 
  isSameYear, 
  isWithinInterval, 
  startOfDay, 
  endOfDay 
} from 'date-fns';
import { Service, Planning, User, ServiceStatus, UserRole } from '../../types';
import { cn } from '../../lib/utils';

interface ServiceCardProps {
  service: Service;
  planning?: Planning;
  role: UserRole;
  onUpdateStatus: (status: ServiceStatus, reason?: string) => void;
  onConfirmStatus?: (id: string) => void;
  onReviewStatus?: (id: string) => void;
  users: User[];
}

const ServiceCard: React.FC<ServiceCardProps> = ({ service, planning, role, onUpdateStatus, onConfirmStatus, onReviewStatus, users }) => {
  const [showReasonModal, setShowReasonModal] = useState<{ status: ServiceStatus, show: boolean }>({ status: 'PENDING', show: false });
  const [reason, setReason] = useState('');

  const teamNames = service.teamIds.map(id => users.find(u => u.id === id)?.name).join(', ');
  const secretaryId = planning?.secretaryId || service.secretaryIdSnapshot;
  const secretary = users.find(u => u.id === secretaryId);

  const serviceType = planning?.serviceType || service.serviceTypeSnapshot;
  const description = planning?.description || service.descriptionSnapshot;
  const observations = planning?.observations || service.observationsSnapshot;
  const date = planning?.date || service.dateSnapshot;
  const time = planning?.time || service.timeSnapshot;
  const address = planning?.location.address || service.locationSnapshot?.address;

  const handleUpdateClick = (status: ServiceStatus) => {
    if (status === 'CANCELLED' || status === 'RESCHEDULED') {
      setShowReasonModal({ status, show: true });
    } else if (status === 'COMPLETED') {
      onUpdateStatus('WAITING_APPROVAL');
    } else {
      onUpdateStatus(status);
    }
  };

  const handleReasonSubmit = () => {
    if (reason.trim()) {
      onUpdateStatus(showReasonModal.status, reason);
      setShowReasonModal({ ...showReasonModal, show: false });
      setReason('');
    }
  };

  const openMaps = () => {
    const url = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(address || '')}`;
    window.open(url, '_blank');
  };

  return (
    <div className="glass-card rounded-2xl p-6 shadow-sm relative bg-white border">
      <div className="flex flex-col md:flex-row justify-between gap-6">
        <div className="space-y-4 flex-1">
          <div className="flex items-center gap-3">
            <span className={cn(
              "px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider",
              service.status === 'COMPLETED' ? "bg-emerald-100 text-emerald-700" : 
              service.status === 'CANCELLED' ? "bg-red-100 text-red-700" :
              service.status === 'RESCHEDULED' ? "bg-amber-100 text-amber-700" :
              service.status === 'WAITING_APPROVAL' ? "bg-blue-100 text-blue-700" :
              "bg-slate-100 text-slate-700"
            )}>
              {service.status === 'COMPLETED' ? 'Concluído' : 
               service.status === 'CANCELLED' ? 'Cancelado' :
               service.status === 'RESCHEDULED' ? 'Reagendado' :
               service.status === 'WAITING_APPROVAL' ? 'Aguardando Aprovação' :
               'Em Andamento'}
            </span>
            <span className="text-xs text-slate-400 font-medium">Atualizado em {format(parseISO(service.updatedAt), "dd/MM HH:mm")}</span>
            {service.managerConfirmed && (
              <span className="flex items-center gap-1 text-[10px] font-bold text-emerald-600 uppercase bg-emerald-50 px-2 py-0.5 rounded-full">
                <CheckCircle2 size={10} />
                Confirmado
              </span>
            )}
          </div>

          <div>
            <h4 className="text-lg font-bold text-secondary">{serviceType}</h4>
            <p className="text-sm text-slate-500 mt-1">{description}</p>
            {observations && (
              <p className="text-xs text-slate-400 mt-2 italic">Obs: {observations}</p>
            )}
            {service.reason && (
              <div className="mt-3 p-3 bg-slate-50 rounded-xl border border-slate-100">
                <p className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-1">Motivo do {service.status === 'CANCELLED' ? 'Cancelamento' : 'Reagendamento'}:</p>
                <p className="text-sm text-slate-600">{service.reason}</p>
              </div>
            )}
          </div>

          <div className="flex flex-wrap gap-4 pt-2">
            <div className="flex items-center gap-2 text-xs text-slate-500 bg-slate-50 px-3 py-1.5 rounded-lg">
              <Calendar size={14} className="text-primary" />
              <span>{date} às {time}</span>
            </div>
            <button 
              onClick={openMaps}
              className="flex items-center gap-2 text-xs text-slate-500 bg-slate-50 px-3 py-1.5 rounded-lg hover:bg-primary/5 hover:text-primary transition-colors group"
            >
              <MapPin size={14} className="text-primary group-hover:scale-110 transition-transform" />
              <span>{address}</span>
            </button>
            <div className="flex items-center gap-2 text-xs text-slate-500 bg-slate-50 px-3 py-1.5 rounded-lg">
              <UserCircle size={14} className="text-primary" />
              <span>Solicitante: {secretary?.name || 'N/A'}</span>
            </div>
            <div className="flex items-center gap-2 text-xs text-slate-500 bg-slate-50 px-3 py-1.5 rounded-lg">
              <Users size={14} className="text-primary" />
              <span>Responsável: {teamNames}</span>
            </div>
          </div>
        </div>

        <div className="flex flex-col justify-center gap-2 min-w-[180px]">
          {role === 'EMPLOYEE' && service.status === 'IN_PROGRESS' && (
            <>
              <button 
                onClick={() => handleUpdateClick('COMPLETED')}
                className="w-full py-2.5 bg-emerald-500 text-white rounded-xl text-sm font-bold hover:bg-emerald-600 transition-colors shadow-lg shadow-emerald-200"
              >
                Concluir Serviço
              </button>
              <div className="grid grid-cols-2 gap-2">
                <button 
                  onClick={() => handleUpdateClick('CANCELLED')}
                  className="py-2 bg-white border border-slate-200 text-slate-600 rounded-xl text-xs font-bold hover:bg-slate-50 transition-colors"
                >
                  Cancelar
                </button>
                <button 
                  onClick={() => handleUpdateClick('RESCHEDULED')}
                  className="py-2 bg-white border border-slate-200 text-slate-600 rounded-xl text-xs font-bold hover:bg-slate-50 transition-colors"
                >
                  Reagendar
                </button>
              </div>
            </>
          )}

          {role === 'MANAGER' && service.status !== 'COMPLETED' && service.status !== 'CANCELLED' && (
            <div className="space-y-2">
              <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider text-center">Controle do Gerente</p>
              {service.status === 'WAITING_APPROVAL' ? (
                <>
                  <button 
                    onClick={() => onConfirmStatus?.(service.id)}
                    className="w-full py-2.5 bg-emerald-500 text-white rounded-xl text-sm font-bold hover:bg-emerald-600 transition-colors shadow-lg shadow-emerald-200 flex items-center justify-center gap-2"
                  >
                    <CheckCircle2 size={18} />
                    Confirmar Conclusão
                  </button>
                  <button 
                    onClick={() => onReviewStatus?.(service.id)}
                    className="w-full py-2.5 bg-amber-500 text-white rounded-xl text-sm font-bold hover:bg-amber-600 transition-colors shadow-lg shadow-amber-200 flex items-center justify-center gap-2"
                  >
                    <AlertCircle size={18} />
                    Solicitar Revisão
                  </button>
                </>
              ) : (
                <>
                  <button 
                    onClick={() => handleUpdateClick('COMPLETED')}
                    className="w-full py-2 bg-emerald-50 text-emerald-600 rounded-xl text-xs font-bold hover:bg-emerald-100 transition-colors"
                  >
                    Marcar como Concluído
                  </button>
                  <div className="grid grid-cols-2 gap-2">
                    <button 
                      onClick={() => handleUpdateClick('CANCELLED')}
                      className="py-2 bg-red-50 text-red-600 rounded-xl text-xs font-bold hover:bg-red-100 transition-colors"
                    >
                      Cancelar
                    </button>
                    <button 
                      onClick={() => handleUpdateClick('RESCHEDULED')}
                      className="py-2 bg-amber-50 text-amber-600 rounded-xl text-xs font-bold hover:bg-amber-100 transition-colors"
                    >
                      Reagendar
                    </button>
                  </div>
                </>
              )}
            </div>
          )}

          {role === 'MANAGER' && (service.status === 'CANCELLED' || service.status === 'RESCHEDULED') && !service.managerConfirmed && (
            <button 
              onClick={() => onConfirmStatus?.(service.id)}
              className="w-full py-2.5 bg-primary text-white rounded-xl text-sm font-bold hover:bg-primary/90 transition-colors shadow-lg shadow-primary/20 flex items-center justify-center gap-2"
            >
              <CheckCircle2 size={18} />
              Ciente
            </button>
          )}
          
          {service.status === 'COMPLETED' && service.managerConfirmed && (
            <div className="flex flex-col items-center text-emerald-600 gap-1">
              <CheckCircle2 size={32} />
              <span className="text-xs font-bold uppercase tracking-wider">Finalizado & Confirmado</span>
            </div>
          )}
        </div>
      </div>

      <AnimatePresence>
        {showReasonModal.show && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm">
            <motion.div 
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="w-full max-w-md bg-white rounded-[32px] p-8 shadow-2xl space-y-6"
            >
              <div className="flex items-center justify-between">
                <h3 className="text-xl font-bold text-secondary">
                  {showReasonModal.status === 'CANCELLED' ? 'Motivo do Cancelamento' : 'Motivo do Reagendamento'}
                </h3>
                <button onClick={() => setShowReasonModal({ ...showReasonModal, show: false })} className="p-2 hover:bg-slate-100 rounded-full transition-colors">
                  <X size={20} className="text-slate-400" />
                </button>
              </div>

              <div className="space-y-2">
                <label className="text-xs font-bold text-slate-400 uppercase tracking-wider">Descrição do Motivo</label>
                <textarea 
                  className="w-full p-4 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 min-h-[120px] resize-none"
                  placeholder="Explique o motivo..."
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                />
              </div>

              <div className="flex gap-3">
                <button 
                  onClick={() => setShowReasonModal({ ...showReasonModal, show: false })}
                  className="flex-1 py-4 bg-slate-100 text-slate-600 rounded-2xl font-bold hover:bg-slate-200 transition-all"
                >
                  Voltar
                </button>
                <button 
                  onClick={handleReasonSubmit}
                  disabled={!reason.trim()}
                  className="flex-1 py-4 bg-primary text-white rounded-2xl font-bold hover:bg-primary/90 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Confirmar
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
};

interface ServicesViewProps {
  services: Service[];
  plannings: Planning[];
  onUpdateStatus: (id: string, status: ServiceStatus, reason?: string) => void;
  onConfirmStatus: (id: string) => void;
  onReviewStatus: (id: string) => void;
  user: User;
  users: User[];
}

export const ServicesView = ({ 
  services, 
  plannings, 
  onUpdateStatus, 
  onConfirmStatus, 
  onReviewStatus, 
  user, 
  users 
}: ServicesViewProps) => {
  const [periodFilter, setPeriodFilter] = useState<'WEEK' | 'MONTH' | 'YEAR' | 'CUSTOM'>('MONTH');
  const [statusFilter, setStatusFilter] = useState<'ALL' | 'PENDING' | 'COMPLETED' | 'CANCELLED' | 'RESCHEDULED'>('ALL');
  const [customRange, setCustomRange] = useState({ start: '', end: '' });
  const [showCustomRange, setShowCustomRange] = useState(false);

  const filteredServices = useMemo(() => {
    let list = services;
    
    // Role based filtering
    if (user.role === 'EMPLOYEE') {
      list = list.filter(s => s.teamIds.includes(user.id));
    } else if (user.role === 'SECRETARY') {
      list = list.filter(s => {
        const p = plannings.find(pl => pl.id === s.planningId);
        return p && (p.secretaryId === user.id || p.responsibleSecretaryId === user.id);
      });
    }

    // Period filtering
    const now = new Date();
    list = list.filter(s => {
      const date = parseISO(s.updatedAt);
      if (periodFilter === 'WEEK') return isSameWeek(date, now);
      if (periodFilter === 'MONTH') return isSameMonth(date, now);
      if (periodFilter === 'YEAR') return isSameYear(date, now);
      if (periodFilter === 'CUSTOM') {
        if (!customRange.start || !customRange.end) return true;
        return isWithinInterval(date, { 
          start: startOfDay(parseISO(customRange.start)), 
          end: endOfDay(parseISO(customRange.end)) 
        });
      }
      return true;
    });

    // Status filtering
    if (statusFilter !== 'ALL') {
      if (statusFilter === 'PENDING') {
        list = list.filter(s => s.status === 'IN_PROGRESS' || s.status === 'WAITING_APPROVAL');
      } else {
        list = list.filter(s => s.status === statusFilter);
      }
    }

    return list;
  }, [services, user, plannings, periodFilter, statusFilter, customRange]);

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex bg-slate-100 p-1 rounded-xl">
            {(['WEEK', 'MONTH', 'YEAR', 'CUSTOM'] as const).map((f) => (
              <button
                key={f}
                onClick={() => {
                  setPeriodFilter(f);
                  setShowCustomRange(f === 'CUSTOM');
                }}
                className={cn(
                  "px-4 py-1.5 text-xs font-bold rounded-lg transition-all",
                  periodFilter === f ? "bg-white text-primary shadow-sm" : "text-slate-500"
                )}
              >
                {f === 'WEEK' ? 'Semana' : f === 'MONTH' ? 'Mês' : f === 'YEAR' ? 'Ano' : 'Personalizado'}
              </button>
            ))}
          </div>

          <div className="flex items-center gap-2 bg-white border rounded-xl px-3 py-2 shadow-sm">
            <Filter size={16} className="text-slate-400" />
            <select 
              value={statusFilter} 
              onChange={(e) => setStatusFilter(e.target.value as any)}
              className="text-sm font-medium bg-transparent outline-none flex-1"
            >
              <option value="ALL">Todos Status</option>
              <option value="PENDING">Pendentes</option>
              <option value="COMPLETED">Concluídos</option>
              <option value="CANCELLED">Cancelados</option>
              <option value="RESCHEDULED">Reagendados</option>
            </select>
          </div>
        </div>

        {showCustomRange && (
          <motion.div 
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            className="bg-white p-4 rounded-2xl border shadow-sm flex flex-col md:flex-row items-end gap-4"
          >
            <div className="flex-1 space-y-1.5">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Data Inicial</label>
              <input 
                type="date" 
                className="w-full p-2.5 bg-slate-50 border rounded-xl outline-none focus:ring-2 focus:ring-primary/20 text-sm"
                value={customRange.start}
                onChange={(e) => setCustomRange({ ...customRange, start: e.target.value })}
              />
            </div>
            <div className="flex-1 space-y-1.5">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Data Final</label>
              <input 
                type="date" 
                className="w-full p-2.5 bg-slate-50 border rounded-xl outline-none focus:ring-2 focus:ring-primary/20 text-sm"
                value={customRange.end}
                onChange={(e) => setCustomRange({ ...customRange, end: e.target.value })}
              />
            </div>
            <button 
              onClick={() => setShowCustomRange(false)}
              className="px-6 py-2.5 bg-primary text-white rounded-xl font-bold hover:bg-primary/90 transition-all text-sm"
            >
              Aplicar
            </button>
          </motion.div>
        )}
      </div>

      <div className="grid grid-cols-1 gap-4">
        {filteredServices.length > 0 ? (
          filteredServices.map((service) => {
            const planning = plannings.find(p => p.id === service.planningId);
            return (
              <ServiceCard 
                key={service.id} 
                service={service} 
                planning={planning} 
                role={user.role}
                onUpdateStatus={(status: ServiceStatus, reason?: string) => onUpdateStatus(service.id, status, reason)}
                onConfirmStatus={onConfirmStatus}
                onReviewStatus={onReviewStatus}
                users={users}
              />
            );
          })
        ) : (
          <div className="text-center py-20 glass-card rounded-3xl bg-white border border-dashed">
            <Briefcase size={48} className="mx-auto text-slate-200 mb-4" />
            <p className="text-slate-500">Nenhum serviço em execução.</p>
          </div>
        )}
      </div>
    </div>
  );
};
