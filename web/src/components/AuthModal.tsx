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
  ShieldCheck,
  RotateCw,
  ArrowLeft,
  CheckCircle2,
  ExternalLink,
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
  const [mode, setMode] = useState<'signin' | 'signup' | 'verify_otp'>(initialMode);
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

  // OTP Verification States
  const [otpCode, setOtpCode] = useState('');
  const [pendingVerificationEmail, setPendingVerificationEmail] = useState('');
  const [pendingPassword, setPendingPassword] = useState('');
  const [campusOtpPreview, setCampusOtpPreview] = useState<string | null>(null);
  const [resendCountdown, setResendCountdown] = useState(0);

  useEffect(() => {
    if (isOpen) {
      setMode(initialMode);
      setErrorMsg(null);
    }
  }, [isOpen, initialMode]);

  // Countdown timer for OTP resend
  useEffect(() => {
    if (resendCountdown <= 0) return;
    const timer = setInterval(() => {
      setResendCountdown((prev) => (prev > 0 ? prev - 1 : 0));
    }, 1000);
    return () => clearInterval(timer);
  }, [resendCountdown]);

  if (!isOpen) return null;

  const handleSignIn = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setErrorMsg(null);
    try {
      const cleanEmail = email.trim().toLowerCase();
      const { data, error } = await supabase.auth.signInWithPassword({
        email: cleanEmail,
        password,
      });

      if (error) {
        // Detect if email is not confirmed
        if (
          error.message?.toLowerCase().includes('email not confirmed') ||
          error.message?.toLowerCase().includes('not verified')
        ) {
          // Trigger OTP generation and dispatch confirmation email
          const { data: otpRes } = await supabase.rpc('request_email_verification_otp', {
            p_email: cleanEmail,
          });

          const redirectUrl = window.location.origin + window.location.pathname;
          try {
            await supabase.auth.resend({
              type: 'signup',
              email: cleanEmail,
              options: { emailRedirectTo: redirectUrl },
            });
          } catch (_) {}

          setPendingVerificationEmail(cleanEmail);
          setPendingPassword(password);
          if (otpRes?.otp_code) {
            setCampusOtpPreview(otpRes.otp_code);
          }
          setMode('verify_otp');
          setResendCountdown(60);
          setErrorMsg(
            'Your account is not verified yet. We have sent a confirmation link to your email, or you can activate instantly using the 6-digit code below.'
          );
          return;
        }
        throw error;
      }

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

    const cleanEmail = email.trim().toLowerCase();
    const isValidDomain = cleanEmail.endsWith('@uet.edu.pk') || cleanEmail.endsWith('@student.uet.edu.pk');
    if (!isValidDomain) {
      setErrorMsg('Please use an official UET student email address (ending with @uet.edu.pk or @student.uet.edu.pk)');
      setLoading(false);
      return;
    }

    try {
      // 1. Register student in DB (stores metadata & generates 6-digit OTP in public.student_email_verifications)
      const { data: regData, error: regErr } = await supabase.rpc('register_student_account', {
        p_email: cleanEmail,
        p_password: password,
        p_full_name: fullName.trim(),
        p_roll_number: rollNumber.trim().toUpperCase(),
        p_department: department,
        p_semester: Number(semester),
      });

      if (regErr) {
        if (regErr.message && regErr.message.includes('already exists')) {
          setErrorMsg('An account with this email already exists. Please Sign In.');
          setLoading(false);
          return;
        }
        throw regErr;
      }

      // Try optional outbound confirmation email via Supabase GoTrue resend
      try {
        const redirectUrl = window.location.origin + window.location.pathname;
        await supabase.auth.resend({
          type: 'signup',
          email: cleanEmail,
          options: { emailRedirectTo: redirectUrl },
        });
      } catch (mailErr) {
        console.warn('Mail dispatch note:', mailErr);
      }

      // STRICT VERIFICATION: DO NOT LOG IN YET.
      // Transition immediately to the verification step
      setPendingVerificationEmail(cleanEmail);
      setPendingPassword(password);
      if (regData?.otp_code) {
        setCampusOtpPreview(regData.otp_code);
      }
      setOtpCode('');
      setResendCountdown(60);
      setMode('verify_otp');

      showToast('Registration initiated! Enter your 6-digit verification code below to activate your account.', 'info');
    } catch (err: any) {
      console.error('Sign up error:', err);
      setErrorMsg(err.message || 'Failed to create student account.');
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOtp = async (codeToVerify?: string) => {
    const activeCode = (codeToVerify || otpCode).trim();
    if (!activeCode || activeCode.length !== 6) {
      setErrorMsg('Please enter a valid 6-digit verification code.');
      return;
    }

    setLoading(true);
    setErrorMsg(null);

    try {
      // 1. Verify OTP and confirm user in auth.users
      const { data: vData, error: vErr } = await supabase.rpc('verify_student_email_otp', {
        p_email: pendingVerificationEmail,
        p_otp: activeCode,
      });

      if (vErr) throw vErr;

      // 2. Now that user is confirmed, sign in to establish real authenticated JWT session
      if (pendingPassword) {
        const { data: loginData, error: loginErr } = await supabase.auth.signInWithPassword({
          email: pendingVerificationEmail,
          password: pendingPassword,
        });

        if (!loginErr && loginData?.user) {
          // Retrieve verified student profile
          const { data: profileData } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', loginData.user.id)
            .single();

          const profile: Profile = profileData || {
            id: loginData.user.id,
            email: pendingVerificationEmail,
            full_name: fullName || 'UET Student',
            roll_number: rollNumber || 'N/A',
            department,
            semester,
            is_system_admin: false,
          };

          showToast(`Account verified & activated! Welcome, ${profile.full_name}!`, 'success');
          onAuthSuccess(profile);
          onClose();
          return;
        }
      }

      // If pendingPassword was not in memory or signInWithPassword needs manual password,
      // OTP verification already succeeded! Guide student smoothly to Sign In.
      showToast('Email verified successfully! Please enter your password to sign in.', 'success');
      setEmail(pendingVerificationEmail);
      setPassword('');
      setMode('signin');
    } catch (err: any) {
      console.error('OTP verification error:', err);
      setErrorMsg(err.message || 'Incorrect or expired verification code. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleResendOtp = async () => {
    if (resendCountdown > 0 || !pendingVerificationEmail) return;
    setLoading(true);
    setErrorMsg(null);
    try {
      const redirectUrl = window.location.origin + window.location.pathname;

      // 1. Generate fresh 6-digit OTP in database
      const { data, error } = await supabase.rpc('request_email_verification_otp', {
        p_email: pendingVerificationEmail,
      });
      if (error) throw error;
      if (data?.otp_code) {
        setCampusOtpPreview(data.otp_code);
      }

      // 2. Trigger outbound confirmation email via Supabase
      try {
        await supabase.auth.resend({
          type: 'signup',
          email: pendingVerificationEmail,
          options: { emailRedirectTo: redirectUrl },
        });
      } catch (mailErr) {
        console.warn('Resend mail note:', mailErr);
      }

      setResendCountdown(60);
      showToast('A fresh confirmation link & activation code have been generated.', 'success');
    } catch (err: any) {
      setErrorMsg(err.message || 'Could not resend code. Please try again.');
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
                {mode === 'verify_otp'
                  ? 'Verify Institutional Email'
                  : mode === 'signin'
                  ? 'Sign In to Student Portal'
                  : 'Create Student Account'}
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

            {/* Mode Selector Tabs (only shown on signin/signup, hidden during verification) */}
            {mode !== 'verify_otp' && (
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
            )}

            {/* Forms */}
            {mode === 'verify_otp' ? (
              <form onSubmit={(e) => { e.preventDefault(); handleVerifyOtp(); }} className="space-y-4">
                <div className="text-center space-y-2">
                  <div className="w-12 h-12 bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 rounded-full flex items-center justify-center mx-auto mb-1">
                    <ShieldCheck className="w-6 h-6" />
                  </div>
                  <h4 className="text-sm font-semibold text-white">Choose Your Verification Method</h4>
                  <div className="bg-slate-950 border border-slate-800 rounded-xl p-3 text-left space-y-1.5 text-xs text-slate-300">
                    <div className="flex items-start gap-2">
                      <span className="font-bold text-emerald-400">1.</span>
                      <span>
                        <strong>Via Email Link:</strong> Check your inbox for{' '}
                        <span className="text-emerald-400 font-mono">{pendingVerificationEmail}</span> and click{' '}
                        <span className="text-white font-medium">"Confirm your mail"</span> (also check Spam/Junk).
                      </span>
                    </div>
                    <div className="flex items-start gap-2">
                      <span className="font-bold text-emerald-400">2.</span>
                      <span>
                        <strong>Instant Activation:</strong> Use the 6-digit institutional code below to activate immediately without waiting for mail delivery.
                      </span>
                    </div>
                  </div>
                </div>

                {/* Campus Verification Instant Assistant */}
                {campusOtpPreview && (
                  <div className="p-3 bg-emerald-950/40 border border-emerald-500/50 rounded-xl flex items-center justify-between">
                    <div>
                      <div className="text-[10px] uppercase font-bold text-emerald-400 tracking-wider flex items-center gap-1.5">
                        <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
                        Institutional Activation Code
                      </div>
                      <div className="text-2xl font-mono font-bold text-white tracking-widest mt-0.5">
                        {campusOtpPreview}
                      </div>
                      <div className="text-[10px] text-slate-400">
                        Valid for 30 minutes • Instant access
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => {
                        setOtpCode(campusOtpPreview);
                        handleVerifyOtp(campusOtpPreview);
                      }}
                      className="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold rounded-lg transition shadow-md shadow-emerald-950"
                    >
                      Autofill & Verify
                    </button>
                  </div>
                )}

                <div>
                  <label className="text-xs font-medium text-slate-300 mb-1.5 block">
                    6-Digit Verification Code
                  </label>
                  <input
                    type="text"
                    required
                    maxLength={6}
                    autoFocus
                    placeholder="123456"
                    value={otpCode}
                    onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, ''))}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-3 text-center text-xl text-white tracking-[0.5em] font-mono placeholder-slate-600 focus:outline-none focus:border-emerald-500"
                  />
                </div>

                <button
                  type="submit"
                  disabled={loading || otpCode.length !== 6}
                  className="w-full py-2.5 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white text-xs font-semibold rounded-xl transition flex items-center justify-center gap-2 shadow-lg shadow-emerald-900/30"
                >
                  <CheckCircle2 className="w-4 h-4" /> {loading ? 'Activating Account...' : 'Verify & Activate Account'}
                </button>

                <div className="flex items-center justify-between text-xs pt-1">
                  <button
                    type="button"
                    onClick={() => {
                      setMode('signin');
                      setErrorMsg(null);
                    }}
                    className="text-slate-400 hover:text-white flex items-center gap-1 transition"
                  >
                    <ArrowLeft className="w-3.5 h-3.5" /> Back to Sign In
                  </button>

                  <button
                    type="button"
                    onClick={handleResendOtp}
                    disabled={resendCountdown > 0 || loading}
                    className="text-emerald-400 hover:text-emerald-300 disabled:text-slate-600 flex items-center gap-1 transition font-medium"
                  >
                    <RotateCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
                    {resendCountdown > 0 ? `Resend email in ${resendCountdown}s` : 'Resend Email / Code'}
                  </button>
                </div>
              </form>
            ) : mode === 'signin' ? (
              <form onSubmit={handleSignIn} className="space-y-4">
                <div>
                  <label className="text-xs font-medium text-slate-300 mb-1 block">
                    Student Email (@uet.edu.pk or @student.uet.edu.pk)
                  </label>
                  <div className="relative">
                    <Mail className="w-4 h-4 text-slate-500 absolute left-3 top-3" />
                    <input
                      type="email"
                      required
                      placeholder="student@student.uet.edu.pk"
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
                    Student Email (@uet.edu.pk or @student.uet.edu.pk)
                  </label>
                  <input
                    type="email"
                    required
                    placeholder="2024cs45@student.uet.edu.pk"
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
                  <UserPlus className="w-4 h-4" /> {loading ? 'Registering...' : 'Register Student & Get Code'}
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
