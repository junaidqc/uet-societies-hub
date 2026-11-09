import React, { useState, useEffect } from 'react';
import {
  Briefcase,
  CheckCircle,
  X,
  Send,
  FileCheck,
  Link as LinkIcon,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { Hiring, Profile, Application } from '../types';
import { useToast } from './Toast';

interface HiringSectionProps {
  currentUser: Profile | null;
  onRequireAuth: () => void;
  selectedHiringForApply?: Hiring | null;
  onClearSelectedHiring?: () => void;
  cachedHirings?: Hiring[];
  onCacheHirings?: (hirings: Hiring[]) => void;
}

export const HiringSection: React.FC<HiringSectionProps> = ({
  currentUser,
  onRequireAuth,
  selectedHiringForApply,
  onClearSelectedHiring,
  cachedHirings = [],
  onCacheHirings,
}) => {
  const { showToast } = useToast();
  const [hirings, setHirings] = useState<Hiring[]>(cachedHirings);
  const [loading, setLoading] = useState(cachedHirings.length === 0);

  // Application Modal state
  const [activeHiring, setActiveHiring] = useState<Hiring | null>(null);
  const [selectedPosition, setSelectedPosition] = useState('');
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [resumeLink, setResumeLink] = useState('');
  const [portfolioLink, setPortfolioLink] = useState('');
  const [submittingApp, setSubmittingApp] = useState(false);
  const [appliedSuccess, setAppliedSuccess] = useState(false);
  const [confirmedSocietyName, setConfirmedSocietyName] = useState('');

  // Saved user applications
  const [myApplications, setMyApplications] = useState<Application[]>([]);

  const fetchHirings = async () => {
    if (hirings.length === 0) setLoading(true);
    try {
      const { data, error } = await supabase
        .from('hirings')
        .select(`
          *,
          society:societies(*)
        `)
        .eq('status', 'open')
        .order('deadline', { ascending: true });

      if (error) throw error;
      const processed = data || [];
      setHirings(processed);

      if (onCacheHirings) {
        onCacheHirings(processed);
      }

      if (currentUser) {
        const { data: appData } = await supabase
          .from('applications')
          .select('*, hiring:hirings(*)')
          .eq('user_id', currentUser.id);
        setMyApplications(appData || []);
      }
    } catch (err) {
      console.error('Error fetching hirings:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchHirings();
  }, [currentUser]);

  useEffect(() => {
    if (selectedHiringForApply) {
      handleOpenApply(selectedHiringForApply);
    }
  }, [selectedHiringForApply]);

  const handleOpenApply = (hiring: Hiring) => {
    if (!currentUser) {
      onRequireAuth();
      return;
    }
    setActiveHiring(hiring);
    setSelectedPosition(hiring.positions[0] || 'General Member');
    setAnswers({});
    setResumeLink('');
    setPortfolioLink('');
    setAppliedSuccess(false);

    // BUG-05 fix: preserve society name upfront
    const sName = hiring.society?.name || 'the Society Executive Council';
    setConfirmedSocietyName(sName);
  };

  const handleCloseModal = () => {
    setActiveHiring(null);
    setAppliedSuccess(false);
    if (onClearSelectedHiring) onClearSelectedHiring();
  };

  const handleSubmitApplication = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!activeHiring || !currentUser) return;

    if (!resumeLink.trim()) {
      showToast('Please provide your Resume / CV Link.', 'error');
      return;
    }

    setSubmittingApp(true);
    const targetSociety = activeHiring.society?.name || confirmedSocietyName || 'the Society Directorate';
    setConfirmedSocietyName(targetSociety);

    try {
      const payload = {
        hiring_id: activeHiring.id,
        user_id: currentUser.id,
        position: selectedPosition,
        status: 'submitted',
        answers: {
          ...answers,
          resume_url: resumeLink.trim(),
          portfolio_url: portfolioLink.trim() || undefined,
          applicant_name: currentUser.full_name,
          roll_number: currentUser.roll_number,
          department: currentUser.department,
        },
        resume_url: resumeLink.trim() || null,
      };

      const { error } = await supabase
        .from('applications')
        .insert(payload);

      if (error) throw error;

      setAppliedSuccess(true);
      showToast(`Application for ${selectedPosition} submitted to ${targetSociety}!`, 'success');
      fetchHirings();
    } catch (err: any) {
      console.error('Application submit error:', err);
      showToast(err.message || 'Failed to submit application.', 'error');
    } finally {
      setSubmittingApp(false);
    }
  };

  // BUG-09: Filter out custom questions that duplicate resume/portfolio links
  const relevantCustomQuestions = (activeHiring?.custom_questions || []).filter((q) => {
    const qLower = q.question.toLowerCase();
    return !(
      qLower.includes('github') ||
      qLower.includes('portfolio') ||
      qLower.includes('resume') ||
      qLower.includes('cv') ||
      qLower.includes('behance')
    );
  });

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Header Banner */}
      <div className="bg-gradient-to-r from-emerald-950/40 via-slate-900 to-teal-950/40 border border-slate-800 rounded-3xl p-6 sm:p-8 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6 shadow-xl">
        <div className="space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-xs font-semibold">
            <Briefcase className="w-3.5 h-3.5" /> UET Campus Recruitment Portal
          </div>
          <h2 className="text-xl sm:text-2xl font-extrabold text-white">
            Lead, Build & Innovate in Student Councils
          </h2>
          <p className="text-xs sm:text-sm text-slate-300 max-w-xl leading-relaxed">
            Directly apply to executive bodies, technical developer councils, media directorates,
            and event operations teams across official university societies.
          </p>
        </div>

        {/* Quick Student Stats */}
        {currentUser && (
          <div className="bg-slate-950/80 border border-slate-800 rounded-2xl p-4 shrink-0 text-xs space-y-1">
            <span className="text-slate-400">Your Active Applications:</span>
            <p className="text-lg font-bold text-emerald-400">{myApplications.length}</p>
            <span className="text-[10px] text-slate-500 font-mono">
              Roll: {currentUser.roll_number}
            </span>
          </div>
        )}
      </div>

      {/* Hirings List (BUG-08: rich skeleton wireframes) */}
      {loading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {[1, 2, 3, 4].map((i) => (
            <div
              key={i}
              className="bg-slate-900/80 border border-slate-800 rounded-3xl p-6 space-y-4 animate-pulse"
            >
              <div className="flex justify-between items-start">
                <div className="w-10 h-10 rounded-2xl bg-slate-800" />
                <div className="w-20 h-5 rounded-full bg-slate-800" />
              </div>
              <div className="h-5 w-48 bg-slate-800 rounded" />
              <div className="space-y-2">
                <div className="h-3 w-full bg-slate-800/60 rounded" />
                <div className="h-3 w-3/4 bg-slate-800/60 rounded" />
              </div>
              <div className="pt-4 border-t border-slate-800/80 flex justify-between">
                <div className="h-4 w-24 bg-slate-800 rounded" />
                <div className="h-8 w-24 bg-slate-800 rounded-xl" />
              </div>
            </div>
          ))}
        </div>
      ) : hirings.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {hirings.map((hiring) => {
            const deadlineDate = new Date(hiring.deadline);
            const isClosingSoon =
              deadlineDate.getTime() - Date.now() < 3 * 24 * 60 * 60 * 1000;
            const hasApplied = myApplications.some((a) => a.hiring_id === hiring.id);

            return (
              <div
                key={hiring.id}
                className="bg-slate-900/80 border border-slate-800 hover:border-emerald-500/40 rounded-3xl p-6 flex flex-col justify-between shadow-xl transition"
              >
                <div>
                  {/* Society info & Deadline */}
                  <div className="flex items-start justify-between gap-3 mb-4">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-2xl bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center font-bold text-emerald-400 text-sm">
                        {hiring.society?.name?.charAt(0) || 'U'}
                      </div>
                      <div>
                        <h4 className="text-xs font-bold text-emerald-400 uppercase tracking-wider">
                          {hiring.society?.name || 'Campus Society'}
                        </h4>
                        <span className="text-[11px] text-slate-400">
                          {hiring.society?.category}
                        </span>
                      </div>
                    </div>

                    <span
                      className={`text-[11px] font-mono px-2.5 py-1 rounded-full border ${
                        isClosingSoon
                          ? 'bg-amber-950/60 text-amber-300 border-amber-500/40'
                          : 'bg-slate-950 text-slate-300 border-slate-800'
                      }`}
                    >
                      Closes {deadlineDate.toLocaleDateString()}
                    </span>
                  </div>

                  {/* Title & Description */}
                  <h3 className="text-base font-bold text-white mb-2">{hiring.title}</h3>
                  <p className="text-xs text-slate-300 line-clamp-3 leading-relaxed mb-4">
                    {hiring.description}
                  </p>

                  {/* Open Positions Badges */}
                  <div className="mb-4">
                    <span className="text-[10px] font-semibold uppercase tracking-wider text-slate-400 block mb-1.5">
                      Available Roles:
                    </span>
                    <div className="flex flex-wrap gap-1.5">
                      {(hiring.positions || []).map((pos, idx) => (
                        <span
                          key={idx}
                          className="px-2.5 py-1 rounded-lg bg-slate-950 border border-slate-800 text-[11px] font-medium text-slate-300"
                        >
                          {pos}
                        </span>
                      ))}
                    </div>
                  </div>

                  {/* Requirements & Selection */}
                  {hiring.requirements && (
                    <div className="p-3 rounded-2xl bg-slate-950/60 border border-slate-800/80 text-[11px] text-slate-400 mb-4">
                      <span className="font-semibold text-slate-300">Eligibility:</span>{' '}
                      {hiring.requirements}
                    </div>
                  )}
                </div>

                {/* Footer Apply Action */}
                <div className="pt-4 border-t border-slate-800/80 flex items-center justify-between">
                  <div className="text-xs text-slate-400">
                    <span className="text-white font-semibold">{hiring.total_seats || 12}</span>{' '}
                    Total Open Seats
                  </div>

                  {hasApplied ? (
                    <div className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-emerald-950/60 border border-emerald-500/40 text-emerald-400 text-xs font-semibold">
                      <CheckCircle className="w-3.5 h-3.5" /> Applied
                    </div>
                  ) : (
                    <button
                      type="button"
                      onClick={() => handleOpenApply(hiring)}
                      className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold rounded-xl shadow-md shadow-emerald-900/30 transition"
                    >
                      Apply Now &rarr;
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        <div className="bg-slate-900 border border-slate-800 rounded-3xl p-12 text-center">
          <p className="text-slate-400 text-sm">No open recruitment cycles right now.</p>
        </div>
      )}

      {/* Application Modal */}
      {activeHiring && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-fadeIn">
          <div className="bg-slate-900 border border-slate-700/80 rounded-3xl w-full max-w-lg shadow-2xl overflow-hidden flex flex-col">
            {/* Header */}
            <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 bg-slate-950/40">
              <div>
                <h3 className="font-bold text-white text-base">Society Application</h3>
                <p className="text-xs text-emerald-400 font-medium">
                  {confirmedSocietyName || activeHiring.society?.name || 'Campus Society'} &bull; {activeHiring.title}
                </p>
              </div>
              <button
                onClick={handleCloseModal}
                className="text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* BUG-05 Fix: confirmation string explicitly renders confirmed society name */}
            {appliedSuccess ? (
              <div className="p-8 text-center space-y-4">
                <div className="w-14 h-14 rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 flex items-center justify-center mx-auto">
                  <CheckCircle className="w-8 h-8" />
                </div>
                <h4 className="text-lg font-bold text-white">Application Submitted!</h4>
                <p className="text-xs text-slate-300 max-w-sm mx-auto leading-relaxed">
                  Your application for <span className="text-emerald-400 font-semibold">{selectedPosition}</span> has
                  been sent to <strong className="text-white font-bold">{confirmedSocietyName || activeHiring.society?.name || 'the Society Executive Council'}</strong>. You will be notified regarding interview rounds.
                </p>
                <button
                  onClick={handleCloseModal}
                  className="px-6 py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold rounded-xl"
                >
                  Done
                </button>
              </div>
            ) : (
              <form onSubmit={handleSubmitApplication} className="p-6 space-y-4 text-xs">
                {/* Candidate Summary */}
                <div className="p-3.5 bg-slate-950 rounded-2xl border border-slate-800 grid grid-cols-2 gap-2 text-[11px]">
                  <div>
                    <span className="text-slate-500">Applicant:</span>
                    <p className="font-medium text-white">{currentUser?.full_name}</p>
                  </div>
                  <div>
                    <span className="text-slate-500">Roll Number:</span>
                    <p className="font-mono font-medium text-emerald-400">
                      {currentUser?.roll_number}
                    </p>
                  </div>
                  <div>
                    <span className="text-slate-500">Department:</span>
                    <p className="text-slate-300">{currentUser?.department}</p>
                  </div>
                  <div>
                    <span className="text-slate-500">Semester:</span>
                    <p className="text-slate-300">Semester {currentUser?.semester}</p>
                  </div>
                </div>

                {/* Position Selection */}
                <div>
                  <label className="text-slate-300 font-medium block mb-1">
                    Select Role / Position You Are Applying For
                  </label>
                  <select
                    value={selectedPosition}
                    onChange={(e) => setSelectedPosition(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                  >
                    {(activeHiring.positions || []).map((pos, idx) => (
                      <option key={idx} value={pos}>
                        {pos}
                      </option>
                    ))}
                  </select>
                </div>

                {/* Non-duplicate custom questions */}
                {relevantCustomQuestions.map((q) => (
                  <div key={q.id}>
                    <label className="text-slate-300 font-medium block mb-1">
                      {q.question} {q.required && <span className="text-red-400">*</span>}
                    </label>
                    {q.type === 'textarea' ? (
                      <textarea
                        required={q.required}
                        rows={3}
                        value={answers[q.id] || ''}
                        onChange={(e) =>
                          setAnswers({ ...answers, [q.id]: e.target.value })
                        }
                        className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500 resize-none"
                      />
                    ) : (
                      <input
                        type="text"
                        required={q.required}
                        value={answers[q.id] || ''}
                        onChange={(e) =>
                          setAnswers({ ...answers, [q.id]: e.target.value })
                        }
                        className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                      />
                    )}
                  </div>
                ))}

                {/* BUG-09 Fix: Consolidate into 1 required Resume/CV link & 1 optional Portfolio link */}
                <div>
                  <label className="text-slate-300 font-medium block mb-1 flex items-center justify-between">
                    <span className="flex items-center gap-1">
                      <FileCheck className="w-3.5 h-3.5 text-emerald-400" />
                      <span>Resume / CV Document Link (Google Drive / PDF / Cloud)</span>
                    </span>
                    <span className="text-emerald-400 text-[10px]">Required</span>
                  </label>
                  <input
                    type="url"
                    required
                    placeholder="https://drive.google.com/file/d/..."
                    value={resumeLink}
                    onChange={(e) => setResumeLink(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500 font-mono"
                  />
                  <p className="text-[10px] text-slate-500 mt-1">
                    Ensure link sharing permissions are set to "Anyone with the link can view".
                  </p>
                </div>

                <div>
                  <label className="text-slate-300 font-medium block mb-1 flex items-center justify-between">
                    <span className="flex items-center gap-1">
                      <LinkIcon className="w-3.5 h-3.5 text-slate-400" />
                      <span>Portfolio / GitHub / Behance Profile Link</span>
                    </span>
                    <span className="text-slate-500 text-[10px]">Optional</span>
                  </label>
                  <input
                    type="url"
                    placeholder="https://github.com/..."
                    value={portfolioLink}
                    onChange={(e) => setPortfolioLink(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500 font-mono"
                  />
                </div>

                <div className="flex justify-end gap-2 pt-2">
                  <button
                    type="button"
                    onClick={handleCloseModal}
                    className="px-4 py-2 rounded-xl text-slate-400 hover:text-white"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={submittingApp}
                    className="px-5 py-2 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white font-semibold rounded-xl flex items-center gap-1.5 shadow-md shadow-emerald-900/30"
                  >
                    <Send className="w-3.5 h-3.5" />
                    <span>{submittingApp ? 'Submitting...' : 'Submit Application'}</span>
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
