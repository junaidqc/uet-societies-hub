import React, { useState, useEffect, Suspense, lazy } from 'react';
import { supabase } from './lib/supabase';
import { Profile, Hiring, Event, Post, Society, Group } from './types';
import { Navbar, NavTab } from './components/Navbar';
import { AuthModal } from './components/AuthModal';
import { ProfileModal } from './components/ProfileModal';
import { DownloadApkModal } from './components/DownloadApkModal';
import { EventRegistrationModal } from './components/EventRegistrationModal';
import { ToastProvider, useToast } from './components/Toast';
import { getAppUrlState, syncAppUrl } from './utils/urlState';
import {
  Download,
  GraduationCap,
  Globe,
  Loader2,
} from 'lucide-react';

// DEF-15: Code-splitting sections for high performance and fast initial paint
const FeedSection = lazy(() =>
  import('./components/FeedSection').then((m) => ({ default: m.FeedSection }))
);
const SocietiesSection = lazy(() =>
  import('./components/SocietiesSection').then((m) => ({ default: m.SocietiesSection }))
);
const HiringSection = lazy(() =>
  import('./components/HiringSection').then((m) => ({ default: m.HiringSection }))
);
const CalendarSection = lazy(() =>
  import('./components/CalendarSection').then((m) => ({ default: m.CalendarSection }))
);
const GroupsSection = lazy(() =>
  import('./components/GroupsSection').then((m) => ({ default: m.GroupsSection }))
);
const AdminSection = lazy(() =>
  import('./components/AdminSection').then((m) => ({ default: m.AdminSection }))
);

function SectionFallback() {
  return (
    <div className="py-24 flex flex-col items-center justify-center gap-3 text-slate-500 animate-fadeIn">
      <Loader2 className="w-7 h-7 text-emerald-400 animate-spin" />
      <span className="text-xs font-mono">Loading campus module...</span>
    </div>
  );
}

function AppContent() {
  const { showToast } = useToast();
  const [currentUser, setCurrentUser] = useState<Profile | null>(null);

  // DEF-01: Initialize activeTab from URL search params
  const [activeTab, setActiveTab] = useState<NavTab>(() => getAppUrlState().tab);

  const [authModalOpen, setAuthModalOpen] = useState(false);
  const [authMode, setAuthMode] = useState<'signin' | 'signup'>('signin');
  const [profileModalOpen, setProfileModalOpen] = useState(false);
  const [downloadApkOpen, setDownloadApkOpen] = useState(false);
  const [selectedHiringForApply, setSelectedHiringForApply] = useState<Hiring | null>(null);
  const [selectedEventForRegister, setSelectedEventForRegister] = useState<Event | null>(null);

  // In-memory cache for seamless, instant tab switching without blank card repaints
  const [cachedPosts, setCachedPosts] = useState<Post[]>([]);
  const [cachedEvents, setCachedEvents] = useState<Event[]>([]);
  const [cachedSocieties, setCachedSocieties] = useState<Society[]>([]);
  const [cachedHirings, setCachedHirings] = useState<Hiring[]>([]);
  const [cachedGroups, setCachedGroups] = useState<Group[]>([]);

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
              full_name: session.user.user_metadata?.full_name || 'Student',
              roll_number: session.user.user_metadata?.roll_number || 'N/A',
              department: session.user.user_metadata?.department || 'Engineering',
              semester: session.user.user_metadata?.semester || 1,
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

  // DEF-01: Synchronize browser URL query parameters and listen for popstate (Back/Forward)
  const handleTabChange = (tab: NavTab) => {
    setActiveTab(tab);
    syncAppUrl({ tab });
  };

  useEffect(() => {
    const handlePopState = () => {
      const state = getAppUrlState();
      setActiveTab(state.tab);
    };

    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, []);

  // Close auth modal when user signs in
  useEffect(() => {
    if (currentUser) {
      setAuthModalOpen(false);
    }
  }, [currentUser]);

  const handleOpenAuth = (mode: 'signin' | 'signup' = 'signin') => {
    setAuthMode(mode);
    setAuthModalOpen(true);
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
    setCurrentUser(null);
    showToast('Signed out of student session.', 'info');
  };

  const handleApplyHiring = (hiring: Hiring) => {
    setSelectedHiringForApply(hiring);
    handleTabChange('hirings');
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans">
      {/* Main Navigation */}
      <Navbar
        activeTab={activeTab}
        onTabChange={handleTabChange}
        currentUser={currentUser}
        onOpenAuth={handleOpenAuth}
        onOpenProfile={() => setProfileModalOpen(true)}
        onLogout={handleLogout}
        onOpenDownloadApk={() => setDownloadApkOpen(true)}
      />

      {/* Main Content Area */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Suspense fallback={<SectionFallback />}>
          {activeTab === 'feed' && (
            <FeedSection
              currentUser={currentUser}
              onRequireAuth={() => handleOpenAuth('signin')}
              onNavigateToCalendar={() => handleTabChange('calendar')}
              onNavigateToSocieties={() => handleTabChange('societies')}
              onRegisterEvent={(evt) => setSelectedEventForRegister(evt)}
              cachedPosts={cachedPosts}
              cachedEvents={cachedEvents}
              onCacheData={(posts, events) => {
                setCachedPosts(posts);
                setCachedEvents(events);
              }}
            />
          )}

          {activeTab === 'societies' && (
            <SocietiesSection
              currentUser={currentUser}
              onRequireAuth={() => handleOpenAuth('signin')}
              onApplyHiring={handleApplyHiring}
              cachedSocieties={cachedSocieties}
              onCacheSocieties={(socs) => setCachedSocieties(socs)}
            />
          )}

          {activeTab === 'hirings' && (
            <HiringSection
              currentUser={currentUser}
              onRequireAuth={() => handleOpenAuth('signin')}
              selectedHiringForApply={selectedHiringForApply}
              onClearSelectedHiring={() => setSelectedHiringForApply(null)}
              cachedHirings={cachedHirings}
              onCacheHirings={(hires) => setCachedHirings(hires)}
            />
          )}

          {activeTab === 'calendar' && (
            <CalendarSection
              currentUser={currentUser}
              onRequireAuth={() => handleOpenAuth('signin')}
              onRegisterEvent={(evt) => setSelectedEventForRegister(evt)}
              cachedEvents={cachedEvents}
              onCacheEvents={(events) => setCachedEvents(events)}
            />
          )}

          {activeTab === 'groups' && (
            <GroupsSection
              currentUser={currentUser}
              onRequireAuth={() => handleOpenAuth('signin')}
              cachedGroups={cachedGroups}
              onCacheGroups={(grps) => setCachedGroups(grps)}
            />
          )}

          {activeTab === 'admin' && <AdminSection currentUser={currentUser} />}
        </Suspense>
      </main>

      {/* Footer (triggers download modal and valid release download) */}
      <footer className="border-t border-slate-900 bg-slate-950/80 py-8 mt-12 text-xs text-slate-500">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <GraduationCap className="w-4 h-4 text-emerald-400" />
            <span className="font-semibold text-slate-300">UET Societies Hub</span>
            <span>&bull; University of Engineering and Technology, Lahore</span>
          </div>

          <div className="flex items-center gap-4">
            <button
              type="button"
              onClick={() => setDownloadApkOpen(true)}
              className="hover:text-emerald-400 flex items-center gap-1 transition cursor-pointer"
            >
              <Download className="w-3.5 h-3.5" />
              <span>Download Android APK (v1.0.0)</span>
            </button>
            <a
              href="https://github.com/junaidqc/uet-societies-hub"
              target="_blank"
              rel="noreferrer"
              className="hover:text-emerald-400 flex items-center gap-1 transition cursor-pointer"
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

      {/* Android APK Download Modal */}
      <DownloadApkModal
        isOpen={downloadApkOpen}
        onClose={() => setDownloadApkOpen(false)}
        onDownloadStarted={() => {
          showToast('Starting Android APK download (36.7 MB)...', 'info');
          setDownloadApkOpen(false);
        }}
      />

      {/* Event Registration Modal */}
      <EventRegistrationModal
        isOpen={!!selectedEventForRegister}
        onClose={() => setSelectedEventForRegister(null)}
        event={selectedEventForRegister}
        currentUser={currentUser}
        onRequireAuth={() => {
          setSelectedEventForRegister(null);
          handleOpenAuth('signin');
        }}
      />
    </div>
  );
}

export function App() {
  return (
    <ToastProvider>
      <AppContent />
    </ToastProvider>
  );
}

export default App;
