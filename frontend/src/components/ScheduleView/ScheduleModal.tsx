import React, { useState } from 'react';
import { motion } from 'motion/react';
import { X, CheckCircle2, MapPin } from 'lucide-react';
import { Planning, User } from '../../types';
import { cn } from '../../lib/utils';

interface ScheduleModalProps {
  plannings: Planning[];
  team: User[];
  onClose: () => void;
  onSubmit: (pId: string, tIds: string[]) => void;
}

export function ScheduleModal({ plannings, team, onClose, onSubmit }: ScheduleModalProps) {
  const [selectedPlanning, setSelectedPlanning] = useState(plannings[0]?.id || '');
  const [selectedTeam, setSelectedTeam] = useState<string[]>([]);
  const [useGPS, setUseGPS] = useState(false);
  const [location, setLocation] = useState<{lat?: number, lng?: number} | null>(null);

  const toggleMember = (id: string) => {
    setSelectedTeam(prev => prev.includes(id) ? prev.filter(i => i !== id) : [...prev, id]);
  };

  const handleCaptureGPS = () => {
    if ("geolocation" in navigator) {
      navigator.geolocation.getCurrentPosition((position) => {
        setLocation({
          lat: position.coords.latitude,
          lng: position.coords.longitude
        });
        setUseGPS(true);
      });
    } else {
      alert("Geolocalização não disponível");
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <motion.div 
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        className="bg-white rounded-3xl w-full max-w-lg overflow-hidden shadow-2xl"
      >
        <div className="p-6 border-b flex items-center justify-between bg-primary text-white">
          <h3 className="text-xl font-bold text-secondary">Escalar Equipe</h3>
          <button onClick={onClose} className="p-1 hover:bg-white/10 rounded-full transition-colors">
            <X size={24} />
          </button>
        </div>

        <div className="p-8 space-y-6 max-h-[70vh] overflow-y-auto">
          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-400 uppercase tracking-wider">Selecionar Planejamento</label>
            <select 
              className="w-full p-3 bg-slate-50 border rounded-xl outline-none focus:ring-2 focus:ring-primary/20"
              value={selectedPlanning}
              onChange={(e) => setSelectedPlanning(e.target.value)}
            >
              <option value="">Selecione um planejamento pendente</option>
              {plannings.map(p => (
                <option key={p.id} value={p.id}>{p.serviceType} - {p.department} ({p.date})</option>
              ))}
            </select>
          </div>

          <div className="space-y-3">
            <label className="text-xs font-bold text-slate-400 uppercase tracking-wider">Selecionar Equipe</label>
            <div className="grid grid-cols-1 gap-2">
              {team.map(member => (
                <button 
                  key={member.id}
                  onClick={() => toggleMember(member.id)}
                  className={cn(
                    "flex items-center gap-3 p-3 rounded-xl border transition-all text-left",
                    selectedTeam.includes(member.id) ? "bg-primary/5 border-primary ring-1 ring-primary" : "bg-white hover:bg-slate-50"
                  )}
                >
                  <div className={cn(
                    "w-5 h-5 rounded-md border flex items-center justify-center transition-colors",
                    selectedTeam.includes(member.id) ? "bg-primary border-primary text-white" : "bg-white border-slate-300"
                  )}>
                    {selectedTeam.includes(member.id) && <CheckCircle2 size={14} />}
                  </div>
                  <div className="flex-1">
                    <p className="text-sm font-bold text-secondary">{member.name}</p>
                    <p className="text-[10px] text-slate-500 uppercase">{member.role}</p>
                  </div>
                </button>
              ))}
            </div>
          </div>

          <div className="space-y-3">
            <label className="text-xs font-bold text-slate-400 uppercase tracking-wider">Localização (GPS)</label>
            <div className="flex items-center gap-4">
              <button 
                onClick={handleCaptureGPS}
                className={cn(
                  "flex-1 flex items-center justify-center gap-2 py-3 rounded-xl border font-bold text-sm transition-all",
                  useGPS ? "bg-emerald-50 border-emerald-200 text-emerald-600" : "bg-slate-50 border-slate-200 text-slate-600 hover:bg-slate-100"
                )}
              >
                <MapPin size={18} />
                {useGPS ? "Localização Capturada" : "Capturar GPS Atual"}
              </button>
            </div>
          </div>

          <div className="flex gap-3 pt-4">
            <button 
              onClick={onClose}
              className="flex-1 py-4 bg-slate-100 text-slate-600 rounded-2xl font-bold hover:bg-slate-200 transition-all"
            >
              Cancelar
            </button>
            <button 
              onClick={() => onSubmit(selectedPlanning, selectedTeam)}
              disabled={!selectedPlanning || selectedTeam.length === 0}
              className="flex-[2] py-4 bg-secondary text-primary rounded-2xl font-bold shadow-lg shadow-secondary/20 hover:bg-secondary/90 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Confirmar Escala
            </button>
          </div>
        </div>
      </motion.div>
    </div>
  );
}
