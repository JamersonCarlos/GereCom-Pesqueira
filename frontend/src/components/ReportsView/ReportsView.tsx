import React, { useState, useMemo } from 'react';
import { motion } from 'motion/react';
import { 
  FileText, 
  Download, 
  Users, 
  User as UserIcon, 
  UserCircle
} from 'lucide-react';
import { 
  format, 
  startOfWeek, 
  endOfWeek, 
  startOfMonth, 
  endOfMonth, 
  startOfYear, 
  endOfYear, 
  isWithinInterval, 
  parseISO 
} from 'date-fns';
import { jsPDF } from 'jspdf';
import autoTable from 'jspdf-autotable';
import { Planning, Service, User } from '../../types';
import { cn } from '../../lib/utils';

interface ReportsViewProps {
  plannings: Planning[];
  services: Service[];
  users: User[];
  linkedManagers?: User[];
  currentUser: User;
}

export function ReportsView({ plannings, services, users, linkedManagers = [], currentUser }: ReportsViewProps) {
  const [filterType, setFilterType] = useState<'WEEKLY' | 'MONTHLY' | 'ANNUAL' | 'CUSTOM'>('MONTHLY');
  const [customRange, setCustomRange] = useState({ start: '', end: '' });
  const [showCustomRange, setShowCustomRange] = useState(false);
  const [selectedManagerId, setSelectedManagerId] = useState<string>('ALL');

  const filteredServices = useMemo(() => {
    const now = new Date();
    let interval: { start: Date, end: Date };

    switch (filterType) {
      case 'WEEKLY':
        interval = { start: startOfWeek(now, { weekStartsOn: 0 }), end: endOfWeek(now, { weekStartsOn: 0 }) };
        break;
      case 'MONTHLY':
        interval = { start: startOfMonth(now), end: endOfMonth(now) };
        break;
      case 'ANNUAL':
        interval = { start: startOfYear(now), end: endOfYear(now) };
        break;
      case 'CUSTOM':
        if (!customRange.start || !customRange.end) return services;
        interval = { start: parseISO(customRange.start), end: parseISO(customRange.end) };
        break;
      default:
        return services;
    }

    return services.filter(s => {
      const p = plannings.find(pl => pl.id === s.planningId);
      const dateStr = p?.date || s.dateSnapshot;
      if (!dateStr) return false;
      
      try {
        const date = parseISO(dateStr);
        return isWithinInterval(date, interval);
      } catch (e) {
        return false;
      }
    });
  }, [services, plannings, filterType, customRange]);

  const productivityData = useMemo(() => {
    const employeeStats: { [key: string]: { performed: number, completed: number, cancelled: number, rescheduled: number } } = {};
    const secretaryStats: { [key: string]: { requested: number, managed: number, completed: number } } = {};

    filteredServices.forEach(s => {
      const p = plannings.find(pl => pl.id === s.planningId);
      
      // Employee stats
      s.teamIds.forEach(tid => {
        if (!employeeStats[tid]) {
          employeeStats[tid] = { performed: 0, completed: 0, cancelled: 0, rescheduled: 0 };
        }
        employeeStats[tid].performed += 1;
        if (s.status === 'COMPLETED' && s.managerConfirmed) employeeStats[tid].completed += 1;
        if (s.status === 'CANCELLED') employeeStats[tid].cancelled += 1;
        if (s.status === 'RESCHEDULED') employeeStats[tid].rescheduled += 1;
      });

      // Secretary stats
      const secretaryId = p?.secretaryId || s.secretaryIdSnapshot;
      const responsibleSecId = p?.responsibleSecretaryId || s.responsibleSecretaryIdSnapshot;
      
      if (secretaryId) {
        if (!secretaryStats[secretaryId]) {
          secretaryStats[secretaryId] = { requested: 0, managed: 0, completed: 0 };
        }
        secretaryStats[secretaryId].requested += 1;
        if (s.status === 'COMPLETED' && s.managerConfirmed) secretaryStats[secretaryId].completed += 1;
      }

      if (responsibleSecId) {
        if (!secretaryStats[responsibleSecId]) {
          secretaryStats[responsibleSecId] = { requested: 0, managed: 0, completed: 0 };
        }
        secretaryStats[responsibleSecId].managed += 1;
        if (s.status === 'COMPLETED' && s.managerConfirmed) secretaryStats[responsibleSecId].completed += 1;
      }
    });

    return { employeeStats, secretaryStats };
  }, [filteredServices, plannings]);

  const generatePDF = () => {
    const doc = new jsPDF();
    doc.setFontSize(20);
    doc.text('Relatório de Serviços - GereCom', 14, 22);
    doc.setFontSize(11);
    doc.setTextColor(100);
    doc.text(`Gerado em: ${format(new Date(), 'dd/MM/yyyy HH:mm')}`, 14, 30);
    const getFilterLabel = (type: string) => {
      switch (type) {
        case 'WEEKLY': return 'Semanal';
        case 'MONTHLY': return 'Mensal';
        case 'ANNUAL': return 'Anual';
        case 'CUSTOM': return 'Personalizado';
        default: return type;
      }
    };

    doc.text(`Período: ${filterType === 'CUSTOM' ? `${customRange.start} até ${customRange.end}` : getFilterLabel(filterType)}`, 14, 36);

    const tableData = filteredServices.map(s => {
      const p = plannings.find(pl => pl.id === s.planningId);
      const secretaryId = p?.secretaryId || s.secretaryIdSnapshot;
      const responsibleSecId = p?.responsibleSecretaryId || s.responsibleSecretaryIdSnapshot;
      const secretary = users.find(u => u.id === secretaryId);
      const responsibleSec = users.find(u => u.id === responsibleSecId);
      const teamNames = s.teamIds.map(tid => users.find(u => u.id === tid)?.name).join(', ');
      
      const description = p?.description || s.descriptionSnapshot || '-';
      const reason = s.reason || '-';
      
      return [
        p?.serviceType || s.serviceTypeSnapshot || '-',
        s.status === 'COMPLETED' ? 'Concluído' : 
        s.status === 'CANCELLED' ? 'Cancelado' :
        s.status === 'RESCHEDULED' ? 'Reagendado' : 'Pendente',
        responsibleSec?.name || secretary?.name || '-',
        teamNames || '-',
        p?.date || s.dateSnapshot || '-',
        p?.time || s.timeSnapshot || '-',
        p?.location.address || s.locationSnapshot?.address || '-',
        description,
        reason
      ];
    });

    autoTable(doc, {
      startY: 45,
      head: [['Serviço', 'Status', 'Secretário', 'Equipe', 'Data', 'Hora', 'Local', 'Descrição', 'Justificativa']],
      body: tableData,
      theme: 'grid',
      headStyles: { fillColor: [46, 81, 164] },
      styles: { fontSize: 7 }
    });

    // Employee Productivity Table
    doc.addPage();
    doc.setFontSize(16);
    doc.text('Produtividade por Funcionário', 14, 22);
    
    const employeeTableData = (Object.entries(productivityData.employeeStats) as [string, { performed: number, completed: number, cancelled: number, rescheduled: number }][])
      .sort(([, a], [, b]) => b.completed - a.completed)
      .map(([uid, stats]) => {
        const user = users.find(u => u.id === uid);
        return [
          user?.name || 'Usuário',
          stats.performed,
          stats.completed,
          stats.cancelled,
          stats.rescheduled
        ];
      });

    autoTable(doc, {
      startY: 30,
      head: [['Funcionário', 'Executados', 'Concluídos', 'Cancelados', 'Reagendados']],
      body: employeeTableData,
      theme: 'grid',
      headStyles: { fillColor: [16, 185, 129] },
      styles: { fontSize: 9 }
    });

    // Secretary Management Table
    doc.setFontSize(16);
    const finalY = (doc as any).lastAutoTable.finalY || 30;
    doc.text('Gestão de Serviços por Secretário', 14, finalY + 20);

    const secretaryTableData = (Object.entries(productivityData.secretaryStats) as [string, { requested: number, managed: number, completed: number }][])
      .sort(([, a], [, b]) => b.completed - a.completed)
      .map(([uid, stats]) => {
        const user = users.find(u => u.id === uid);
        return [
          user?.name || 'Secretário',
          stats.requested,
          stats.managed,
          stats.completed
        ];
      });

    autoTable(doc, {
      startY: finalY + 28,
      head: [['Secretário', 'Solicitados', 'Gerenciados', 'Concluídos']],
      body: secretaryTableData,
      theme: 'grid',
      headStyles: { fillColor: [46, 81, 164] },
      styles: { fontSize: 9 }
    });

    doc.save(`relatorio_gerecom_${format(new Date(), 'yyyyMMdd')}.pdf`);
  };

  return (
    <div className="max-w-6xl mx-auto space-y-8 pb-20">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex flex-wrap gap-2 bg-white/50 p-1.5 rounded-2xl border border-white/20 backdrop-blur-sm">
          {[
            { id: 'WEEKLY', label: 'Semanal' },
            { id: 'MONTHLY', label: 'Mensal' },
            { id: 'ANNUAL', label: 'Anual' },
            { id: 'CUSTOM', label: 'Escolher período' }
          ].map((f) => (
            <button
              key={f.id}
              onClick={() => {
                setFilterType(f.id as any);
                if (f.id === 'CUSTOM') setShowCustomRange(true);
                else setShowCustomRange(false);
              }}
              className={cn(
                "px-4 py-2 rounded-xl text-sm font-bold transition-all",
                filterType === f.id ? "bg-secondary text-primary shadow-md" : "text-primary/60 hover:bg-white/50"
              )}
            >
              {f.label}
            </button>
          ))}
        </div>

        <button 
          onClick={generatePDF}
          className="flex items-center gap-2 bg-secondary text-primary px-6 py-3 rounded-2xl font-bold hover:bg-secondary/90 transition-all shadow-lg shadow-secondary/20"
        >
          <Download size={20} />
          Exportar PDF
        </button>
      </div>

      {showCustomRange && (
        <motion.div 
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-white p-6 rounded-3xl border shadow-sm flex flex-col md:flex-row items-end gap-4"
        >
          <div className="flex-1 space-y-1.5">
            <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Data Inicial</label>
            <input 
              type="date" 
              className="w-full p-3 bg-slate-50 border rounded-xl outline-none focus:ring-2 focus:ring-primary/20"
              value={customRange.start}
              onChange={(e) => setCustomRange({ ...customRange, start: e.target.value })}
            />
          </div>
          <div className="flex-1 space-y-1.5">
            <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider ml-1">Data Final</label>
            <input 
              type="date" 
              className="w-full p-3 bg-slate-50 border rounded-xl outline-none focus:ring-2 focus:ring-primary/20"
              value={customRange.end}
              onChange={(e) => setCustomRange({ ...customRange, end: e.target.value })}
            />
          </div>
          <button 
            onClick={() => setShowCustomRange(false)}
            className="px-6 py-3 bg-primary text-white rounded-xl font-bold hover:bg-primary/90 transition-all"
          >
            Aplicar
          </button>
        </motion.div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="p-6 bg-white/80 backdrop-blur-sm rounded-3xl border shadow-sm">
          <p className="text-xs font-bold text-slate-400 uppercase tracking-widest mb-1">Total Realizado</p>
          <p className="text-3xl font-bold text-emerald-600">{filteredServices.filter(s => s.status === 'COMPLETED').length}</p>
        </div>
        <div className="p-6 bg-white/80 backdrop-blur-sm rounded-3xl border shadow-sm">
          <p className="text-xs font-bold text-slate-400 uppercase tracking-widest mb-1">Em Execução</p>
          <p className="text-3xl font-bold text-blue-600">{filteredServices.filter(s => s.status === 'IN_PROGRESS').length}</p>
        </div>
        <div className="p-6 bg-white/80 backdrop-blur-sm rounded-3xl border shadow-sm">
          <p className="text-xs font-bold text-slate-400 uppercase tracking-widest mb-1">Cancelados</p>
          <p className="text-3xl font-bold text-red-600">{filteredServices.filter(s => s.status === 'CANCELLED').length}</p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <div className="bg-white/80 backdrop-blur-sm p-6 rounded-[32px] border shadow-sm">
          <h4 className="text-sm font-bold text-secondary uppercase tracking-wider mb-4 flex items-center gap-2">
            <Users size={18} className="text-primary" />
            Produtividade por Funcionário
          </h4>
          <div className="space-y-3">
            {(Object.entries(productivityData.employeeStats) as [string, { performed: number, completed: number, cancelled: number, rescheduled: number }][])
              .sort(([, a], [, b]) => b.completed - a.completed)
              .map(([uid, stats]) => {
                const user = users.find(u => u.id === uid);
                return (
                  <div key={uid} className="flex flex-col p-4 bg-slate-50 rounded-2xl space-y-2">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-primary/10 text-primary flex items-center justify-center font-bold text-xs">
                          <UserIcon size={14} />
                        </div>
                        <span className="text-sm font-bold text-slate-700">{user?.name || 'Usuário'}</span>
                      </div>
                      <span className="bg-emerald-100 text-emerald-700 px-3 py-1 rounded-full text-[10px] font-bold">
                        {stats.completed} concluídos
                      </span>
                    </div>
                    <div className="grid grid-cols-3 gap-2 text-[10px] font-bold text-slate-400 uppercase tracking-tighter">
                      <span>Executados: {stats.performed}</span>
                      <span className="text-red-400">Cancelados: {stats.cancelled}</span>
                      <span className="text-blue-400">Reagendados: {stats.rescheduled}</span>
                    </div>
                  </div>
                );
              })}
            {Object.keys(productivityData.employeeStats).length === 0 && (
              <p className="text-center py-4 text-slate-400 text-sm italic">Nenhum serviço no período.</p>
            )}
          </div>
        </div>

        <div className="bg-white/80 backdrop-blur-sm p-6 rounded-[32px] border shadow-sm">
          <h4 className="text-sm font-bold text-secondary uppercase tracking-wider mb-4 flex items-center gap-2">
            <UserCircle size={18} className="text-primary" />
            Gestão por Secretário
          </h4>
          <div className="space-y-3">
            {(Object.entries(productivityData.secretaryStats) as [string, { requested: number, managed: number, completed: number }][])
              .sort(([, a], [, b]) => b.completed - a.completed)
              .map(([uid, stats]) => {
                const user = users.find(u => u.id === uid);
                return (
                  <div key={uid} className="flex flex-col p-4 bg-slate-50 rounded-2xl space-y-2">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-secondary/20 text-secondary flex items-center justify-center font-bold text-xs">
                          <UserIcon size={14} />
                        </div>
                        <span className="text-sm font-bold text-slate-700">{user?.name || 'Secretário'}</span>
                      </div>
                      <span className="bg-emerald-100 text-emerald-700 px-3 py-1 rounded-full text-[10px] font-bold">
                        {stats.completed} concluídos
                      </span>
                    </div>
                    <div className="grid grid-cols-2 gap-2 text-[10px] font-bold text-slate-400 uppercase tracking-tighter">
                      <span>Solicitados: {stats.requested}</span>
                      <span>Gerenciados: {stats.managed}</span>
                    </div>
                  </div>
                );
              })}
            {Object.keys(productivityData.secretaryStats).length === 0 && (
              <p className="text-center py-4 text-slate-400 text-sm italic">Nenhuma gestão no período.</p>
            )}
          </div>
        </div>
      </div>

      <div className="bg-white/80 backdrop-blur-sm border rounded-[32px] overflow-hidden shadow-sm">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-50/50 border-b">
                <th className="p-4 text-[10px] font-bold text-slate-400 uppercase tracking-widest">Serviço</th>
                <th className="p-4 text-[10px] font-bold text-slate-400 uppercase tracking-widest">Status</th>
                <th className="p-4 text-[10px] font-bold text-slate-400 uppercase tracking-widest">Secretário</th>
                <th className="p-4 text-[10px] font-bold text-slate-400 uppercase tracking-widest">Equipe</th>
                <th className="p-4 text-[10px] font-bold text-slate-400 uppercase tracking-widest">Data/Hora</th>
                <th className="p-4 text-[10px] font-bold text-slate-400 uppercase tracking-widest">Local</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filteredServices.length > 0 ? (
                filteredServices.map((s) => {
                  const p = plannings.find(pl => pl.id === s.planningId);
                  
                  // Use snapshot if planning is deleted
                  const serviceType = p?.serviceType || s.serviceTypeSnapshot || 'Serviço Removido';
                  const department = p?.department || 'N/A';
                  const secretaryId = p?.secretaryId || s.secretaryIdSnapshot;
                  const responsibleSecId = p?.responsibleSecretaryId || s.responsibleSecretaryIdSnapshot;
                  const secretary = users.find(u => u.id === secretaryId);
                  const responsibleSec = users.find(u => u.id === responsibleSecId);
                  
                  const teamNames = s.teamIds.map(tid => users.find(u => u.id === tid)?.name).join(', ');
                  const date = p?.date || s.dateSnapshot || '-';
                  const time = p?.time || s.timeSnapshot || '-';
                  const location = p?.location.address || s.locationSnapshot?.address || '-';
                  
                  return (
                    <tr key={s.id} className="hover:bg-slate-50/50 transition-colors">
                      <td className="p-4">
                        <p className="text-sm font-bold text-secondary">{serviceType}</p>
                        <p className="text-[10px] text-slate-400 uppercase">{department}</p>
                      </td>
                      <td className="p-4">
                        <span className={cn(
                          "px-2 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider",
                          s.status === 'COMPLETED' ? "bg-emerald-100 text-emerald-700" : 
                          s.status === 'CANCELLED' ? "bg-red-100 text-red-700" :
                          s.status === 'RESCHEDULED' ? "bg-amber-100 text-amber-700" :
                          "bg-blue-100 text-blue-700"
                        )}>
                          {s.status === 'COMPLETED' ? 'Concluído' : 
                           s.status === 'CANCELLED' ? 'Cancelado' :
                           s.status === 'RESCHEDULED' ? 'Reagendado' :
                           'Pendente'}
                        </span>
                      </td>
                      <td className="p-4 text-sm text-slate-600">{responsibleSec?.name || secretary?.name || '-'}</td>
                      <td className="p-4 text-sm text-slate-600">{teamNames || '-'}</td>
                      <td className="p-4">
                        <p className="text-sm text-slate-700 font-medium">{date}</p>
                        <p className="text-xs text-slate-400">{time}</p>
                      </td>
                      <td className="p-4 text-sm text-slate-500 max-w-[200px] truncate">{location}</td>
                    </tr>
                  );
                })
              ) : (
                <tr>
                  <td colSpan={6} className="p-12 text-center">
                    <FileText size={48} className="mx-auto text-slate-200 mb-4" />
                    <p className="text-slate-500">Nenhum serviço encontrado para este período.</p>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
