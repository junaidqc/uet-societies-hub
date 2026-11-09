import React, { useState } from 'react';
import { X, Calendar, MapPin, CheckCircle, Clock, Send, Users, Shield } from 'lucide-react';
import { Event, Profile } from '../types';
import { supabase } from '../lib/supabase';
import { useToast } from './Toast';

interface EventRegistrationModalProps {
  isOpen: boolean;
  onClose: () => void;
  event: Event | null;
  currentUser: Profile | null;
  onRequireAuth: () => void;
  onRegisteredSuccess?: () => void;
}

export const EventRegistrationModal: React.FC<EventRegistrationModalProps> = ({
  isOpen,
  onClose,
  event,
  currentUser,
  onRequireAuth,
  onRegisteredSuccess,
}) => {
  const { showToast } = useToast();
  const [teamName, setTeamName] = useState('');
  const [participantType, setParticipantType] = useState<'individual' | 'team'>('individual');
  const [dietaryOrNotes, setDietaryOrNotes] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);

  if (!isOpen || !event) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!currentUser) {
      onRequireAuth();
      return;
    }

    setSubmitting(true);
    try {
      // Upsert into event_interests
      const { error } = await supabase.from('event_interests').upsert(
        {
          event_id: event.id,
          user_id: currentUser.id,
          status: 'going',
        },
        { onConflict: 'event_id,user_id' }
      );

      if (error) {
        console.warn('Supabase event_interest error:', error);
      }

      setSuccess(true);
      showToast(`Successfully registered for ${event.title}!`, 'success');
      if (onRegisteredSuccess) onRegisteredSuccess();
    } catch (err: any) {
      console.error('Registration failed:', err);
      showToast(err.message || 'Registration failed. Please try again.', 'error');
    } finally {
      setSubmitting(false);
    }
  };

  const startDate = new Date(event.start_time).toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-fadeIn">
      <div className="bg-slate-900 border border-slate-700/80 rounded-3xl w-full max-w-lg shadow-2xl overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 bg-slate-950/40">
          <div>
            <span className="text-[10px] font-semibold uppercase tracking-wider text-emerald-400">
              Campus Event Registration
            </span>
            <h3 className="font-bold text-white text-base leading-snug truncate max-w-sm">
              {event.title}
            </h3>
          </div>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-white p-1.5 rounded-lg hover:bg-slate-800 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {success ? (
          <div className="p-8 text-center space-y-4">
            <div className="w-16 h-16 rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 flex items-center justify-center mx-auto">
              <CheckCircle className="w-9 h-9" />
            </div>
            <h4 className="text-lg font-bold text-white">Registration Confirmed!</h4>
            <p className="text-xs text-slate-300 max-w-sm mx-auto leading-relaxed">
              You are officially registered for <span className="text-emerald-400 font-semibold">{event.title}</span> organized by{' '}
              <span className="text-white font-medium">{event.society?.name || 'UET Campus'}</span>.
            </p>
            <div className="p-3 bg-slate-950 border border-slate-800 rounded-2xl text-[11px] text-slate-400 space-y-1">
              <p><strong className="text-slate-200">Venue:</strong> {event.venue}</p>
              <p><strong className="text-slate-200">Date & Time:</strong> {startDate}</p>
            </div>
            <button
              onClick={() => {
                setSuccess(false);
                onClose();
              }}
              className="px-6 py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold rounded-xl shadow-lg transition"
            >
              Done
            </button>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="p-6 space-y-4 text-xs">
            {/* Event Summary Card */}
            <div className="bg-slate-950/80 border border-slate-800 rounded-2xl p-4 space-y-2">
              <div className="flex items-center justify-between text-slate-400">
                <span className="flex items-center gap-1.5">
                  <Clock className="w-3.5 h-3.5 text-emerald-400" />
                  <span>{startDate}</span>
                </span>
                <span className="text-emerald-400 font-medium">{event.society?.name}</span>
              </div>
              <div className="flex items-center gap-1.5 text-slate-400">
                <MapPin className="w-3.5 h-3.5 text-slate-500 shrink-0" />
                <span className="truncate">{event.venue}</span>
              </div>
            </div>

            {/* Applicant Details */}
            {currentUser ? (
              <div className="p-3 bg-slate-950 rounded-2xl border border-slate-800 grid grid-cols-2 gap-2 text-[11px]">
                <div>
                  <span className="text-slate-500">Applicant:</span>
                  <p className="font-medium text-white">{currentUser.full_name}</p>
                </div>
                <div>
                  <span className="text-slate-500">Roll Number:</span>
                  <p className="font-mono text-emerald-400">{currentUser.roll_number}</p>
                </div>
                <div>
                  <span className="text-slate-500">Department:</span>
                  <p className="text-slate-300">{currentUser.department}</p>
                </div>
                <div>
                  <span className="text-slate-500">Student Email:</span>
                  <p className="font-mono text-slate-300 truncate">{currentUser.email}</p>
                </div>
              </div>
            ) : (
              <div className="p-3.5 bg-amber-950/40 border border-amber-500/40 rounded-2xl text-amber-300 flex items-center justify-between">
                <span>Sign in with student ID to register.</span>
                <button
                  type="button"
                  onClick={onRequireAuth}
                  className="px-3 py-1 bg-amber-600 text-white font-semibold rounded-lg text-[11px]"
                >
                  Sign In
                </button>
              </div>
            )}

            {/* Participation Type */}
            <div>
              <label className="text-slate-300 font-medium block mb-1.5">Participation Type</label>
              <div className="grid grid-cols-2 gap-2">
                <button
                  type="button"
                  onClick={() => setParticipantType('individual')}
                  className={`py-2 px-3 rounded-xl border text-center transition ${
                    participantType === 'individual'
                      ? 'bg-emerald-600/20 border-emerald-500/50 text-emerald-300 font-semibold'
                      : 'bg-slate-950 border-slate-800 text-slate-400'
                  }`}
                >
                  Solo / Individual
                </button>
                <button
                  type="button"
                  onClick={() => setParticipantType('team')}
                  className={`py-2 px-3 rounded-xl border text-center transition ${
                    participantType === 'team'
                      ? 'bg-emerald-600/20 border-emerald-500/50 text-emerald-300 font-semibold'
                      : 'bg-slate-950 border-slate-800 text-slate-400'
                  }`}
                >
                  Team Delegate
                </button>
              </div>
            </div>

            {participantType === 'team' && (
              <div>
                <label className="text-slate-300 font-medium block mb-1">
                  Team Name / Squad Identifier
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. ByteCraft UET"
                  value={teamName}
                  onChange={(e) => setTeamName(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                />
              </div>
            )}

            <div>
              <label className="text-slate-300 font-medium block mb-1">
                Special Requests or Notes (Optional)
              </label>
              <input
                type="text"
                placeholder="e.g. Dietary preference, hardware requirements, etc."
                value={dietaryOrNotes}
                onChange={(e) => setDietaryOrNotes(e.target.value)}
                className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
              />
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={onClose}
                className="px-4 py-2 rounded-xl text-slate-400 hover:text-white"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={submitting || !currentUser}
                className="px-5 py-2 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white font-semibold rounded-xl shadow-md transition flex items-center gap-1.5"
              >
                <Send className="w-3.5 h-3.5" />
                <span>{submitting ? 'Registering...' : 'Confirm Registration'}</span>
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};
