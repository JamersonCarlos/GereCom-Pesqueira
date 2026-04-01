import React, { useState, useMemo } from 'react';
import { motion } from 'motion/react';
import {
  ChevronRight,
  Plus,
  Users,
  Briefcase,
  User as UserIcon,
  UserCircle,
  X,
  Calendar as CalendarIcon,
  Bell,
  Check,
} from 'lucide-react';
import { format, startOfWeek, endOfWeek, isSameDay, parseISO } from 'date-fns';
import { ptBR } from 'date-fns/locale';
import { cn } from '../../lib/utils';
import {
  Service,
  Planning,
  User,
  Shift,
  UserRole,
  ServiceStatus,
} from '../../types';

interface ScheduleViewProps {
  services: Service[];
  plannings: Planning[];
  user: User;
  onScheduleService: (pId: string, tIds: string[]) => void;
  shifts: Shift[];
  onAddShift: (s: any) => void;
  teamMembers: User[];
  users: User[];
}

export function ScheduleView({
  services,
  plannings,
  user,
  onScheduleService,
  shifts,
  onAddShift,
  teamMembers,
  users,
}: ScheduleViewProps) {
  const [currentMonth, setCurrentMonth] = useState(new Date());
  const [selectedDay, setSelectedDay] = useState<Date | null>(new Date());
  const [isShiftModalOpen, setIsShiftModalOpen] = useState(false);

  const monthStart = startOfWeek(
    new Date(currentMonth.getFullYear(), currentMonth.getMonth(), 1),
    { weekStartsOn: 0 }
  );
  const monthEnd = endOfWeek(
    new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1, 0),
    { weekStartsOn: 0 }
  );

  const calendarDays = useMemo(() => {
    const days = [];
    let day = monthStart;
    while (day <= monthEnd) {
      days.push(day);
      day = new Date(day.getTime() + 24 * 60 * 60 * 1000);
    }
    return days;
  }, [monthStart, monthEnd]);

  const dayServices = useMemo(() => {
    if (!selectedDay) return [];
    return services
      .filter((s) => {
        const p = plannings.find((pl) => pl.id === s.planningId);
        const date = p?.date || s.dateSnapshot;
        return date && isSameDay(parseISO(date), selectedDay);
      })
      .map((s) => {
        const p = plannings.find((pl) => pl.id === s.planningId);
        return {
          ...s,
          planning:
            p ||
            ({
              id: s.planningId,
              managerId: s.managerId,
              department: 'Geral',
              serviceType: s.serviceTypeSnapshot || 'Serviço',
              date: s.dateSnapshot || '',
              time: s.timeSnapshot || '',
              location: s.locationSnapshot || { address: '', lat: 0, lng: 0 },
              description: s.descriptionSnapshot || '',
              observations: s.observationsSnapshot || '',
              secretaryId: s.secretaryIdSnapshot || '',
              status: s.status === 'CANCELLED' ? 'REJECTED' : 'APPROVED',
              urgency: 'MEDIUM',
              period: 'UNPLANNED',
              responsibleEmployeeIds: s.teamIds,
              createdAt: s.updatedAt,
              updatedAt: s.updatedAt,
            } as Planning),
        };
      });
  }, [services, plannings, selectedDay]);

  const dayShifts = useMemo(() => {
    if (!selectedDay) return [];
    const filtered = shifts.filter((s) =>
      isSameDay(parseISO(s.date), selectedDay)
    );
    if (user.role === 'MANAGER' || user.role === 'GESTOR') return filtered;
    if (user.role === 'SECRETARY') return filtered;
    return filtered.filter((s) => s.employeeIds.includes(user.id));
  }, [shifts, selectedDay, user]);

  const shiftsGroupedByManager = useMemo(() => {
    if (user.role !== 'SECRETARY') return null;
    const groups: Record<
      string,
      { manager: User | undefined; shifts: Shift[] }
    > = {};
    dayShifts.forEach((shift) => {
      if (!groups[shift.managerId]) {
        groups[shift.managerId] = {
          manager: users.find((u) => u.id === shift.managerId),
          shifts: [],
        };
      }
      groups[shift.managerId].shifts.push(shift);
    });
    return groups;
  }, [dayShifts, users, user.role]);

  const visibleDayServices = useMemo(() => {
    if (user.role === 'MANAGER' || user.role === 'GESTOR') return dayServices;
    if (user.role === 'SECRETARY')
      return dayServices.filter(
        (s) =>
          s.planning.secretaryId === user.id ||
          s.planning.responsibleSecretaryId === user.id
      );
    return dayServices.filter((s) => s.teamIds.includes(user.id));
  }, [dayServices, user]);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <h3 className="text-xl font-bold text-secondary">
            {format(currentMonth, 'MMMM yyyy', { locale: ptBR })}
          </h3>
          <div className="flex gap-1">
            <button
              onClick={() =>
                setCurrentMonth(
                  new Date(
                    currentMonth.getFullYear(),
                    currentMonth.getMonth() - 1
                  )
                )
              }
              className="p-2 hover:bg-slate-100 rounded-lg text-secondary"
            >
              <X size={16} className="rotate-45" />
            </button>
            <button
              onClick={() =>
                setCurrentMonth(
                  new Date(
                    currentMonth.getFullYear(),
                    currentMonth.getMonth() + 1
                  )
                )
              }
              className="p-2 hover:bg-slate-100 rounded-lg text-secondary"
            >
              <ChevronRight size={16} />
            </button>
          </div>
        </div>
        {user.role === 'MANAGER' && (
          <button
            onClick={() => setIsShiftModalOpen(true)}
            className="flex items-center gap-2 bg-secondary text-primary px-4 py-2 rounded-xl font-medium hover:bg-secondary/90 transition-colors shadow-lg shadow-secondary/20"
          >
            <Plus size={20} />
            Escalar Equipe
          </button>
        )}
      </div>

      <div className="bg-white border rounded-3xl overflow-hidden shadow-sm">
        <div className="grid grid-cols-7 border-b bg-slate-50">
          {['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'].map((d) => (
            <div
              key={d}
              className="p-3 text-center text-[10px] font-bold text-slate-400 uppercase tracking-widest"
            >
              {d}
            </div>
          ))}
        </div>

        <div className="grid grid-cols-7">
          {calendarDays.map((day, i) => {
            const isCurrentMonth = day.getMonth() === currentMonth.getMonth();
            const isToday = isSameDay(day, new Date());
            const isSelected = selectedDay && isSameDay(day, selectedDay);
            const hasServices = services.some((s) => {
              const p = plannings.find((pl) => pl.id === s.planningId);
              const date = p?.date || s.dateSnapshot;
              return date && isSameDay(parseISO(date), day);
            });
            const hasShifts = shifts.some((s) =>
              isSameDay(parseISO(s.date), day)
            );

            return (
              <button
                key={i}
                onClick={() => setSelectedDay(day)}
                className={cn(
                  'h-14 md:h-24 p-2 border-r border-b last:border-r-0 relative flex flex-col items-center justify-center transition-all',
                  !isCurrentMonth && 'bg-slate-50/50 text-slate-300',
                  isSelected &&
                    'bg-primary/5 ring-2 ring-primary/20 ring-inset',
                  isToday && !isSelected && 'bg-blue-50/30'
                )}
              >
                <span
                  className={cn(
                    'text-sm font-bold',
                    isToday && 'text-primary',
                    !isCurrentMonth && 'font-normal'
                  )}
                >
                  {format(day, 'd')}
                </span>
                <div className="mt-1 flex gap-0.5">
                  {hasServices && (
                    <div className="w-1.5 h-1.5 rounded-full bg-primary" />
                  )}
                  {hasShifts && (
                    <div className="w-1.5 h-1.5 rounded-full bg-yellow-500" />
                  )}
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {selectedDay && (
        <div className="space-y-6">
          {dayShifts.length > 0 && (
            <div className="space-y-4">
              <h4 className="font-bold text-secondary flex items-center gap-2">
                <Users size={18} className="text-yellow-600" />
                Escala em{' '}
                {format(selectedDay, "dd 'de' MMMM", { locale: ptBR })}
              </h4>
              {shiftsGroupedByManager ? (
                Object.entries(shiftsGroupedByManager).map(
                  ([managerId, group]) => (
                    <div
                      key={managerId}
                      className="border border-yellow-200 rounded-2xl overflow-hidden"
                    >
                      <div className="flex items-center gap-3 px-4 py-3 bg-yellow-50 border-b border-yellow-100">
                        <div className="p-1.5 bg-yellow-200 text-yellow-800 rounded-lg">
                          <UserCircle size={16} />
                        </div>
                        <div>
                          <p className="text-[10px] font-bold text-yellow-700 uppercase tracking-wide">
                            Gestor
                          </p>
                          <p className="text-sm font-bold text-secondary">
                            {group.manager?.name || 'Gestor'}
                          </p>
                        </div>
                        {group.manager?.department && (
                          <span className="ml-auto text-[10px] font-bold px-2 py-0.5 bg-yellow-100 text-yellow-700 rounded-full uppercase">
                            {group.manager.department}
                          </span>
                        )}
                      </div>
                      <div className="p-4 space-y-3">
                        {group.shifts.map((shift) => (
                          <div key={shift.id} className="space-y-2">
                            <div className="flex flex-wrap gap-2">
                              {shift.employeeIds.map((eid) => {
                                const emp = users.find((u) => u.id === eid);
                                return (
                                  <div
                                    key={eid}
                                    className="flex items-center gap-1.5 px-2 py-1 bg-white border border-yellow-100 rounded-lg"
                                  >
                                    <UserIcon
                                      size={12}
                                      className="text-yellow-600"
                                    />
                                    <span className="text-xs font-bold text-slate-700">
                                      {emp?.name || 'Funcionário'}
                                    </span>
                                  </div>
                                );
                              })}
                            </div>
                            {shift.observations && (
                              <p className="text-xs text-slate-500 italic">
                                "{shift.observations}"
                              </p>
                            )}
                          </div>
                        ))}
                      </div>
                    </div>
                  )
                )
              ) : (
                <div className="grid grid-cols-1 gap-3">
                  {dayShifts.map((shift) => (
                    <div
                      key={shift.id}
                      className="p-4 bg-yellow-50/50 border border-yellow-100 rounded-2xl"
                    >
                      <div className="flex items-center gap-3 mb-3">
                        <div className="p-2 bg-yellow-100 text-yellow-700 rounded-xl">
                          <Users size={20} />
                        </div>
                        <div className="flex flex-col gap-1">
                          {shift.employeeIds.map((eid) => {
                            const emp = teamMembers.find((u) => u.id === eid);
                            return (
                              <div
                                key={eid}
                                className="flex items-center gap-2"
                              >
                                <UserIcon
                                  size={12}
                                  className="text-yellow-600"
                                />
                                <span className="text-xs font-bold text-slate-700">
                                  {emp?.name}
                                </span>
                              </div>
                            );
                          })}
                        </div>
                      </div>
                      {shift.observations && (
                        <p className="text-xs text-slate-600 italic">
                          "{shift.observations}"
                        </p>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          <div className="space-y-4">
            <h4 className="font-bold text-secondary flex items-center gap-2">
              Serviços em{' '}
              {format(selectedDay, "dd 'de' MMMM", { locale: ptBR })}
            </h4>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {visibleDayServices.length > 0 ? (
                visibleDayServices.map((s) => (
                  <div
                    key={s.id}
                    className="p-4 glass-card rounded-2xl shadow-sm flex items-start gap-4"
                  >
                    <div className="p-2 bg-blue-50 text-primary rounded-xl">
                      <Briefcase size={20} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between mb-1">
                        <h5 className="font-bold text-secondary truncate">
                          {s.planning.serviceType}
                        </h5>
                        <span className="text-xs font-bold text-primary">
                          {s.planning.time}
                        </span>
                      </div>
                      <p className="text-xs text-slate-500 line-clamp-1 mb-3">
                        {s.planning.location.address}
                      </p>

                      <div className="flex items-center gap-2 mb-3">
                        <UserCircle size={14} className="text-slate-400" />
                        <span className="text-[10px] font-medium text-slate-500">
                          Solicitado por:{' '}
                          <span className="text-slate-700 font-bold">
                            {users.find((u) => u.id === s.planning.secretaryId)
                              ?.name || 'Secretário'}
                          </span>
                        </span>
                      </div>

                      <div className="flex items-center justify-between">
                        <div className="flex flex-col gap-1">
                          <p className="text-[10px] font-bold text-slate-400 uppercase">
                            Responsáveis:
                          </p>
                          <div className="flex flex-col gap-1">
                            {s.teamIds.map((tid) => {
                              const emp = teamMembers.find((u) => u.id === tid);
                              return (
                                <div
                                  key={tid}
                                  className="flex items-center gap-2"
                                >
                                  <UserIcon
                                    size={12}
                                    className="text-primary"
                                  />
                                  <span className="text-[10px] font-bold text-slate-700">
                                    {emp?.name}
                                  </span>
                                </div>
                              );
                            })}
                          </div>
                        </div>
                        <span
                          className={cn(
                            'text-[10px] font-bold px-2 py-0.5 rounded-full uppercase',
                            s.status === 'COMPLETED'
                              ? 'bg-emerald-100 text-emerald-700'
                              : s.status === 'WAITING_APPROVAL'
                                ? 'bg-amber-100 text-amber-700'
                                : s.status === 'CANCELLED'
                                  ? 'bg-red-100 text-red-700'
                                  : s.status === 'RESCHEDULED'
                                    ? 'bg-blue-100 text-blue-700'
                                    : 'bg-blue-100 text-blue-700'
                          )}
                        >
                          {s.status === 'WAITING_APPROVAL'
                            ? 'Aguardando Aprovação'
                            : s.status === 'COMPLETED'
                              ? 'Concluído'
                              : s.status === 'CANCELLED'
                                ? 'Cancelado'
                                : s.status === 'RESCHEDULED'
                                  ? 'Reagendado'
                                  : 'Em Andamento'}
                        </span>
                      </div>
                    </div>
                  </div>
                ))
              ) : (
                <div className="md:col-span-2 py-10 text-center bg-slate-50 border border-dashed rounded-2xl">
                  <p className="text-slate-400 text-sm">
                    Nenhum serviço agendado para este dia.
                  </p>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {isShiftModalOpen && (
        <ShiftModal
          team={teamMembers.filter(
            (u) =>
              (u.role === 'EMPLOYEE' || u.role === 'MANAGER') &&
              u.status === 'ACTIVE'
          )}
          onClose={() => setIsShiftModalOpen(false)}
          onSubmit={(data) => {
            onAddShift(data);
            setIsShiftModalOpen(false);
          }}
          initialDate={selectedDay || new Date()}
        />
      )}
    </div>
  );
}

function ShiftModal({
  team,
  onClose,
  onSubmit,
  initialDate,
}: {
  team: User[];
  onClose: () => void;
  onSubmit: (data: any) => void;
  initialDate: Date;
}) {
  const [date, setDate] = useState(format(initialDate, 'yyyy-MM-dd'));
  const [selectedEmployees, setSelectedEmployees] = useState<string[]>([]);
  const [observations, setObservations] = useState('');
  const [notify, setNotify] = useState(true);

  const toggleEmployee = (id: string) => {
    setSelectedEmployees((prev) =>
      prev.includes(id) ? prev.filter((i) => i !== id) : [...prev, id]
    );
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-end md:items-center justify-center">
      <motion.div
        initial={{ opacity: 0, y: 100 }}
        animate={{ opacity: 1, y: 0 }}
        className="w-full max-w-lg bg-white rounded-t-[32px] md:rounded-[32px] p-8 shadow-2xl"
      >
        <div className="flex items-center justify-between mb-8">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-yellow-100 text-yellow-700 rounded-2xl">
              <CalendarIcon size={24} />
            </div>
            <div>
              <h3 className="text-xl font-bold text-secondary">
                Escalar Equipe
              </h3>
              <p className="text-sm text-slate-500">
                Definir plantão para o dia
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-slate-100 rounded-full transition-colors"
          >
            <X size={24} className="text-slate-400" />
          </button>
        </div>

        <div className="space-y-6">
          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-400 uppercase tracking-wider ml-1">
              Data do Plantão
            </label>
            <input
              type="date"
              value={date}
              onChange={(e) => setDate(e.target.value)}
              className="w-full p-4 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 transition-all"
            />
          </div>

          <div className="space-y-3">
            <label className="text-xs font-bold text-slate-400 uppercase tracking-wider ml-1">
              Selecionar Funcionários
            </label>
            <div className="grid grid-cols-1 gap-2 max-h-48 overflow-y-auto p-1">
              {team.map((emp) => (
                <button
                  key={emp.id}
                  onClick={() => toggleEmployee(emp.id)}
                  className={cn(
                    'flex items-center justify-between p-4 rounded-2xl border transition-all',
                    selectedEmployees.includes(emp.id)
                      ? 'bg-primary/5 border-primary ring-1 ring-primary'
                      : 'bg-white border-slate-100 hover:border-slate-200'
                  )}
                >
                  <div className="flex items-center gap-3">
                    <div
                      className={cn(
                        'w-10 h-10 rounded-xl flex items-center justify-center font-bold',
                        selectedEmployees.includes(emp.id)
                          ? 'bg-primary text-white'
                          : 'bg-slate-100 text-slate-500'
                      )}
                    >
                      {emp.name.charAt(0)}
                    </div>
                    <div className="text-left">
                      <p className="font-bold text-secondary text-sm">
                        {emp.name}
                      </p>
                      <p className="text-[10px] text-slate-500 uppercase tracking-wider">
                        {emp.role}
                      </p>
                    </div>
                  </div>
                  {selectedEmployees.includes(emp.id) && (
                    <Check size={20} className="text-primary" />
                  )}
                </button>
              ))}
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-400 uppercase tracking-wider ml-1">
              Observações (Opcional)
            </label>
            <textarea
              value={observations}
              onChange={(e) => setObservations(e.target.value)}
              className="w-full p-4 bg-slate-50 border rounded-2xl outline-none focus:ring-2 focus:ring-primary/20 transition-all h-24 resize-none"
              placeholder="Ex: Plantão de sobreaviso para emergências..."
            />
          </div>

          <div className="flex items-center justify-between p-4 bg-slate-50 rounded-2xl">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-blue-100 text-blue-600 rounded-lg">
                <Bell size={18} />
              </div>
              <div>
                <p className="text-sm font-bold text-secondary">
                  Notificar Equipe
                </p>
                <p className="text-[10px] text-slate-500">
                  Enviar aviso para os selecionados
                </p>
              </div>
            </div>
            <button
              onClick={() => setNotify(!notify)}
              className={cn(
                'w-12 h-6 rounded-full transition-all relative',
                notify ? 'bg-primary' : 'bg-slate-300'
              )}
            >
              <div
                className={cn(
                  'absolute top-1 w-4 h-4 bg-white rounded-full transition-all',
                  notify ? 'right-1' : 'left-1'
                )}
              />
            </button>
          </div>

          <div className="flex gap-3 pt-4">
            <button
              onClick={onClose}
              className="flex-1 py-4 bg-slate-100 text-slate-600 rounded-2xl font-bold hover:bg-slate-200 transition-all"
            >
              Cancelar
            </button>
            <button
              onClick={() =>
                onSubmit({
                  date,
                  employeeIds: selectedEmployees,
                  observations,
                  notify,
                })
              }
              disabled={selectedEmployees.length === 0}
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
