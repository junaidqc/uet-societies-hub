import React from 'react';
import { Clock, AlertCircle } from 'lucide-react';
import { formatPKTDate, isClosingSoon } from '../../utils/date';

export interface DeadlineBadgeProps {
  deadline?: string;
  deadlineIso?: string;
}

export const DeadlineBadge: React.FC<DeadlineBadgeProps> = ({ deadline, deadlineIso }) => {
  const targetDate = deadline || deadlineIso || new Date().toISOString();
  const urgent = isClosingSoon(targetDate, 72);
  const formatted = formatPKTDate(targetDate, { month: 'short', day: 'numeric', year: 'numeric' });

  return (
    <div
      className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-mono font-medium border transition ${
        urgent
          ? 'bg-amber-950/70 text-amber-300 border-amber-500/50 shadow-sm shadow-amber-950'
          : 'bg-zinc-900/90 text-zinc-300 border-zinc-800'
      }`}
    >
      {urgent ? (
        <>
          <span className="relative flex h-2 w-2">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-amber-400 opacity-75"></span>
            <span className="relative inline-flex rounded-full h-2 w-2 bg-amber-500"></span>
          </span>
          <AlertCircle className="w-3.5 h-3.5 text-amber-400" />
          <span>Closing Soon: {formatted}</span>
        </>
      ) : (
        <>
          <Clock className="w-3.5 h-3.5 text-zinc-400" />
          <span>Deadline: {formatted}</span>
        </>
      )}
    </div>
  );
};
