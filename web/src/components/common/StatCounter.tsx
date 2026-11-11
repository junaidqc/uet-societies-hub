import React, { useEffect, useState } from 'react';

export interface StatCounterProps {
  end?: number;
  target?: number;
  value?: number;
  label: string;
  suffix?: string;
  duration?: number;
  icon?: React.ReactNode;
}

export const StatCounter: React.FC<StatCounterProps> = ({
  end,
  target,
  value,
  label,
  suffix = '',
  duration = 1000,
  icon,
}) => {
  const targetNumber = end ?? target ?? value ?? 0;
  const [count, setCount] = useState(0);

  useEffect(() => {
    let startTimestamp: number | null = null;
    const startValue = 0;

    const step = (timestamp: number) => {
      if (!startTimestamp) startTimestamp = timestamp;
      const progress = Math.min((timestamp - startTimestamp) / duration, 1);
      // Ease out quad
      const current = Math.floor(startValue + (targetNumber - startValue) * (1 - (1 - progress) * (1 - progress)));
      setCount(current);

      if (progress < 1) {
        window.requestAnimationFrame(step);
      } else {
        setCount(targetNumber);
      }
    };

    window.requestAnimationFrame(step);
  }, [targetNumber, duration]);

  return (
    <div className="flex items-center gap-3.5 p-4 rounded-2xl bg-zinc-900/60 border border-zinc-800/80 shadow-lg">
      {icon && (
        <div className="w-10 h-10 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 flex items-center justify-center shrink-0">
          {icon}
        </div>
      )}
      <div>
        <div className="text-xl sm:text-2xl font-extrabold font-mono text-white tracking-tight">
          {count}
          {suffix}
        </div>
        <div className="text-xs text-zinc-400 font-medium">{label}</div>
      </div>
    </div>
  );
};
