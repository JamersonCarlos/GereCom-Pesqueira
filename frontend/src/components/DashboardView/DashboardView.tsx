import React, { useMemo } from 'react';
import { motion } from 'motion/react';
import { 
  Clock, 
  AlertCircle, 
  CheckCircle2 
} from 'lucide-react';
import { 
  isSameDay, 
  parseISO, 
  format 
} from 'date-fns';
import { 
  BarChart, 
  Bar, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer, 
  PieChart, 
  Pie, 
  Cell 
} from 'recharts';
import { Planning, Service, User } from '../../types';
import { COLORS } from '../../constants';
import { cn } from '../../lib/utils';
import { ProductivityDashboard } from '../ProductivityDashboard';
import { WorkloadControl } from '../WorkloadControl';

interface DashboardViewProps {
  plannings: Planning[];
  services: Service[];
  user: User;
  teamMembers: User[];
  users: User[];
}

export const DashboardView = ({ plannings, services, user, teamMembers, users }: DashboardViewProps) => {
  const stats = useMemo(() => {
    const today = new Date();
    
    let filteredPlannings = plannings;
    let filteredServices = services;

    if (user.role === 'SECRETARY') {
      filteredPlannings = plannings.filter(p => p.secretaryId === user.id);
      filteredServices = services.filter(s => {
        const p = plannings.find(pl => pl.id === s.planningId);
        const secId = p?.secretaryId || s.secretaryIdSnapshot;
        return secId === user.id;
      });
    } else if (user.role === 'EMPLOYEE') {
      filteredServices = services.filter(s => s.teamIds.includes(user.id));
      filteredPlannings = plannings.filter(p => filteredServices.some(s => s.planningId === p.id));
    }

    const servicesToday = filteredServices.filter(s => {
      const p = plannings.find(pl => pl.id === s.planningId);
      const date = p?.date || s.dateSnapshot;
      return date && isSameDay(parseISO(date), today);
    });

    return [
      { label: 'Serviços Hoje', value: servicesToday.length, icon: <Clock className="text-blue-500" />, color: 'bg-blue-50' },
      { label: 'Pendentes', value: filteredPlannings.filter(p => p.status === 'PENDING').length, icon: <AlertCircle className="text-amber-500" />, color: 'bg-amber-50' },
      { label: 'Concluídos', value: filteredServices.filter(s => s.status === 'COMPLETED').length, icon: <CheckCircle2 className="text-emerald-500" />, color: 'bg-emerald-50' },
      { label: 'Urgentes', value: filteredPlannings.filter(p => p.urgency === 'URGENT' && p.status !== 'COMPLETED').length, icon: <AlertCircle className="text-red-500" />, color: 'bg-red-50' },
    ];
  }, [plannings, services, user]);

  const chartData = useMemo(() => {
    const last7Days = Array.from({ length: 7 }).map((_, i) => {
      const d = new Date();
      d.setDate(d.getDate() - (6 - i));
      return format(d, 'dd/MM');
    });

    return last7Days.map(day => ({
      name: day,
      servicos: Math.floor(Math.random() * 10), // Mock data for trend
    }));
  }, []);

  const pieData = [
    { name: 'Saúde', value: plannings.filter(p => p.department === 'Saúde').length },
    { name: 'Educação', value: plannings.filter(p => p.department === 'Educação').length },
    { name: 'Obras', value: plannings.filter(p => p.department === 'Obras').length },
    { name: 'Outros', value: plannings.filter(p => !['Saúde', 'Educação', 'Obras'].includes(p.department)).length },
  ].filter(d => d.value > 0);

  return (
    <div className="space-y-8">
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {stats.map((stat, i) => (
          <motion.div 
            key={i}
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: i * 0.1 }}
            className="p-6 rounded-2xl glass-card flex items-center gap-4"
          >
            <div className={cn("p-3 rounded-xl", stat.color)}>
              {stat.icon}
            </div>
            <div>
              <p className="text-sm text-slate-500 font-medium">{stat.label}</p>
              <p className="text-2xl font-bold text-slate-900">{stat.value}</p>
            </div>
          </motion.div>
        ))}
      </div>

      {(user.role === 'MANAGER' || user.role === 'GESTOR' || user.role === 'GENERAL_MANAGER') && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div className="lg:col-span-2">
            <ProductivityDashboard services={services} users={users} teamMembers={teamMembers} />
          </div>
          <div>
            <WorkloadControl services={services} teamMembers={teamMembers} />
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2 p-6 rounded-2xl glass-card">
          <h3 className="text-lg font-semibold mb-6 text-secondary">Produtividade Semanal</h3>
          <div className="h-80">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fontSize: 12, fill: '#64748b' }} />
                <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 12, fill: '#64748b' }} />
                <Tooltip 
                  cursor={{ fill: '#f8fafc' }}
                  contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)' }}
                />
                <Bar dataKey="servicos" fill={COLORS.primary} radius={[4, 4, 0, 0]} barSize={40} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="p-6 rounded-2xl glass-card">
          <h3 className="text-lg font-semibold mb-6 text-secondary">Serviços por Secretaria</h3>
          <div className="h-80 flex flex-col items-center justify-center">
            {pieData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={pieData}
                    cx="50%"
                    cy="50%"
                    innerRadius={60}
                    outerRadius={80}
                    paddingAngle={5}
                    dataKey="value"
                  >
                    {pieData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={[COLORS.primary, COLORS.secondary, '#10b981', '#f43f5e'][index % 4]} />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <div className="text-slate-400 text-sm italic">Nenhum dado disponível</div>
            )}
            <div className="mt-4 space-y-2 w-full">
              {pieData.map((d, i) => (
                <div key={i} className="flex items-center justify-between text-sm">
                  <div className="flex items-center gap-2">
                    <div className="w-3 h-3 rounded-full" style={{ backgroundColor: [COLORS.primary, COLORS.secondary, '#10b981', '#f43f5e'][i % 4] }} />
                    <span className="text-slate-600">{d.name}</span>
                  </div>
                  <span className="font-semibold">{d.value}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
