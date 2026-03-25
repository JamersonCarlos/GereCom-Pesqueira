import React from 'react';
import { Bell } from 'lucide-react';
import { format, parseISO } from 'date-fns';
import { Notification } from '../../types';
import { cn } from '../../lib/utils';

interface NotificationsViewProps {
  notifications: Notification[];
  onRead: (id: string) => void;
}

export const NotificationsView = ({ notifications, onRead }: NotificationsViewProps) => {
  return (
    <div className="max-w-2xl mx-auto space-y-4">
      {notifications.length > 0 ? (
        notifications.map((n) => (
          <div 
            key={n.id} 
            onClick={() => onRead(n.id)}
            className={cn(
              "p-4 rounded-2xl border transition-all cursor-pointer flex gap-4 items-start",
              n.read ? "bg-white opacity-60" : "bg-white border-primary/20 shadow-md ring-1 ring-primary/5"
            )}
          >
            <div className={cn(
              "p-2 rounded-xl shrink-0",
              n.read ? "bg-slate-100 text-slate-400" : "bg-primary/10 text-primary"
            )}>
              <Bell size={20} />
            </div>
            <div className="flex-1">
              <div className="flex items-center justify-between mb-1">
                <h4 className="font-bold text-secondary">{n.title}</h4>
                <span className="text-[10px] font-medium text-slate-400">{format(parseISO(n.createdAt), "HH:mm")}</span>
              </div>
              <p className="text-sm text-slate-600">{n.message}</p>
            </div>
            {!n.read && <div className="w-2 h-2 bg-primary rounded-full mt-2" />}
          </div>
        ))
      ) : (
        <div className="text-center py-20 bg-white border border-dashed rounded-3xl">
          <Bell size={48} className="mx-auto text-slate-200 mb-4" />
          <p className="text-slate-500">Nenhuma notificação.</p>
        </div>
      )}
    </div>
  );
};
