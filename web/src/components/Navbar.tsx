import React, { useState, useEffect } from 'react';
import {
  GraduationCap,
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
  Home,
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
  onOpenDownloadApk: () => void;
}

export const Navbar: React.FC<NavbarProps> = ({
  activeTab,
  onTabChange,
  currentUser,
  onOpenAuth,
  onOpenProfile,
  onLogout,
  onOpenDownloadApk,
}) => {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [userDropdownOpen, setUserDropdownOpen] = useState(false);
  const [isScrolled, setIsScrolled] = useState(false);

  // Shrink-on-scroll sticky nav (Step 3 design requirement)
  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 20);
    };
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

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
    <header
      className={`sticky top-0 z-40 bg-zinc-950/85 backdrop-blur-md border-b border-zinc-800/80 transition-all duration-200 ${
        isScrolled ? 'py-1 shadow-xl shadow-black/40' : 'py-2'
      }`}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div
          className={`flex items-center justify-between transition-all duration-200 ${
            isScrolled ? 'h-13' : 'h-15 sm:h-16'
          }`}
        >
          {/* Logo & University Info (DEF-13: Includes semantic H1) */}
          <div className="flex items-center gap-3">
            <button
              onClick={() => onTabChange('feed')}
              className="flex items-center gap-2.5 text-left group cursor-pointer"
              aria-label="UET Societies Hub Home"
            >
              <div className="w-9 h-9 sm:w-10 sm:h-10 rounded-xl bg-gradient-to-br from-emerald-500 to-teal-700 p-0.5 shadow-lg shadow-emerald-950/40 flex items-center justify-center">
                <div className="w-full h-full bg-zinc-950 rounded-[10px] flex items-center justify-center">
                  <GraduationCap className="w-5 h-5 text-emerald-400 group-hover:scale-110 transition duration-200" />
                </div>
              </div>
              <div>
                <h1 className="flex items-center gap-1.5 m-0 p-0 text-sm sm:text-base leading-none">
                  <span className="font-extrabold text-white tracking-tight">UET</span>
                  <span className="font-light text-emerald-400">Societies Hub</span>
                </h1>
                <p className="text-[10px] text-zinc-400 font-medium tracking-wide uppercase mt-0.5">
                  Univ. of Engineering & Tech, Lahore
                </p>
              </div>
            </button>
          </div>

          {/* Desktop Nav Tabs */}
          <nav
            aria-label="Main Navigation"
            className="hidden md:flex items-center space-x-1 lg:space-x-1.5 bg-zinc-900/50 p-1 rounded-2xl border border-zinc-800/60"
          >
            {navItems.map((item) => {
              if (item.adminOnly && (!currentUser || !currentUser.is_system_admin)) {
                return null;
              }
              const isActive = activeTab === item.id;
              return (
                <button
                  key={item.id}
                  onClick={() => onTabChange(item.id)}
                  className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs lg:text-sm font-medium transition duration-150 cursor-pointer ${
                    isActive
                      ? 'bg-emerald-500/15 text-emerald-300 border border-emerald-500/30 shadow-sm'
                      : 'text-zinc-300 hover:text-white hover:bg-zinc-800/60'
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
            {/* Download Android APK Button (DEF-12: aria-label added) */}
            <button
              type="button"
              onClick={onOpenDownloadApk}
              aria-label="Download official Android APK v1.0.0"
              className="hidden lg:flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-zinc-900 hover:bg-zinc-800 border border-zinc-800 text-xs font-semibold text-zinc-200 hover:text-white transition cursor-pointer"
              title="Download Android APK (v1.0.0)"
            >
              <Download className="w-3.5 h-3.5 text-emerald-400" />
              <span>Android APK</span>
            </button>

            {/* User State */}
            {currentUser ? (
              <div className="relative">
                {/* Backdrop for closing dropdown on outside click */}
                {userDropdownOpen && (
                  <div
                    className="fixed inset-0 z-40"
                    onClick={() => setUserDropdownOpen(false)}
                  />
                )}

                <button
                  onClick={() => setUserDropdownOpen(!userDropdownOpen)}
                  aria-label={`Signed in as ${currentUser.full_name}. Open student account menu.`}
                  className="flex items-center gap-2 p-1.5 rounded-2xl bg-zinc-900/90 hover:bg-zinc-800 border border-zinc-800 transition relative z-40 cursor-pointer"
                >
                  <div className="w-7 h-7 rounded-xl bg-emerald-600/30 text-emerald-300 flex items-center justify-center font-bold text-xs uppercase">
                    {currentUser.full_name?.charAt(0) || 'U'}
                  </div>
                  <div className="hidden sm:block text-left pr-1.5">
                    <p className="text-xs font-semibold text-white leading-tight">
                      {currentUser.full_name}
                    </p>
                    <p className="text-[10px] text-emerald-400 font-mono leading-tight">
                      {currentUser.roll_number}
                    </p>
                  </div>
                </button>

                {userDropdownOpen && (
                  <div className="absolute right-0 mt-2 w-60 rounded-2xl bg-zinc-900 border border-zinc-800 shadow-2xl py-2 z-50 animate-in fade-in duration-150">
                    <div className="px-4 py-2.5 border-b border-zinc-800/80">
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
                      className="w-full flex items-center gap-2.5 px-4 py-2 text-xs text-zinc-300 hover:text-white hover:bg-zinc-800/80 text-left transition cursor-pointer"
                    >
                      <User className="w-4 h-4 text-zinc-400" />
                      <span>Student Profile</span>
                    </button>

                    {currentUser.is_system_admin && (
                      <button
                        onClick={() => {
                          setUserDropdownOpen(false);
                          onTabChange('admin');
                        }}
                        className="w-full flex items-center gap-2.5 px-4 py-2 text-xs text-emerald-400 hover:bg-zinc-800/80 text-left transition cursor-pointer"
                      >
                        <Shield className="w-4 h-4" />
                        <span>Admin Dashboard</span>
                      </button>
                    )}

                    <div className="border-t border-zinc-800 mt-1 pt-1">
                      <button
                        onClick={() => {
                          setUserDropdownOpen(false);
                          onLogout();
                        }}
                        className="w-full flex items-center gap-2.5 px-4 py-2 text-xs text-rose-400 hover:bg-rose-950/30 text-left transition cursor-pointer"
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
                <button
                  type="button"
                  onClick={() => onOpenAuth('signin')}
                  className="px-3.5 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold shadow-md shadow-emerald-950 transition cursor-pointer"
                >
                  Sign In
                </button>
                <button
                  type="button"
                  onClick={() => onOpenAuth('signup')}
                  className="hidden sm:inline-flex px-3.5 py-1.5 rounded-xl bg-zinc-900 hover:bg-zinc-800 text-zinc-200 hover:text-white border border-zinc-800 text-xs font-semibold transition cursor-pointer"
                >
                  Register
                </button>
              </div>
            )}

            {/* Mobile Menu Toggle */}
            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              aria-label={mobileMenuOpen ? 'Close navigation menu' : 'Open navigation menu'}
              className="md:hidden p-2 rounded-xl text-zinc-400 hover:text-white hover:bg-zinc-800 transition cursor-pointer"
            >
              {mobileMenuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
            </button>
          </div>
        </div>
      </div>

      {/* Mobile Drawer */}
      {mobileMenuOpen && (
        <div className="md:hidden border-t border-zinc-800 bg-zinc-950 px-4 pt-3 pb-5 space-y-1.5 animate-in fade-in duration-150">
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
                    ? 'bg-emerald-500/15 text-emerald-300 border border-emerald-500/30'
                    : 'text-zinc-300 hover:bg-zinc-900'
                }`}
              >
                {item.icon}
                <span>{item.label}</span>
              </button>
            );
          })}

          <div className="pt-3 border-t border-zinc-800/80 flex flex-col gap-2">
            <button
              type="button"
              onClick={() => {
                setMobileMenuOpen(false);
                onOpenDownloadApk();
              }}
              className="flex items-center justify-center gap-2 py-2.5 px-3 rounded-xl bg-zinc-900 border border-zinc-800 text-xs font-medium text-zinc-200 cursor-pointer"
            >
              <Download className="w-4 h-4 text-emerald-400" />
              <span>Download Android APK</span>
            </button>

            {!currentUser && (
              <button
                type="button"
                onClick={() => {
                  setMobileMenuOpen(false);
                  onOpenAuth('signin');
                }}
                className="flex items-center justify-center gap-2 py-2.5 px-3 rounded-xl bg-emerald-600 text-white text-xs font-semibold cursor-pointer"
              >
                <span>Student Sign In</span>
              </button>
            )}
          </div>
        </div>
      )}
    </header>
  );
};
