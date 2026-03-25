export type UserRole = 'SECRETARY' | 'MANAGER' | 'EMPLOYEE' | 'GESTOR' | 'GENERAL_MANAGER';

export interface User {
  id: string;
  username: string;
  password?: string;
  name: string;
  role: UserRole;
  managerId?: string; // Linked to the manager who created/invited this user
  generalManagerId?: string; // Linked to the General Manager
  department?: string;
  function?: string;
  status?: 'ACTIVE' | 'INACTIVE';
  email?: string;
  phone?: string;
  createdAt: string;
}

export interface Invitation {
  id: string;
  managerId: string;
  role: UserRole;
  username: string;
  token: string;
  createdAt: string;
}

export interface Shift {
  id: string;
  managerId: string;
  date: string;
  employeeIds: string[];
  observations?: string;
  createdAt: string;
  notifyEmployees?: boolean;
}

export type UrgencyLevel = 'LOW' | 'MEDIUM' | 'HIGH' | 'URGENT';
export type PlanningPeriod = 'WEEKLY' | 'MONTHLY' | 'ANNUAL' | 'UNPLANNED';
export type ServiceStatus = 'PENDING' | 'APPROVED' | 'REJECTED' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED' | 'RESCHEDULED' | 'WAITING_APPROVAL';

export interface Planning {
  id: string;
  managerId: string;
  secretaryId: string;
  department: string;
  serviceType: string;
  date: string;
  time: string;
  location: {
    address: string;
    lat?: number;
    lng?: number;
  };
  description: string;
  observations?: string;
  urgency: UrgencyLevel;
  period: PlanningPeriod;
  status: ServiceStatus;
  rejectionReason?: string;
  responsibleEmployeeIds?: string[];
  responsibleSecretaryId?: string; // New field for linked secretary
  createdAt: string;
}

export interface Service {
  id: string;
  managerId: string;
  planningId: string;
  teamIds: string[];
  status: ServiceStatus;
  executionDate?: string;
  notes?: string;
  updatedAt: string;
  managerConfirmed?: boolean;
  reason?: string; // Reason for cancellation or rescheduling
  completedBy?: string; // ID of the employee who marked as completed
  
  // Snapshot fields for historical reports (persists even if planning is deleted)
  serviceTypeSnapshot?: string;
  secretaryIdSnapshot?: string;
  dateSnapshot?: string;
  timeSnapshot?: string;
  locationSnapshot?: {
    address: string;
    lat?: number;
    lng?: number;
  };
  descriptionSnapshot?: string;
  observationsSnapshot?: string;
}

export interface Notification {
  id: string;
  userId: string;
  managerId: string;
  title: string;
  message: string;
  read: boolean;
  createdAt: string;
  type?: 'service' | 'schedule' | 'general';
  relatedId?: string;
}
