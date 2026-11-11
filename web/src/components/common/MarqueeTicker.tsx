import React from 'react';
import { Terminal, Code, Cpu, Globe2, BookOpen, HeartHandshake, ShieldCheck } from 'lucide-react';

interface SocietyTickerItem {
  name: string;
  category: string;
  icon: React.ReactNode;
}

const FEATURED_TICKER: SocietyTickerItem[] = [
  { name: 'ACM UET Lahore', category: 'Computing & Hackathons', icon: <Terminal className="w-4 h-4 text-emerald-400" /> },
  { name: 'IEEE UET Student Branch', category: 'Robotics & Hardware', icon: <Cpu className="w-4 h-4 text-cyan-400" /> },
  { name: 'UET Debating Society', category: 'Parliamentary & Bilingual', icon: <BookOpen className="w-4 h-4 text-amber-400" /> },
  { name: 'Environmental Protection Society', category: 'Green Initiatives', icon: <Globe2 className="w-4 h-4 text-emerald-400" /> },
  { name: 'UET Blood Donor Society', category: 'Health & Welfare', icon: <HeartHandshake className="w-4 h-4 text-rose-400" /> },
  { name: 'UET AI & Robotics Club', category: 'Autonomous Systems', icon: <Code className="w-4 h-4 text-indigo-400" /> },
];

export const MarqueeTicker: React.FC = () => {
  return (
    <div className="relative w-full overflow-hidden border-y border-zinc-800/80 bg-zinc-950/70 backdrop-blur-md py-3.5 my-8">
      {/* Edge gradient masks */}
      <div className="pointer-events-none absolute left-0 top-0 bottom-0 w-16 sm:w-28 bg-gradient-to-r from-zinc-950 to-transparent z-10" />
      <div className="pointer-events-none absolute right-0 top-0 bottom-0 w-16 sm:w-28 bg-gradient-to-l from-zinc-950 to-transparent z-10" />

      {/* Marquee track */}
      <div className="flex w-max gap-8 animate-marquee hover:[animation-play-state:paused]">
        {[...FEATURED_TICKER, ...FEATURED_TICKER, ...FEATURED_TICKER].map((item, idx) => (
          <div
            key={idx}
            className="flex items-center gap-2.5 px-4 py-1.5 rounded-2xl bg-zinc-900/60 border border-zinc-800/80 text-xs text-zinc-300 shrink-0 hover:border-emerald-500/40 transition group cursor-default"
          >
            <div className="p-1 rounded-lg bg-zinc-950 border border-zinc-800/80 group-hover:scale-110 transition">
              {item.icon}
            </div>
            <span className="font-semibold text-white group-hover:text-emerald-300 transition">
              {item.name}
            </span>
            <span className="text-[10px] text-zinc-500 uppercase tracking-wider font-mono">
              &bull; {item.category}
            </span>
            <ShieldCheck className="w-3.5 h-3.5 text-emerald-400 opacity-60" />
          </div>
        ))}
      </div>
    </div>
  );
};
