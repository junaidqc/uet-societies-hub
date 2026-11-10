import React, { useState, useEffect } from 'react';
import {
  X,
  LogIn,
  UserPlus,
  KeyRound,
  Mail,
  User,
  AlertCircle,
  Eye,
  EyeOff,
  ScanLine,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { StudentCardScannerModal } from './StudentCardScannerModal';
import { Profile } from '../types';
import { useToast } from './Toast';

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
  onAuthSuccess: (profile: Profile) => void;
  initialMode?: 'signin' | 'signup';
}

export const AuthModal: React.FC<AuthModalProps> = ({
  isOpen,
  onClose,
  onAuthSuccess,
  initialMode = 'signin',
}) => {
  const { showToast } = useToast();
  const [mode, setMode] = useState<'signin' | 'signup'>(initialMode);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [rollNumber, setRollNumber] = useState('');
  const [department, setDepartment] = useState('Computer Science');
  const [semester, setSemester] = useState(2);
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [scannerOpen, setScannerOpen] = useState(false);

  useEffect(() => {
    if (isOpen) {
      setMode(initialMode);
      setErrorMsg(null);
    }
  }, [isOpen, initialMode]);

  if (!isOpen) return null;

  const handleSignIn = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setErrorMsg(null);
    try {
      const cleanEmail = email.trim();
      const { data, error } = await supabase.auth.signInWithPassword({
        email: cleanEmail,
        password,
      });

      if (error) throw error;
      if (!data.user) throw new Error('Sign in failed');

      const { data: profileData } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', data.user.id)
        .single();

      const profile: Profile = profileData || {
        id: data.user.id,
        email: data.user.email || cleanEmail,
        full_name: data.user.user_metadata?.full_name || cleanEmail.split('@')[0],
        roll_number: data.user.user_metadata?.roll_number || 'N/A',
        department: data.user.user_metadata?.department || 'Engineering',
        semester: data.user.user_metadata?.semester || 1,
        is_system_admin: false,
      };

      showToast(`Welcome back, ${profile.full_name}!`, 'success');
      onAuthSuccess(profile);
      onClose();
    } catch (err: any) {
      console.error('Sign in error:', err);
      setErrorMsg(err.message || 'Invalid email or password. Please verify credentials.');
    } finally {
      setLoading(false);
    }
  };

  const handleSignUp = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setErrorMsg(null);

    const cleanEmail = email.trim();
    if (!cleanEmail.endsWith('@uet.edu.pk')) {
      setErrorMsg('Please use an official UET student email address (ending with @uet.edu.pk)');
      setLoading(false);
      return;
    }

    try {
      const { data, error } = await supabase.auth.signUp({
        email: cleanEmail,
        password,
        options: {
          data: {
            full_name: fullName,
            roll_number: rollNumber,
            department,
            semester,
          },
        },
      });

      if (error) throw error;
      if (!data.user) throw new Error('Signup failed');

      const newProfile: Profile = {
        id: data.user.id,
        email: cleanEmail,
        full_name: fullName,
        roll_number: rollNumber,
        department,
        semester,
        is_system_admin: false,
      };

      await supabase.from('profiles').upsert(newProfile);

      showToast(`Account created successfully! Welcome, ${fullName}`, 'success');
      onAuthSuccess(newProfile);
      onClose();
    } catch (err: any) {
      console.error('Sign up error:', err);
      setErrorMsg(err.message || 'Failed to create student account.');
    } finally {
      setLoading(false);
    }
  };

  const handleScannedCard = (data: {
    rollNumber: string;
    department: string;
    semester: number;
    email: string;
    fullName?: string;
  }) => {
    setRollNumber(data.rollNumber);
    setDepartment(data.department);
    setSemester(data.semester);
    setEmail(data.email);
    if (data.fullName) setFullName(data.fullName);
    setMode('signup');
    showToast(`Autofilled student card data for ${data.rollNumber}!`, 'success');
  };

  return (
    <>
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-md animate-fadeIn">
        <div className="bg-slate-900 border border-slate-700/80 rounded-2xl w-full max-w-md shadow-2xl overflow-hidden flex flex-col">
          {/* Header */}
          <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 bg-slate-950/40">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-emerald-500/20 text-emerald-400 flex items-center justify-center font-bold text-sm">
                UET
              </div>
              <h3 className="font-bold text-white text-base">
                {mode === 'signin' ? 'Sign In to Student Portal' : 'Create Student Account'}
              </h3>
            </div>
            <button
              onClick={onClose}
              className="text-slate-400 hover:text-white p-1.5 rounded-lg hover:bg-slate-800 transition"
            >
              <X className="w-5 h-5" />
            </button>
          </div>

          <div className="p-6 space-y-4">
            {/* Error Message */}
            {errorMsg && (
              <div className="flex items-center gap-2 p-3 bg-red-950/40 border border-red-500/40 text-red-300 text-xs rounded-xl">
                <AlertCircle className="w-4 h-4 shrink-0 text-red-400" />
                <span>{errorMsg}</span>
              </div>
            )}

            {/* Mode Selector Tabs */}
            <div className="grid grid-cols-2 p-1 bg-slate-950 rounded-xl border border-slate-800 text-xs font-semibold">
              <button
                type="button"
                onClick={() => {
                  setMode('signin');
                  setErrorMsg(null);
                }}
                className={`py-2 rounded-lg transition ${
                  mode === 'signin'
                    ? 'bg-slate-800 text-white shadow-sm'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                Sign In
              </button>
              <button
                type="button"
                onClick={() => {
                  setMode('signup');
                  setErrorMsg(null);
                }}
                className={`py-2 rounded-lg transition ${
                  mode === 'signup'
                    ? 'bg-slate-800 text-white shadow-sm'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                Student Sign Up
              </button>
            </div>

            {/* Forms */}
            {mode === 'signin' ? (
              <form onSubmit={handleSignIn} className="space-y-4">
                <div>
                  <label className="text-xs font-medium text-slate-300 mb-1 block">
                    Student Email Address (@uet.edu.pk)
                  </label>
                  <div className="relative">
                    <Mail className="w-4 h-4 text-slate-500 absolute left-3 top-3" />
                    <input
                      type="email"
                      required
                      placeholder="student@uet.edu.pk"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-9 pr-3 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 font-mono"
                    />
                  </div>
                </div>

                <div>
                  <label className="text-xs font-medium text-slate-300 mb-1 block">
                    Password
                  </label>
                  <div className="relative">
                    <KeyRound className="w-4 h-4 text-slate-500 absolute left-3 top-3" />
                    <input
                      type={showPassword ? 'text' : 'password'}
                      required
                      placeholder="••••••••••••"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-9 pr-10 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-3 top-3 text-slate-500 hover:text-slate-300"
                    >
                      {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="w-full py-2.5 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white text-xs font-semibold rounded-xl transition flex items-center justify-center gap-2 shadow-lg shadow-emerald-900/30"
                >
                  <LogIn className="w-4 h-4" /> {loading ? 'Verifying Credentials...' : 'Sign In'}
                </button>
              </form>
            ) : (
              <form onSubmit={handleSignUp} className="space-y-3.5 max-h-[50vh] overflow-y-auto pr-1">
                <button
                  type="button"
                  onClick={() => setScannerOpen(true)}
                  className="w-full py-2 bg-slate-800/80 hover:bg-slate-800 border border-slate-700/80 text-emerald-400 text-xs font-medium rounded-xl transition flex items-center justify-center gap-2"
                >
                  <ScanLine className="w-4 h-4 text-emerald-400" /> Autofill with Student ID Scanner
                </button>

                <div>
                  <label className="text-xs font-medium text-slate-300 mb-1 block">Full Name</label>
                  <div className="relative">
                    <User className="w-4 h-4 text-slate-500 absolute left-3 top-3" />
                    <input
                      type="text"
                      required
                      placeholder="e.g. Ali Ahmed"
                      value={fullName}
                      onChange={(e) => setFullName(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-9 pr-3 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="text-xs font-medium text-slate-300 mb-1 block">Roll Number</label>
                    <input
                      type="text"
                      required
                      placeholder="2024-CS-45"
                      value={rollNumber}
                      onChange={(e) => setRollNumber(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 font-mono uppercase"
                    />
                  </div>
                  <div>
                    <label className="text-xs font-medium text-slate-300 mb-1 block">Semester</label>
                    <select
                      value={semester}
                      onChange={(e) => setSemester(parseInt(e.target.value, 10))}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-white focus:outline-none focus:border-emerald-500"
                    >
                      {[1, 2, 3, 4, 5, 6, 7, 8].map((s) => (
                        <option key={s} value={s}>
                          Semester {s}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>

                <div>
                  <label className="text-xs font-medium text-slate-300 mb-1 block">Department</label>
                  <select
                    value={department}
                    onChange={(e) => setDepartment(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-white focus:outline-none focus:border-emerald-500"
                  >
                    <option value="Computer Science">Computer Science (CS)</option>
                    <option value="Software Engineering">Software Engineering (SE)</option>
                    <option value="Electrical Engineering">Electrical Engineering (EE)</option>
                    <option value="Mechanical Engineering">Mechanical Engineering (ME)</option>
                    <option value="Civil Engineering">Civil Engineering (CE)</option>
                    <option value="Chemical Engineering">Chemical Engineering (CH)</option>
                    <option value="Mechatronics Engineering">Mechatronics Engineering</option>
                  </select>
                </div>

                <div>
                  <label className="text-xs font-medium text-slate-300 mb-1 block">
                    Student Email (@uet.edu.pk)
                  </label>
                  <input
                    type="email"
                    required
                    placeholder="2024cs45@uet.edu.pk"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 font-mono"
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-slate-300 mb-1 block">Create Password</label>
                  <div className="relative">
                    <input
                      type={showPassword ? 'text' : 'password'}
                      required
                      minLength={6}
                      placeholder="At least 6 characters"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 pr-10 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-3 top-2.5 text-slate-500 hover:text-slate-300"
                    >
                      {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="w-full mt-2 py-2.5 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white text-xs font-semibold rounded-xl transition flex items-center justify-center gap-2 shadow-lg shadow-emerald-900/30"
                >
                  <UserPlus className="w-4 h-4" /> {loading ? 'Registering...' : 'Register Student'}
                </button>
              </form>
            )}

            {/* Guest note */}
            <div className="text-center pt-2 border-t border-slate-800">
              <button
                type="button"
                onClick={onClose}
                className="text-xs text-slate-400 hover:text-emerald-400 transition"
              >
                Continue browsing campus hub as Guest &rarr;
              </button>
            </div>
          </div>
        </div>
      </div>

      <StudentCardScannerModal
        isOpen={scannerOpen}
        onClose={() => setScannerOpen(false)}
        onScanned={handleScannedCard}
      />
    </>
  );
};
