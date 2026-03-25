/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect, useMemo } from 'react';
import { 
  LayoutDashboard, 
  Calendar, 
  Briefcase, 
  Users, 
  FileText, 
  Bell, 
  LogOut,
  Menu,
  X,
  User as UserIcon,
  Clock,
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { format, parseISO } from 'date-fns';

import { cn } from './lib/utils';
import { User, UserRole, Planning, Service, Notification, ServiceStatus, Invitation, Shift } from './types';
import { MOCK_USERS } from './constants';

import { Logo } from './components/Logo';
import { NavItem } from './components/NavItem';
import { MobileNavItem } from './components/MobileNavItem';
import { EntryView } from './components/EntryView';
import { LoginView } from './components/LoginView';
import { RegisterView } from './components/RegisterView';
import { DashboardView } from './components/DashboardView';
import { PlanningView } from './components/PlanningView';
import { ServicesView } from './components/ServicesView';
import { ScheduleView } from './components/ScheduleView';
import { ReportsView } from './components/ReportsView';
import { ProfileView } from './components/ProfileView';
import { NotificationsView } from './components/NotificationsView';
import { TeamManagementView } from './components/TeamManagementView';

import { useIsMobile, useLocalStorage } from './hooks/useAppHooks';

export default function App() {
  const isMobile = useIsMobile();
  const [currentUser, setCurrentUser] = useLocalStorage<User | null>('gerecom_current_user', null);
  const [users, setUsers] = useLocalStorage<User[]>('gerecom_users', MOCK_USERS);
  const [invitations, setInvitations] = useLocalStorage<Invitation[]>('gerecom_invitations', []);
  const [activeTab, setActiveTab] = useState('dashboard');
  const [isSidebarOpen, setIsSidebarOpen] = useState(!isMobile);
  const [authStep, setAuthStep] = useState<'ENTRY' | 'LOGIN' | 'REGISTER'>('ENTRY');
  const [selectedRole, setSelectedRole] = useState<UserRole | null>(null);

  const [allPlannings, setAllPlannings] = useLocalStorage<Planning[]>('gerecom_plannings', []);
  const [allServices, setAllServices] = useLocalStorage<Service[]>('gerecom_services', []);
  const [allNotifications, setAllNotifications] = useLocalStorage<Notification[]>('gerecom_notifications', []);
  const [allShifts, setAllShifts] = useLocalStorage<Shift[]>('gerecom_shifts', []);

  const currentManagerId = useMemo(() => {
    if (!currentUser) return null;
    return currentUser.role === 'MANAGER' ? currentUser.id : currentUser.managerId;
  }, [currentUser]);

  const plannings = useMemo(() => {
    if (!currentUser || !currentManagerId) return [];
    return allPlannings.filter(p => p.managerId === currentManagerId);
  }, [allPlannings, currentUser, currentManagerId]);

  const services = useMemo(() => {
    if (!currentUser || !currentManagerId) return [];
    return allServices.filter(s => s.managerId === currentManagerId);
  }, [allServices, currentUser, currentManagerId]);

  const notifications = useMemo(() => {
    if (!currentUser || !currentManagerId) return [];
    return allNotifications.filter(n => n.managerId === currentManagerId && n.userId === currentUser.id);
  }, [allNotifications, currentUser, currentManagerId]);

  const shifts = useMemo(() => {
    if (!currentUser || !currentManagerId) return [];
    return allShifts.filter(s => s.managerId === currentManagerId);
  }, [allShifts, currentUser, currentManagerId]);

  const teamMembers = useMemo(() => {
    if (!currentUser || !currentManagerId) return [];
    return users.filter(u => u.managerId === currentManagerId || u.id === currentManagerId);
  }, [users, currentUser, currentManagerId]);

  const linkedManagers = useMemo(() => {
    if (currentUser?.role !== 'GENERAL_MANAGER') return [];
    return users.filter(u => u.role === 'MANAGER' && u.generalManagerId === currentUser.id);
  }, [users, currentUser]);

  useEffect(() => {
    if (isMobile) {
      setIsSidebarOpen(false);
    } else {
      setIsSidebarOpen(true);
    }
  }, [isMobile]);

  // --- Actions ---

  const addNotification = (userId: string, title: string, message: string, type: 'service' | 'schedule' | 'general' = 'general', relatedId?: string) => {
    if (!currentManagerId) return;
    const notification: Notification = {
      id: crypto.randomUUID(),
      userId,
      managerId: currentManagerId,
      title,
      message,
      read: false,
      createdAt: new Date().toISOString(),
      type,
      relatedId
    };
    setAllNotifications(prev => [notification, ...prev]);
  };

  const addPlanning = (newPlanning: Omit<Planning, 'id' | 'createdAt' | 'status' | 'managerId'>) => {
    if (!currentUser || !currentManagerId) return;
    const planning: Planning = {
      ...newPlanning,
      id: crypto.randomUUID(),
      managerId: currentManagerId,
      createdAt: new Date().toISOString(),
      status: 'PENDING'
    };
    setAllPlannings(prev => [planning, ...prev]);
    
    // Notify Manager
    addNotification(currentManagerId, 'Novo Planejamento', `A secretaria ${planning.department} enviou um novo planejamento.`, 'service', planning.id);
  };

  const updatePlanningStatus = (id: string, status: ServiceStatus, reason?: string) => {
    setAllPlannings(prev => prev.map(p => p.id === id ? { ...p, status, rejectionReason: reason } : p));
    
    const planning = allPlannings.find(p => p.id === id);
    if (planning) {
      addNotification(planning.secretaryId, 'Status Atualizado', `Seu planejamento para ${planning.serviceType} foi ${status === 'APPROVED' ? 'aprovado' : 'rejeitado'}.`, 'service', planning.id);
    }
  };

  const deletePlanning = (id: string) => {
    setAllPlannings(prev => prev.filter(p => p.id !== id));
  };

  const updatePlanning = (updatedPlanning: Planning) => {
    setAllPlannings(prev => prev.map(p => p.id === updatedPlanning.id ? updatedPlanning : p));
    
    // Check if there's an associated service
    const service = allServices.find(s => s.planningId === updatedPlanning.id);
    if (service) {
      const oldTeamIds = service.teamIds || [];
      const newTeamIds = updatedPlanning.responsibleEmployeeIds || [];
      
      // Update service teamIds and snapshots
      setAllServices(prev => prev.map(s => s.id === service.id ? {
        ...s,
        teamIds: newTeamIds,
        updatedAt: new Date().toISOString(),
        serviceTypeSnapshot: updatedPlanning.serviceType,
        secretaryIdSnapshot: updatedPlanning.secretaryId,
        dateSnapshot: updatedPlanning.date,
        timeSnapshot: updatedPlanning.time,
        locationSnapshot: updatedPlanning.location,
        descriptionSnapshot: updatedPlanning.description,
        observationsSnapshot: updatedPlanning.observations
      } : s));

      // Notify new employees
      const addedEmployees = newTeamIds.filter(id => !oldTeamIds.includes(id));
      addedEmployees.forEach(tid => {
        addNotification(
          tid, 
          'Novo serviço atribuído a você', 
          `Novo serviço atribuído a você: ${updatedPlanning.serviceType} – ${format(parseISO(updatedPlanning.date), 'dd/MM/yyyy')} às ${updatedPlanning.time}.`, 
          'service', 
          service.id
        );
      });
    }
  };

  const createService = (planningId: string, teamIds: string[]) => {
    if (!currentManagerId) return;
    const planning = allPlannings.find(p => p.id === planningId);
    if (!planning) return;

    const newService: Service = {
      id: crypto.randomUUID(),
      managerId: currentManagerId,
      planningId,
      teamIds,
      status: 'IN_PROGRESS',
      updatedAt: new Date().toISOString(),
      // Snapshots for history
      serviceTypeSnapshot: planning.serviceType,
      secretaryIdSnapshot: planning.secretaryId,
      dateSnapshot: planning.date,
      timeSnapshot: planning.time,
      locationSnapshot: planning.location,
      descriptionSnapshot: planning.description,
      observationsSnapshot: planning.observations
    };
    setAllServices(prev => [...prev, newService]);
    
    // Update Planning status and responsible team
    setAllPlannings(prev => prev.map(p => p.id === planningId ? { 
      ...p, 
      status: 'APPROVED', 
      responsibleEmployeeIds: teamIds 
    } : p));

    // Notify Team
    teamIds.forEach(tid => {
      addNotification(
        tid, 
        'Novo serviço atribuído a você', 
        `Novo serviço atribuído a você: ${planning.serviceType} – ${format(parseISO(planning.date), 'dd/MM/yyyy')} às ${planning.time}.`, 
        'service', 
        newService.id
      );
    });
  };

  const updateServiceStatus = (id: string, status: ServiceStatus, reason?: string) => {
    setAllServices(prev => prev.map(s => s.id === id ? { 
      ...s, 
      status, 
      reason, 
      updatedAt: new Date().toISOString(), 
      managerConfirmed: false,
      completedBy: status === 'WAITING_APPROVAL' ? currentUser?.id : s.completedBy
    } : s));
    
    const service = allServices.find(s => s.id === id);
    if (service) {
      const planning = allPlannings.find(p => p.id === service.planningId);
      const employee = users.find(u => u.id === currentUser?.id);
      
      if (planning && employee && currentManagerId) {
        let title = 'Status de Serviço Atualizado';
        let message = `${employee.name} atualizou o status do serviço ${planning.serviceType} para ${status}.`;
        
        if (status === 'WAITING_APPROVAL') {
          title = 'Serviço Concluído (Aguardando Aprovação)';
          message = `${employee.name} informou que concluiu o serviço '${planning.serviceType}'. Aguarda confirmação do gerente.`;
        } else if (status === 'CANCELLED') {
          title = 'Serviço Cancelado';
          message = `${employee.name} cancelou o serviço '${planning.serviceType}'. Motivo: ${reason}`;
        } else if (status === 'RESCHEDULED') {
          title = 'Serviço Reagendado';
          message = `${employee.name} reagendou o serviço '${planning.serviceType}'. Motivo: ${reason}`;
        }

        // Notify Manager
        addNotification(currentManagerId, title, message, 'service', service.id);
        
        // Notify Secretary
        addNotification(planning.secretaryId, 'Atualização de Serviço', `O serviço solicitado (${planning.serviceType}) para ${planning.date} foi marcado como ${status}.`, 'service', service.id);
      }
    }
  };

  const confirmServiceStatus = (id: string) => {
    setAllServices(prev => prev.map(s => s.id === id ? { 
      ...s, 
      status: s.status === 'WAITING_APPROVAL' ? 'COMPLETED' : s.status, 
      managerConfirmed: true, 
      updatedAt: new Date().toISOString() 
    } : s));
    
    const service = allServices.find(s => s.id === id);
    if (service) {
      const planning = allPlannings.find(p => p.id === service.planningId);
      if (planning) {
        // Notify Team
        service.teamIds.forEach(tid => {
          addNotification(tid, 'Serviço Confirmado', `O gerente confirmou o status do serviço ${planning.serviceType}.`, 'service', service.id);
        });
      }
    }
  };

  const reviewService = (id: string) => {
    setAllServices(prev => prev.map(s => s.id === id ? { ...s, status: 'IN_PROGRESS', managerConfirmed: false, updatedAt: new Date().toISOString() } : s));
    
    const service = allServices.find(s => s.id === id);
    if (service) {
      const planning = allPlannings.find(p => p.id === service.planningId);
      if (planning) {
        // Notify Team
        service.teamIds.forEach(tid => {
          addNotification(tid, 'Revisão de Serviço Solicitada', `O gerente solicitou a revisão do serviço ${planning.serviceType}. Por favor, verifique os detalhes.`, 'service', service.id);
        });
      }
    }
  };

  const addShift = (newShift: Omit<Shift, 'id' | 'createdAt' | 'managerId'>) => {
    if (!currentManagerId) return;
    const shift: Shift = {
      ...newShift,
      id: crypto.randomUUID(),
      managerId: currentManagerId,
      createdAt: new Date().toISOString()
    };
    setAllShifts(prev => [...prev, shift]);
    
    // Notify employees if requested
    if (shift.notifyEmployees) {
      shift.employeeIds.forEach(empId => {
        addNotification(empId, 'Escala de Plantão', `Você foi escalado para o plantão do dia ${format(parseISO(shift.date), 'dd/MM/yyyy')}.`, 'schedule', shift.id);
      });
    }
  };

  const markNotificationRead = (id: string) => {
    const notification = allNotifications.find(n => n.id === id);
    if (notification) {
      if (notification.type === 'service') setActiveTab('services');
      else if (notification.type === 'schedule') setActiveTab('schedule');
    }
    setAllNotifications(prev => prev.map(n => n.id === id ? { ...n, read: true } : n).filter(n => !n.read));
  };

  const addInvitation = (invite: Omit<Invitation, 'id' | 'createdAt' | 'managerId'>) => {
    if (!currentUser) return;
    const newInvite: Invitation = {
      ...invite,
      id: crypto.randomUUID(),
      managerId: currentUser.id,
      createdAt: new Date().toISOString()
    };
    setInvitations(prev => [...prev, newInvite]);
  };

  const removeInvitation = (token: string) => {
    setInvitations(prev => prev.filter(i => i.token !== token));
  };

  const handleLogin = (username: string, password: string): boolean => {
    const user = users.find(u => u.username === username && u.password === password);
    if (user) {
      setCurrentUser(user);
      return true;
    }
    return false;
  };

  const handleRegister = (username: string, password: string, role: UserRole, managerId?: string) => {
    const newUser: User = {
      id: crypto.randomUUID(),
      username,
      password,
      name: username, // Default name to username
      role,
      managerId,
      status: 'ACTIVE',
      createdAt: new Date().toISOString()
    } as any;
    setUsers(prev => [...prev, newUser]);
    setCurrentUser(newUser);

    // Notify Manager if joined a team
    if (managerId) {
      const manager = users.find(u => u.id === managerId);
      const roleName = role === 'SECRETARY' ? 'Secretário' : 'Funcionário';
      addNotification(managerId, 'Novo Membro na Equipe', `Novo membro adicionado à sua equipe: ${username} – Nível de acesso: ${roleName}.`, 'general');
    }
  };

  const updateTeamMember = (updatedMember: User) => {
    setUsers(prev => prev.map(u => u.id === updatedMember.id ? updatedMember : u));
    if (currentUser && updatedMember.id === currentUser.id) {
      setCurrentUser(updatedMember);
    }
  };

  const deleteTeamMember = (id: string) => {
    setUsers(prev => prev.filter(u => u.id !== id));
    addNotification(currentUser?.id || '', 'Membro Removido', 'Um membro foi removido da equipe.', 'general');
  };

  const addTeamMember = (newMember: Omit<User, 'id' | 'createdAt' | 'managerId'>) => {
    if (!currentUser) return;
    const user: User = {
      ...newMember,
      id: crypto.randomUUID(),
      managerId: currentUser.id,
      createdAt: new Date().toISOString(),
      status: 'ACTIVE'
    } as any;
    setUsers(prev => [...prev, user]);
  };

  // --- Views ---

  const renderContent = () => {
    if (!currentUser) {
      if (authStep === 'ENTRY') {
        return (
          <EntryView 
            onSelectRole={(role) => {
              setSelectedRole(role);
              setAuthStep('REGISTER');
            }} 
            onGoToLogin={() => setAuthStep('LOGIN')} 
          />
        );
      }
      if (authStep === 'LOGIN') {
        return (
          <LoginView 
            onLogin={handleLogin} 
            onBack={() => setAuthStep('ENTRY')} 
          />
        );
      }
      if (authStep === 'REGISTER') {
        return (
          <RegisterView 
            role={selectedRole!} 
            onRegister={handleRegister} 
            onBack={() => setAuthStep('ENTRY')} 
            users={users}
            invitations={invitations}
          />
        );
      }
    }

    if (!currentUser) return null;

    switch (activeTab) {
      case 'dashboard': return <DashboardView plannings={plannings} services={services} user={currentUser} teamMembers={teamMembers} users={users} />;
      case 'planning': return <PlanningView plannings={plannings} onAdd={addPlanning} onUpdateStatus={updatePlanningStatus} user={currentUser} onCreateService={createService} onDelete={deletePlanning} onUpdate={updatePlanning} teamMembers={teamMembers} users={users} />;
      case 'services': return <ServicesView services={services} plannings={plannings} onUpdateStatus={updateServiceStatus} onConfirmStatus={confirmServiceStatus} onReviewStatus={reviewService} user={currentUser} users={users} />;
      case 'schedule': return (
        <ScheduleView 
          services={services} 
          plannings={plannings} 
          user={currentUser} 
          onScheduleService={(pId, tIds) => createService(pId, tIds)}
          shifts={shifts}
          onAddShift={addShift}
          teamMembers={teamMembers}
          users={users}
        />
      );
      case 'team': return (
        <TeamManagementView 
          team={teamMembers} 
          onUpdate={updateTeamMember}
          onAdd={addTeamMember}
          onDelete={deleteTeamMember}
          role={currentUser.role}
          invitations={invitations.filter(i => i.managerId === currentUser.id)}
          onAddInvitation={addInvitation}
          onRemoveInvitation={removeInvitation}
          allUsers={users}
          currentUser={currentUser}
        />
      );
      case 'reports': 
        if (currentUser.role !== 'MANAGER' && currentUser.role !== 'GESTOR' && currentUser.role !== 'GENERAL_MANAGER') {
          return <DashboardView plannings={plannings} services={services} user={currentUser} teamMembers={teamMembers} users={users} />;
        }
        return (
          <ReportsView 
            plannings={plannings} 
            services={services} 
            users={users} 
            linkedManagers={linkedManagers}
            currentUser={currentUser}
          />
        );
      case 'notifications': return <NotificationsView notifications={notifications.filter(n => n.userId === currentUser.id)} onRead={markNotificationRead} />;
      case 'profile': return <ProfileView user={currentUser} onLogout={() => { setCurrentUser(null); setAuthStep('ENTRY'); }} />;
      default: return <DashboardView plannings={plannings} services={services} user={currentUser} teamMembers={teamMembers} users={users} />;
    }
  };

  if (!currentUser) {
    return (
      <div className="h-screen bg-slate-50 overflow-y-auto">
        {renderContent()}
      </div>
    );
  }

  return (
    <div className="flex h-screen overflow-hidden bg-transparent font-sans relative">
      {/* Sidebar Overlay for Mobile */}
      <AnimatePresence>
        {isMobile && isSidebarOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={() => setIsSidebarOpen(false)}
            className="fixed inset-0 bg-black/50 z-40 backdrop-blur-sm"
          />
        )}
      </AnimatePresence>

      {/* Sidebar */}
      <motion.aside 
        initial={false}
        animate={{ 
          width: isMobile ? 280 : (isSidebarOpen ? 260 : 80),
          x: isMobile && !isSidebarOpen ? -280 : 0
        }}
        className={cn(
          "bg-primary text-white flex flex-col z-50 transition-all duration-300 ease-in-out",
          isMobile ? "fixed inset-y-0 left-0 shadow-2xl" : "relative"
        )}
      >
        <div className="p-6 flex items-center justify-between">
          {(isSidebarOpen || isMobile) && <Logo className="text-2xl" variant="white" />}
          {!isMobile && (
            <button onClick={() => setIsSidebarOpen(!isSidebarOpen)} className="p-1 hover:bg-white/10 rounded">
              {isSidebarOpen ? <X size={20} /> : <Menu size={20} />}
            </button>
          )}
          {isMobile && (
            <button onClick={() => setIsSidebarOpen(false)} className="p-1 hover:bg-white/10 rounded">
              <X size={20} />
            </button>
          )}
        </div>

        <nav className="flex-1 px-3 space-y-1 overflow-y-auto">
          <NavItem icon={<LayoutDashboard size={20} />} label="Dashboard" active={activeTab === 'dashboard'} onClick={() => { setActiveTab('dashboard'); if(isMobile) setIsSidebarOpen(false); }} collapsed={!isSidebarOpen && !isMobile} />
          
          {(currentUser.role === 'MANAGER' || currentUser.role === 'SECRETARY' || currentUser.role === 'GESTOR') && (
            <NavItem icon={<FileText size={20} />} label="Planejamentos" active={activeTab === 'planning'} onClick={() => { setActiveTab('planning'); if(isMobile) setIsSidebarOpen(false); }} collapsed={!isSidebarOpen && !isMobile} />
          )}
          
          <NavItem icon={<Briefcase size={20} />} label="Serviços" active={activeTab === 'services'} onClick={() => { setActiveTab('services'); if(isMobile) setIsSidebarOpen(false); }} collapsed={!isSidebarOpen && !isMobile} />
          
          {(currentUser.role === 'MANAGER' || currentUser.role === 'EMPLOYEE' || currentUser.role === 'SECRETARY' || currentUser.role === 'GESTOR') && (
            <NavItem icon={<Calendar size={20} />} label="Escala" active={activeTab === 'schedule'} onClick={() => { setActiveTab('schedule'); if(isMobile) setIsSidebarOpen(false); }} collapsed={!isSidebarOpen && !isMobile} />
          )}
          
          {(currentUser.role === 'MANAGER' || currentUser.role === 'GESTOR') && (
            <NavItem icon={<Users size={20} />} label="Equipe & Convites" active={activeTab === 'team'} onClick={() => { setActiveTab('team'); if(isMobile) setIsSidebarOpen(false); }} collapsed={!isSidebarOpen && !isMobile} count={invitations.filter(i => i.managerId === currentUser.id).length} />
          )}
          
          {(currentUser.role === 'MANAGER' || currentUser.role === 'GESTOR' || currentUser.role === 'GENERAL_MANAGER') && (
            <NavItem icon={<FileText size={20} />} label="Relatórios" active={activeTab === 'reports'} onClick={() => { setActiveTab('reports'); if(isMobile) setIsSidebarOpen(false); }} collapsed={!isSidebarOpen && !isMobile} />
          )}
          
          <NavItem icon={<Bell size={20} />} label="Notificações" active={activeTab === 'notifications'} onClick={() => { setActiveTab('notifications'); if(isMobile) setIsSidebarOpen(false); }} collapsed={!isSidebarOpen && !isMobile} count={notifications.filter(n => n.userId === currentUser.id && !n.read).length} />
        </nav>

        <div className="p-4 border-t border-white/10 space-y-4">
          <div className={cn("flex items-center gap-3", !isSidebarOpen && !isMobile && "justify-center")}>
            <div className="w-10 h-10 rounded-full bg-secondary text-primary flex items-center justify-center font-bold shrink-0">
              <UserIcon size={20} />
            </div>
            {(isSidebarOpen || isMobile) && (
              <div className="overflow-hidden">
                <p className="text-sm font-medium truncate">{currentUser.name}</p>
                <p className="text-xs text-white/60 truncate">{currentUser.role}</p>
              </div>
            )}
          </div>
          <button 
            onClick={() => {
              setCurrentUser(null);
              setAuthStep('ENTRY');
            }}
            className={cn(
              "w-full flex items-center gap-3 px-3 py-2 rounded-lg text-white/60 hover:bg-red-500/20 hover:text-red-200 transition-all",
              !isSidebarOpen && !isMobile && "justify-center"
            )}
          >
            <LogOut size={20} />
            {(isSidebarOpen || isMobile) && <span className="text-sm font-medium">Sair</span>}
          </button>
        </div>
      </motion.aside>

      {/* Main Content */}
      <main className="flex-1 flex flex-col min-w-0 overflow-hidden relative">
        <header className="h-16 bg-secondary border-b border-primary/10 flex items-center justify-between px-4 md:px-8 z-20 shadow-sm">
          <div className="flex items-center gap-3">
            {isMobile && (
              <button 
                onClick={() => setIsSidebarOpen(true)}
                className="p-2 text-primary hover:bg-primary/10 rounded-lg"
              >
                <Menu size={20} />
              </button>
            )}
            <h2 className="text-lg font-bold text-primary capitalize">
              {activeTab === 'dashboard' ? 'Dashboard' :
               activeTab === 'planning' ? 'Planejamentos' :
               activeTab === 'services' ? 'Serviços' :
               activeTab === 'schedule' ? 'Escala' :
               activeTab === 'team' ? 'Equipe' :
               activeTab === 'reports' ? 'Relatórios' :
               activeTab === 'notifications' ? 'Notificações' :
               activeTab === 'profile' ? 'Perfil do Usuário' :
               activeTab}
            </h2>
          </div>
          
          <button 
            onClick={() => setActiveTab('profile')}
            className="flex items-center gap-4 hover:bg-primary/5 p-2 rounded-xl transition-all"
          >
            <div className="hidden md:flex flex-col items-end">
              <span className="text-sm font-bold text-primary">{currentUser.name}</span>
              <span className="text-[10px] font-medium text-primary/60 uppercase tracking-wider">{currentUser.role}</span>
            </div>
            <div className="w-10 h-10 rounded-full bg-primary/10 text-primary flex items-center justify-center font-bold border border-primary/20">
              <UserIcon size={20} />
            </div>
          </button>
        </header>

        <div className={cn("flex-1 overflow-y-auto p-4 md:p-8 bg-transparent", isMobile && "pb-24")}>
          <AnimatePresence mode="wait">
            <motion.div
              key={activeTab}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              transition={{ duration: 0.2 }}
            >
              {renderContent()}
            </motion.div>
          </AnimatePresence>
        </div>

        {/* Mobile Bottom Navigation */}
        {isMobile && (
          <div className="fixed bottom-0 left-0 right-0 bg-secondary border-t border-primary/10 flex justify-around items-center h-16 px-2 z-40 pb-safe shadow-[0_-4px_10px_rgba(0,0,0,0.05)]">
            <MobileNavItem icon={<LayoutDashboard size={20} />} active={activeTab === 'dashboard'} onClick={() => setActiveTab('dashboard')} />
            {(currentUser.role === 'MANAGER' || currentUser.role === 'SECRETARY' || currentUser.role === 'GESTOR') && (
              <MobileNavItem icon={<FileText size={20} />} active={activeTab === 'planning'} onClick={() => setActiveTab('planning')} />
            )}
            <MobileNavItem icon={<Briefcase size={20} />} active={activeTab === 'services'} onClick={() => setActiveTab('services')} />
            {(currentUser.role === 'MANAGER' || currentUser.role === 'EMPLOYEE' || currentUser.role === 'SECRETARY' || currentUser.role === 'GESTOR') && (
              <MobileNavItem icon={<Calendar size={20} />} active={activeTab === 'schedule'} onClick={() => setActiveTab('schedule')} />
            )}
            {(currentUser.role === 'MANAGER' || currentUser.role === 'GESTOR') && (
              <MobileNavItem icon={<Users size={20} />} active={activeTab === 'team'} onClick={() => setActiveTab('team')} />
            )}
            {(currentUser.role === 'MANAGER' || currentUser.role === 'GESTOR' || currentUser.role === 'GENERAL_MANAGER') && (
              <MobileNavItem icon={<Clock size={20} />} active={activeTab === 'reports'} onClick={() => setActiveTab('reports')} />
            )}
            <MobileNavItem icon={<Bell size={20} />} active={activeTab === 'notifications'} onClick={() => setActiveTab('notifications')} count={notifications.filter(n => n.userId === currentUser.id && !n.read).length} />
          </div>
        )}
      </main>
    </div>
  );
}
