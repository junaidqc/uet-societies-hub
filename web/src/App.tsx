import React, { useState, useEffect } from 'react';
import { supabase } from './lib/supabase';
import { Profile, Hiring } from './types';
import { Navbar, NavTab } from './components/Navbar';
import { FeedSection } from './components/FeedSection';
import { SocietiesSection } from './components/SocietiesSection';
import { HiringSection } from './components/HiringSection';
import { CalendarSection } from './components/CalendarSection';
import { GroupsSection } from './components/GroupsSection';
import { AdminSection } from './components/AdminSection';
import { AuthModal } from './components/AuthModal';
import { ProfileModal } from './components/ProfileModal';
import {
  Sparkles,
  Download,
  GraduationCap,
  Globe,
} from 'lucide-react';

export function App() {
  const [currentUser, setCurrentUser] = useState<Profile | null>(null);
  const [activeTab, setActiveTab] = useState<NavTab>('feed');
  const [authModalOpen, setAuthModalOpen] = useState(false);
  const [authMode, setAuthMode] = useState<'signin' | 'signup'>('signin');
  const [profileModalOpen, setProfileModalOpen] = useState(false);
  const [selectedHiringForApply, setSelectedHiringForApply] = useState<Hiring | null>(null);

  // Initialize Auth & Profile
  useEffect(() => {
    const initAuth = async () => {
      try {
        const {
          data: { session },
        } = await supabase.auth.getSession();

        if (session?.user) {
          const { data: profile } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', session.user.id)
            .single();

          if (profile) {
            setCurrentUser(profile);
          } else {
            setCurrentUser({
              id: session.user.id,
              email: session.user.email || '',
              full_name: 'Student',
              roll_number: 'N/A',
              department: 'Engineering',
              semester: 1,
              is_system_admin: false,
            });
          }
        }
      } catch (err) {
        console.error('Error restoring session:', err);
      }
    };

    initAuth();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (_event, session) => {
      if (session?.user) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', session.user.id)
          .single();
        if (profile) setCurrentUser(profile);
      } else {
        setCurrentUser(null);
      }
    });

    return () => {
      subscription.unsubscribe();
    };
  }, []);

  const handleOpenAuth = (mode: 'signin' | 'signup' = 'signin') => {
    setAuthMode(mode);
    setAuthModalOpen(true);
  };

  const handleQuickDemoLogin = async () => {
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: '2025@uet.edu.pk',
        password: 'qwertyuiop123$',
      });

      if (error) throw error;
      if (data.user) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', data.user.id)
          .single();

        if (profile) {
          setCurrentUser(profile);
        } else {
          setCurrentUser({
            id: data.user.id,
            email: '2025@uet.edu.pk',
            full_name: 'Test Student 2025',
            roll_number: '2025-CS-25',
            department: 'Computer Science',
            semester: 2,
            is_system_admin: true,
          });
        }
      }
    } catch (err) {
      console.error('Quick demo login failed:', err);
      handleOpenAuth('signin');
    }
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
    setCurrentUser(null);
  };

  const handleApplyHiring = (hiring: Hiring) => {
    setSelectedHiringForApply(hiring);
    setActiveTab('hirings');
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans">
      {/* Top Demo Banner for Visitors */}
      {!currentUser && (
        <aside aria-label="Demo Credentials Announcement" className="bg-gradient-to-r from-emerald-950 via-slate-900 to-teal-950 border-b border-emerald-500/30 px-4 py-2 text-center text-xs">
          <div className="max-w-7xl mx-auto flex items-center justify-center gap-2 flex-wrap">
            <span className="flex items-center gap-1 text-emerald-400 font-semibold">
              <Sparkles className="w-3.5 h-3.5" /> Testing Credentials:
            </span>
            <span className="font-mono text-slate-300">
              ID: <strong className="text-white">2025@uet.edu.pk</strong> | Pass:{' '}
              <strong className="text-white">qwertyuiop123$</strong>
            </span>
            <button
              onClick={handleQuickDemoLogin}
              className="ml-2 px-2.5 py-0.5 rounded-full bg-emerald-500/20 hover:bg-emerald-500/30 text-emerald-300 border border-emerald-500/40 font-semibold transition"
            >
              Click to Auto Sign In &rarr;
            </button>
          </div>
        </aside>
      )}

      {/* Main Navigation */}
      <Navbar
        activeTab={activeTab}
        onTabChange={setActiveTab}
        currentUser={currentUser}
        onOpenAuth={handleOpenAuth}
        onOpenProfile={() => setProfileModalOpen(true)}
        onLogout={handleLogout}
        onQuickDemoLogin={handleQuickDemoLogin}
      />

      {/* Main Content Area */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {activeTab === 'feed' && (
          <FeedSection
            currentUser={currentUser}
            onRequireAuth={() => handleOpenAuth('signin')}
            onNavigateToCalendar={() => setActiveTab('calendar')}
            onNavigateToSocieties={() => setActiveTab('societies')}
          />
        )}

        {activeTab === 'societies' && (
          <SocietiesSection
            currentUser={currentUser}
            onRequireAuth={() => handleOpenAuth('signin')}
            onApplyHiring={handleApplyHiring}
          />
        )}

        {activeTab === 'hirings' && (
          <HiringSection
            currentUser={currentUser}
            onRequireAuth={() => handleOpenAuth('signin')}
            selectedHiringForApply={selectedHiringForApply}
            onClearSelectedHiring={() => setSelectedHiringForApply(null)}
          />
        )}

        {activeTab === 'calendar' && (
          <CalendarSection
            currentUser={currentUser}
            onRequireAuth={() => handleOpenAuth('signin')}
          />
        )}

        {activeTab === 'groups' && (
          <GroupsSection
            currentUser={currentUser}
            onRequireAuth={() => handleOpenAuth('signin')}
          />
        )}

        {activeTab === 'admin' && <AdminSection currentUser={currentUser} />}
      </main>

      {/* Footer */}
      <footer className="border-t border-slate-900 bg-slate-950/80 py-8 mt-12 text-xs text-slate-500">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <GraduationCap className="w-4 h-4 text-emerald-400" />
            <span className="font-semibold text-slate-300">UET Societies Hub</span>
            <span>&bull; University of Engineering and Technology, Lahore</span>
          </div>

          <div className="flex items-center gap-4">
            <a
              href="https://github.com/junaidqc/uet-societies-hub/releases/latest/download/app-release.apk"
              target="_blank"
              rel="noreferrer"
              className="hover:text-emerald-400 flex items-center gap-1 transition"
            >
              <Download className="w-3.5 h-3.5" />
              <span>Download Android APK</span>
            </a>
            <a
              href="https://github.com/junaidqc/uet-societies-hub"
              target="_blank"
              rel="noreferrer"
              className="hover:text-emerald-400 flex items-center gap-1 transition"
            >
              <Globe className="w-3.5 h-3.5" />
              <span>GitHub Repository</span>
            </a>
          </div>
        </div>
      </footer>

      {/* Modals */}
      <AuthModal
        isOpen={authModalOpen}
        onClose={() => setAuthModalOpen(false)}
        initialMode={authMode}
        onAuthSuccess={(profile) => setCurrentUser(profile)}
      />

      <ProfileModal
        isOpen={profileModalOpen}
        onClose={() => setProfileModalOpen(false)}
        currentUser={currentUser}
        onProfileUpdated={(updated) => setCurrentUser(updated)}
      />
    </div>
  );
}

export default App;
