import React, { useState } from 'react';
import {
  GraduationCap,
  Sparkles,
  Download,
  User,
  LogOut,
  Shield,
  Menu,
  X,
  Calendar,
  Briefcase,
  Users,
  Compass,
  MessageSquare,
  Home,
  CheckCircle2,
} from 'lucide-react';
import { Profile } from '../types';

export type NavTab = 'feed' | 'societies' | 'hirings' | 'calendar' | 'groups' | 'admin';

interface NavbarProps {
  activeTab: NavTab;
  onTabChange: (tab: NavTab) => void;
  currentUser: Profile | null;
  onOpenAuth: (mode?: 'signin' | 'signup') => void;
  onOpenProfile: () => void;
  onLogout: () => void;
  onQuickDemoLogin: () => void;
}

export const Navbar: React.FC<NavbarProps> = ({
  activeTab,
  onTabChange,
  currentUser,
  onOpenAuth,
  onOpenProfile,
  onLogout,
  onQuickDemoLogin,
}) => {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [userDropdownOpen, setUserDropdownOpen] = useState(false);

  const navItems: { id: NavTab; label: string; icon: React.ReactNode; adminOnly?: boolean }[] = [
    { id: 'feed', label: 'Announcements', icon: <Home className="w-4 h-4" /> },
    { id: 'societies', label: 'Societies', icon: <Compass className="w-4 h-4" /> },
    { id: 'hirings', label: 'Hirings', icon: <Briefcase className="w-4 h-4" /> },
    { id: 'calendar', label: 'Campus Events', icon: <Calendar className="w-4 h-4" /> },
    { id: 'groups', label: 'Working Groups', icon: <Users className="w-4 h-4" /> },
    {
      id: 'admin',
      label: 'Admin Portal',
      icon: <Shield className="w-4 h-4" />,
      adminOnly: true,
    },
  ];

  return (
    <header className="sticky top-0 z-40 bg-slate-900/90 backdrop-blur-md border-b border-slate-800">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo & University Info */}
          <div className="flex items-center gap-3">
            <button
              onClick={() => onTabChange('feed')}
              className="flex items-center gap-2.5 text-left group"
            >
              <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-emerald-500 to-teal-700 p-0.5 shadow-lg shadow-emerald-900/30 flex items-center justify-center">
                <div className="w-full h-full bg-slate-950 rounded-[10px] flex items-center justify-center">
                  <GraduationCap className="w-5 h-5 text-emerald-400 group-hover:scale-110 transition duration-200" />
                </div>
              </div>
              <div className="hidden sm:block">
                <div className="flex items-center gap-1.5">
                  <span className="font-extrabold text-white text-base tracking-tight">UET</span>
                  <span className="font-light text-emerald-400 text-base">Societies Hub</span>
                </div>
                <p className="text-[10px] text-slate-400 font-medium tracking-wide uppercase">
                  Univ. of Engineering & Tech, Lahore
                </p>
              </div>
            </button>
          </div>

          {/* Desktop Nav Tabs */}
          <nav className="hidden md:flex items-center space-x-1 lg:space-x-2">
            {navItems.map((item) => {
              if (item.adminOnly && (!currentUser || !currentUser.is_system_admin)) {
                return null;
              }
              const isActive = activeTab === item.id;
              return (
                <button
                  key={item.id}
                  onClick={() => onTabChange(item.id)}
                  className={`flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs lg:text-sm font-medium transition duration-150 ${
                    isActive
                      ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30'
                      : 'text-slate-300 hover:text-white hover:bg-slate-800/60'
                  }`}
                >
                  {item.icon}
                  <span>{item.label}</span>
                </button>
              );
            })}
          </nav>

          {/* Right actions */}
          <div className="flex items-center gap-2 sm:gap-3">
            {/* Download Android APK Button */}
            <a
              href="https://github.com/junaidqc/uet-societies-hub/releases/latest/download/app-release.apk"
              target="_blank"
              rel="noopener noreferrer"
              className="hidden lg:flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 border border-slate-700/80 text-xs font-semibold text-slate-200 hover:text-white transition"
              title="Download Android APK"
            >
              <Download className="w-3.5 h-3.5 text-emerald-400" />
              <span>Android APK</span>
            </a>

            {/* User State */}
            {currentUser ? (
              <div className="relative">
                <button
                  onClick={() => setUserDropdownOpen(!userDropdownOpen)}
                  className="flex items-center gap-2 p-1.5 rounded-xl bg-slate-800/80 hover:bg-slate-800 border border-slate-700 transition"
                >
                  <div className="w-7 h-7 rounded-lg bg-emerald-600/30 text-emerald-300 flex items-center justify-center font-bold text-xs uppercase">
                    {currentUser.full_name?.charAt(0) || 'U'}
                  </div>
                  <div className="hidden sm:block text-left pr-1">
                    <p className="text-xs font-semibold text-white leading-tight">
                      {currentUser.full_name}
                    </p>
                    <p className="text-[10px] text-emerald-400 font-mono leading-tight">
                      {currentUser.roll_number}
                    </p>
                  </div>
                </button>

                {userDropdownOpen && (
                  <div className="absolute right-0 mt-2 w-56 rounded-2xl bg-slate-900 border border-slate-700 shadow-2xl py-2 z-50 animate-fadeIn">
                    <div className="px-4 py-2 border-b border-slate-800">
                      <p className="text-xs font-semibold text-white truncate">
                        {currentUser.full_name}
                      </p>
                      <p className="text-[11px] font-mono text-emerald-400 truncate">
                        {currentUser.email}
                      </p>
                      {currentUser.is_system_admin && (
                        <div className="inline-flex items-center gap-1 mt-1 px-2 py-0.5 rounded-full bg-emerald-950/80 border border-emerald-500/40 text-[10px] font-semibold text-emerald-400">
                          <Shield className="w-3 h-3" /> System Admin
                        </div>
                      )}
                    </div>

                    <button
                      onClick={() => {
                        setUserDropdownOpen(false);
                        onOpenProfile();
                      }}
                      className="w-full flex items-center gap-2.5 px-4 py-2 text-xs text-slate-300 hover:text-white hover:bg-slate-800 text-left transition"
                    >
                      <User className="w-4 h-4 text-slate-400" />
                      <span>Student Profile</span>
                    </button>

                    {currentUser.is_system_admin && (
                      <button
                        onClick={() => {
                          setUserDropdownOpen(false);
                          onTabChange('admin');
                        }}
                        className="w-full flex items-center gap-2.5 px-4 py-2 text-xs text-emerald-400 hover:bg-slate-800 text-left transition"
                      >
                        <Shield className="w-4 h-4" />
                        <span>Admin Dashboard</span>
                      </button>
                    )}

                    <div className="border-t border-slate-800 mt-1 pt-1">
                      <button
                        onClick={() => {
                          setUserDropdownOpen(false);
                          onLogout();
                        }}
                        className="w-full flex items-center gap-2.5 px-4 py-2 text-xs text-red-400 hover:bg-red-950/30 text-left transition"
                      >
                        <LogOut className="w-4 h-4" />
                        <span>Sign Out</span>
                      </button>
                    </div>
                  </div>
                )}
              </div>
            ) : (
              <div className="flex items-center gap-2">
                {/* 1-Click Test ID */}
                <button
                  onClick={onQuickDemoLogin}
                  className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-600/20 hover:bg-emerald-600/30 border border-emerald-500/40 text-xs font-semibold text-emerald-300 transition"
                  title="Sign In with 2025@uet.edu.pk"
                >
                  <Sparkles className="w-3.5 h-3.5 text-emerald-400" />
                  <span>1-Click Test ID</span>
                </button>

                <button
                  onClick={() => onOpenAuth('signin')}
                  className="px-3.5 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold shadow-md shadow-emerald-900/30 transition"
                >
                  Sign In
                </button>
              </div>
            )}

            {/* Mobile Menu Toggle */}
            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              className="md:hidden p-2 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition"
            >
              {mobileMenuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
            </button>
          </div>
        </div>
      </div>

      {/* Mobile Drawer */}
      {mobileMenuOpen && (
        <div className="md:hidden border-t border-slate-800 bg-slate-900/98 px-4 pt-3 pb-5 space-y-2 animate-fadeIn">
          {navItems.map((item) => {
            if (item.adminOnly && (!currentUser || !currentUser.is_system_admin)) {
              return null;
            }
            const isActive = activeTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => {
                  onTabChange(item.id);
                  setMobileMenuOpen(false);
                }}
                className={`w-full flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-sm font-medium transition ${
                  isActive
                    ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30'
                    : 'text-slate-300 hover:bg-slate-800/80'
                }`}
              >
                {item.icon}
                <span>{item.label}</span>
              </button>
            );
          })}

          <div className="pt-3 border-t border-slate-800 flex flex-col gap-2">
            <a
              href="https://github.com/junaidqc/uet-societies-hub/releases/latest/download/app-release.apk"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center justify-center gap-2 py-2 px-3 rounded-lg bg-slate-800 text-xs font-medium text-slate-200"
            >
              <Download className="w-4 h-4 text-emerald-400" />
              <span>Download Android APK</span>
            </a>

            {!currentUser && (
              <button
                onClick={() => {
                  setMobileMenuOpen(false);
                  onQuickDemoLogin();
                }}
                className="flex items-center justify-center gap-2 py-2 px-3 rounded-lg bg-emerald-600/20 border border-emerald-500/40 text-xs font-semibold text-emerald-300"
              >
                <Sparkles className="w-4 h-4 text-emerald-400" />
                <span>1-Click Test ID (2025@uet.edu.pk)</span>
              </button>
            )}
          </div>
        </div>
      )}
    </header>
  );
};
