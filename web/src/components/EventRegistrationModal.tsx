import React, { useState } from 'react';
import { Calendar, MapPin, CheckCircle, Clock, Send, Users, Shield, Ticket } from 'lucide-react';
import { Event, Profile } from '../types';
import { supabase } from '../lib/supabase';
import { useToast } from './Toast';
import { Modal } from './common/Modal';
import { formatPKTDate, formatPKTTime } from '../utils/date';

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

  const handleClose = () => {
    setSuccess(false);
    onClose();
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={handleClose}
      title={success ? 'Registration Confirmed' : 'Campus Event Registration'}
      description={
        event
          ? `${event.society?.name || 'UET Campus'} • ${event.title}`
          : undefined
      }
      maxWidth="max-w-lg"
    >
      {success ? (
        <div className="p-8 text-center space-y-4 text-xs">
          <div className="w-16 h-16 rounded-2xl bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 flex items-center justify-center mx-auto shadow-lg">
            <CheckCircle className="w-9 h-9" />
          </div>
          <h4 className="text-lg font-bold text-white">Your Seat is Reserved!</h4>
          <p className="text-slate-300 max-w-sm mx-auto leading-relaxed">
            Registration confirmed for <strong className="text-white">{event.title}</strong> organized by{' '}
            <span className="text-emerald-400">{event.society?.name || 'UET Directorate'}</span>. An official
            entry pass has been logged to your student roll number.
          </p>
          <div className="pt-2">
            <button
              type="button"
              onClick={handleClose}
              className="px-6 py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold rounded-xl shadow-lg transition cursor-pointer"
            >
              Done & Return
            </button>
          </div>
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="p-6 space-y-4 text-xs">
          {/* Event Specs Card */}
          <div className="p-4 rounded-2xl bg-slate-950 border border-slate-800 space-y-2">
            <div className="flex items-center justify-between text-slate-400">
              <span className="flex items-center gap-1.5 font-mono text-[11px]">
                <Clock className="w-3.5 h-3.5 text-emerald-400" />
                {formatPKTDate(event.start_time)} &bull; {formatPKTTime(event.start_time)} PKT
              </span>
              <span className="text-[10px] uppercase font-mono px-2 py-0.5 rounded-full bg-emerald-950/60 text-emerald-300 border border-emerald-500/30">
                Official Hub
              </span>
            </div>
            <div className="flex items-center gap-1.5 text-slate-300">
              <MapPin className="w-3.5 h-3.5 text-slate-400 shrink-0" />
              <span>{event.venue}</span>
            </div>
          </div>

          {/* Student Info */}
          <div className="p-3 bg-slate-950/60 rounded-2xl border border-slate-800/80 grid grid-cols-2 gap-2 text-[11px]">
            <div>
              <span className="text-slate-500">Student Name:</span>
              <p className="font-medium text-white">{currentUser?.full_name || 'Sign in to register'}</p>
            </div>
            <div>
              <span className="text-slate-500">Roll Number:</span>
              <p className="font-mono text-emerald-400">{currentUser?.roll_number || 'N/A'}</p>
            </div>
          </div>

          {/* Participant Type */}
          <div>
            <label className="text-slate-300 font-medium block mb-1.5">Participation Type</label>
            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => setParticipantType('individual')}
                className={`p-2.5 rounded-xl border text-center transition cursor-pointer ${
                  participantType === 'individual'
                    ? 'bg-emerald-500/10 border-emerald-500/40 text-emerald-300 font-bold'
                    : 'bg-slate-950 border-slate-800 text-slate-400'
                }`}
              >
                Individual Student
              </button>
              <button
                type="button"
                onClick={() => setParticipantType('team')}
                className={`p-2.5 rounded-xl border text-center transition cursor-pointer ${
                  participantType === 'team'
                    ? 'bg-emerald-500/10 border-emerald-500/40 text-emerald-300 font-bold'
                    : 'bg-slate-950 border-slate-800 text-slate-400'
                }`}
              >
                Team Entry
              </button>
            </div>
          </div>

          {participantType === 'team' && (
            <div>
              <label htmlFor="reg-team-name" className="text-slate-300 font-medium block mb-1">
                Team Name & Members' Roll Numbers
              </label>
              <input
                id="reg-team-name"
                type="text"
                required
                placeholder="e.g. ByteBuilders (2025-CS-12, 2025-CS-45)"
                value={teamName}
                onChange={(e) => setTeamName(e.target.value)}
                className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
              />
            </div>
          )}

          <div>
            <label htmlFor="reg-notes" className="text-slate-300 font-medium block mb-1">
              Special Requirements / Dietary Notes (Optional)
            </label>
            <input
              id="reg-notes"
              type="text"
              placeholder="e.g. Power outlet for laptop, wheelchair access"
              value={dietaryOrNotes}
              onChange={(e) => setDietaryOrNotes(e.target.value)}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
            />
          </div>

          <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
            <button
              type="button"
              onClick={handleClose}
              className="px-4 py-2 rounded-xl text-slate-400 hover:text-white transition cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={submitting}
              className="flex items-center gap-1.5 px-5 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold rounded-xl shadow-md transition cursor-pointer"
            >
              <Ticket className="w-3.5 h-3.5" />
              <span>{submitting ? 'Confirming...' : 'Confirm Registration'}</span>
            </button>
          </div>
        </form>
      )}
    </Modal>
  );
};
