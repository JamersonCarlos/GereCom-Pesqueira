import React, { useMemo } from 'react';
import { motion } from 'motion/react';
import { Service, User } from '../../types';
import { cn } from '../../lib/utils';

interface WorkloadControlProps {
  services: Service[];
  teamMembers: User[];
}

export const WorkloadControl = ({ services, teamMembers }: WorkloadControlProps) => {
  const workload = useMemo(() => {
    const employees = teamMembers.filter(u => u.role === 'EMPLOYEE');
    return employees.map(emp => {
      const activeServices = services.filter(s => s.teamIds.includes(emp.id) && s.status === 'IN_PROGRESS').length;
      return {
        name: emp.name,
        services: activeServices
      };
    }).sort((a, b) => b.services - a.services);
  }, [services, teamMembers]);

  return (
    <div className="glass-card p-6 rounded-2xl">
      <h3 className="text-lg font-bold text-secondary mb-6">Controle de Carga de Trabalho</h3>
      <div className="space-y-6">
        {workload.map((item, i) => (
          <div key={i} className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="font-medium text-slate-700">{item.name}</span>
              <span className="font-bold text-primary">{item.services} serviços ativos</span>
            </div>
            <div className="h-2 bg-slate-100 rounded-full overflow-hidden">
              <motion.div 
                initial={{ width: 0 }}
                animate={{ width: `${Math.min((item.services / 10) * 100, 100)}%` }}
                className={cn(
                  "h-full rounded-full",
                  item.services > 7 ? "bg-red-500" : item.services > 4 ? "bg-amber-500" : "bg-emerald-500"
                )}
              />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};
