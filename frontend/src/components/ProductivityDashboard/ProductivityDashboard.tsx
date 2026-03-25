import React, { useState, useMemo } from 'react';
import { motion } from 'motion/react';
import { 
  startOfWeek, 
  endOfWeek, 
  startOfMonth, 
  endOfMonth, 
  startOfYear, 
  endOfYear, 
  parseISO, 
  isWithinInterval 
} from 'date-fns';
import { Service, User } from '../../types';
import { cn } from '../../lib/utils';

interface ProductivityDashboardProps {
  services: Service[];
  users: User[];
  teamMembers: User[];
}

export const ProductivityDashboard = ({ services, users, teamMembers }: ProductivityDashboardProps) => {
  const [filter, setFilter] = useState<'WEEK' | 'MONTH' | 'YEAR' | 'CUSTOM'>('MONTH');
  const [dateRange, setDateRange] = useState({ start: '', end: '' });

  const filteredServices = useMemo(() => {
    const now = new Date();
    let start: Date, end: Date;

    if (filter === 'WEEK') {
      start = startOfWeek(now, { weekStartsOn: 0 });
      end = endOfWeek(now, { weekStartsOn: 0 });
    } else if (filter === 'MONTH') {
      start = startOfMonth(now);
      end = endOfMonth(now);
    } else if (filter === 'YEAR') {
      start = startOfYear(now);
      end = endOfYear(now);
    } else {
      if (!dateRange.start || !dateRange.end) return services;
      start = parseISO(dateRange.start);
      end = parseISO(dateRange.end);
    }

    return services.filter(s => {
      const date = parseISO(s.updatedAt);
      return isWithinInterval(date, { start, end });
    });
  }, [services, filter, dateRange]);

  const ranking = useMemo(() => {
    const employees = teamMembers.filter(u => u.role === 'EMPLOYEE');
    const data = employees.map(emp => {
      const empServices = filteredServices.filter(s => s.teamIds.includes(emp.id));
      const completed = empServices.filter(s => s.status === 'COMPLETED' && s.managerConfirmed).length;
      const cancelled = empServices.filter(s => s.status === 'CANCELLED').length;
      const rescheduled = empServices.filter(s => s.status === 'RESCHEDULED').length;
      const points = completed; // +1 point for each completed and approved service, no penalties

      return {
        id: emp.id,
        name: emp.name,
        completed,
        cancelled,
        rescheduled,
        points
      };
    });

    return data.sort((a, b) => b.points - a.points);
  }, [filteredServices, teamMembers]);

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <h3 className="text-xl font-bold text-secondary">Painel de Produtividade</h3>
        <div className="flex flex-wrap gap-2">
          {(['WEEK', 'MONTH', 'YEAR', 'CUSTOM'] as const).map(f => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={cn(
                "px-4 py-2 rounded-xl text-xs font-bold transition-all",
                filter === f ? "bg-primary text-white shadow-lg shadow-primary/20" : "bg-white text-slate-500 border border-slate-200 hover:bg-slate-50"
              )}
            >
              {f === 'WEEK' ? 'Semanal' : f === 'MONTH' ? 'Mensal' : f === 'YEAR' ? 'Anual' : 'Escolher Período'}
            </button>
          ))}
        </div>
      </div>

      {filter === 'CUSTOM' && (
        <div className="flex gap-4 p-4 glass-card rounded-2xl animate-in fade-in slide-in-from-top-2">
          <div className="flex-1">
            <label className="text-[10px] font-bold text-slate-400 uppercase mb-1 block">Início</label>
            <input type="date" className="w-full p-2 bg-slate-50 border rounded-lg text-sm" value={dateRange.start} onChange={e => setDateRange({...dateRange, start: e.target.value})} />
          </div>
          <div className="flex-1">
            <label className="text-[10px] font-bold text-slate-400 uppercase mb-1 block">Fim</label>
            <input type="date" className="w-full p-2 bg-slate-50 border rounded-lg text-sm" value={dateRange.end} onChange={e => setDateRange({...dateRange, end: e.target.value})} />
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 gap-4">
        {ranking.map((emp, i) => (
          <div key={emp.id} className="glass-card p-6 rounded-2xl flex flex-col md:flex-row md:items-center justify-between gap-6">
            <div className="flex items-center gap-4">
              <div className={cn(
                "w-10 h-10 rounded-full flex items-center justify-center font-bold text-white",
                i === 0 ? "bg-yellow-500" : i === 1 ? "bg-slate-400" : i === 2 ? "bg-amber-600" : "bg-slate-200 text-slate-500"
              )}>
                {i + 1}
              </div>
              <div>
                <h4 className="font-bold text-secondary">{emp.name}</h4>
                <p className="text-xs text-slate-500">Pontuação Total: <span className="font-bold text-primary">{emp.points} pts</span></p>
              </div>
            </div>

            <div className="grid grid-cols-3 gap-8 text-center">
              <div>
                <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-1">Concluídos</p>
                <p className="text-lg font-bold text-emerald-600">{emp.completed}</p>
              </div>
              <div>
                <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-1">Cancelados</p>
                <p className="text-lg font-bold text-red-600">{emp.cancelled}</p>
              </div>
              <div>
                <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-1">Reagendados</p>
                <p className="text-lg font-bold text-amber-600">{emp.rescheduled}</p>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};
