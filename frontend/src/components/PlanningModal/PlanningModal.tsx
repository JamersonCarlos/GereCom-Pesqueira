import React, { useState } from 'react';
import { motion } from 'motion/react';
import { X, MapPin } from 'lucide-react';
import { format } from 'date-fns';
import { User, Planning, UrgencyLevel, PlanningPeriod } from '../../types';
import { SERVICE_TYPES } from '../../constants';
import { cn } from '../../lib/utils';

interface PlanningModalProps {
  onClose: () => void;
  onSubmit: (data: any) => void;
  planning?: Planning | null;
  user: User;
  teamMembers: User[];
}

export const PlanningModal = ({ onClose, onSubmit, planning, user, teamMembers }: PlanningModalProps) => {
  const [formData, setFormData] = useState({
    serviceType: planning?.serviceType || SERVICE_TYPES[0],
    date: planning?.date || format(new Date(), 'yyyy-MM-dd'),
    time: planning?.time || '09:00',
    location: planning?.location || { address: '' },
    description: planning?.description || '',
    observations: planning?.observations || '',
    urgency: planning?.urgency || 'MEDIUM' as UrgencyLevel,
    period: planning?.period || 'WEEKLY' as PlanningPeriod,
    responsibleEmployeeIds: planning?.responsibleEmployeeIds || [],
    responsibleSecretaryId: planning?.responsibleSecretaryId || '',
  });

  const [isCapturingLocation, setIsCapturingLocation] = useState(false);

  const captureLocation = () => {
    setIsCapturingLocation(true);
    if ("geolocation" in navigator) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          setFormData(prev => ({
            ...prev,
            location: {
              ...prev.location,
              lat: position.coords.latitude,
              lng: position.coords.longitude,
              address: prev.location.address || `Coordenadas: ${position.coords.latitude.toFixed(4)}, ${position.coords.longitude.toFixed(4)}`
            }
          }));
          setIsCapturingLocation(false);
        },
        (error) => {
          console.error("Erro ao capturar localização:", error);
          setIsCapturingLocation(false);
          alert("Não foi possível capturar sua localização. Verifique as permissões do navegador.");
        }
      );
    } else {
      setIsCapturingLocation(false);
      alert("Geolocalização não é suportada pelo seu navegador.");
    }
  };

  const employees = teamMembers.filter(m => (m.role === 'EMPLOYEE' || m.role === 'MANAGER') && m.status === 'ACTIVE');
  const secretaries = teamMembers.filter(m => m.role === 'SECRETARY' && m.status === 'ACTIVE');

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-end md:items-center justify-center">
      <motion.div 
        initial={{ y: "100%" }}
        animate={{ y: 0 }}
        className="bg-white rounded-t-[32px] md:rounded-[32px] w-full max-w-2xl overflow-hidden shadow-2xl max-h-[90vh] flex flex-col"
      >
        <div className="p-6 border-b flex items-center justify-between bg-primary text-white shrink-0">
          <h3 className="text-xl font-bold text-secondary">{planning ? 'Editar Planejamento' : 'Novo Planejamento'}</h3>
          <button onClick={onClose} className="p-2 hover:bg-white/10 rounded-full transition-colors">
            <X size={24} />
          </button>
        </div>

        <div className="p-6 overflow-y-auto space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Tipo de Serviço</label>
              <select 
                className="w-full p-3.5 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 text-sm"
                value={formData.serviceType}
                onChange={(e) => setFormData({ ...formData, serviceType: e.target.value })}
              >
                {SERVICE_TYPES.map(t => <option key={t} value={t}>{t}</option>)}
              </select>
            </div>
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Urgência</label>
              <select 
                className="w-full p-3.5 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 text-sm"
                value={formData.urgency}
                onChange={(e) => setFormData({ ...formData, urgency: e.target.value as any })}
              >
                <option value="LOW">Baixa</option>
                <option value="MEDIUM">Média</option>
                <option value="HIGH">Alta</option>
                <option value="URGENT">Urgente</option>
              </select>
            </div>
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Data</label>
              <input 
                type="date" 
                className="w-full p-3.5 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 text-sm"
                value={formData.date}
                onChange={(e) => setFormData({ ...formData, date: e.target.value })}
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Hora</label>
              <input 
                type="time" 
                className="w-full p-3.5 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 text-sm"
                value={formData.time}
                onChange={(e) => setFormData({ ...formData, time: e.target.value })}
              />
            </div>
          </div>

          <div className="space-y-1.5">
            <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Local</label>
            <div className="flex gap-2">
              <div className="relative flex-1">
                <MapPin size={18} className="absolute left-3.5 top-3.5 text-slate-400" />
                <input 
                  type="text" 
                  placeholder="Endereço ou local"
                  className="w-full pl-11 pr-4 py-3.5 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 text-sm"
                  value={formData.location.address}
                  onChange={(e) => setFormData({ ...formData, location: { ...formData.location, address: e.target.value } })}
                />
              </div>
              <button 
                type="button"
                onClick={captureLocation}
                disabled={isCapturingLocation}
                className={cn(
                  "p-3.5 rounded-2xl border transition-all flex items-center justify-center",
                  isCapturingLocation ? "bg-slate-100 text-slate-400" : "bg-white text-primary hover:bg-primary/5 border-primary/20"
                )}
                title="Capturar GPS"
              >
                {isCapturingLocation ? (
                  <div className="w-5 h-5 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
                ) : (
                  <MapPin size={20} />
                )}
              </button>
            </div>
          </div>

          {user.role === 'MANAGER' && (
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Secretário Responsável</label>
              <select 
                className="w-full p-3.5 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 text-sm"
                value={formData.responsibleSecretaryId}
                onChange={(e) => setFormData({ ...formData, responsibleSecretaryId: e.target.value })}
              >
                <option value="">Selecione um secretário...</option>
                {secretaries.map(sec => (
                  <option key={sec.id} value={sec.id}>{sec.name}</option>
                ))}
              </select>
            </div>
          )}

          {user.role === 'MANAGER' && (
            <div className="space-y-1.5">
              <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Funcionário Responsável</label>
              <select 
                className="w-full p-3.5 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 text-sm"
                value={formData.responsibleEmployeeIds[0] || ''}
                onChange={(e) => setFormData({ ...formData, responsibleEmployeeIds: e.target.value ? [e.target.value] : [] })}
              >
                <option value="">Selecione um funcionário...</option>
                {employees.map(emp => (
                  <option key={emp.id} value={emp.id}>{emp.name} ({emp.function})</option>
                ))}
              </select>
            </div>
          )}

          <div className="space-y-1.5">
            <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Descrição</label>
            <textarea 
              className="w-full p-4 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 text-sm min-h-[100px]"
              placeholder="Descreva os detalhes do serviço..."
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Observações Internas</label>
            <textarea 
              className="w-full p-4 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 text-sm min-h-[80px]"
              placeholder="Notas adicionais para a equipe..."
              value={formData.observations}
              onChange={(e) => setFormData({ ...formData, observations: e.target.value })}
            />
          </div>
        </div>

        <div className="p-6 border-t bg-slate-50 shrink-0">
          <button 
            onClick={() => onSubmit(formData)}
            className="w-full py-4 bg-secondary text-primary rounded-2xl font-bold shadow-lg shadow-secondary/20 hover:bg-secondary/90 transition-all"
          >
            {planning ? 'Salvar Alterações' : 'Criar Planejamento'}
          </button>
        </div>
      </motion.div>
    </div>
  );
};
