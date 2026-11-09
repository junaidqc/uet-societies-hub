import React, { useState, useEffect } from 'react';
import {
  User,
  X,
  Mail,
  Hash,
  Building,
  GraduationCap,
  Briefcase,
  Shield,
  Save,
  CheckCircle,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { Profile, Application } from '../types';

interface ProfileModalProps {
  isOpen: boolean;
  onClose: () => void;
  currentUser: Profile | null;
  onProfileUpdated: (updated: Profile) => void;
}

export const ProfileModal: React.FC<ProfileModalProps> = ({
  isOpen,
  onClose,
  currentUser,
  onProfileUpdated,
}) => {
  const [bio, setBio] = useState('');
  const [phone, setPhone] = useState('');
  const [applications, setApplications] = useState<Application[]>([]);
  const [saving, setSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);

  useEffect(() => {
    if (currentUser) {
      setBio(currentUser.bio || '');
      setPhone(currentUser.phone_number || '');

      // Fetch student applications
      supabase
        .from('applications')
        .select(`
          *,
          hiring:hirings(*, society:societies(*))
        `)
        .eq('user_id', currentUser.id)
        .then(({ data }) => {
          setApplications(data || []);
        });
    }
  }, [currentUser]);

  if (!isOpen || !currentUser) return null;

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      const { data, error } = await supabase
        .from('profiles')
        .update({
          bio: bio.trim(),
          phone_number: phone.trim(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', currentUser.id)
        .select()
        .single();

      if (error) throw error;
      onProfileUpdated(data);
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 2000);
    } catch (err: any) {
      alert(err.message || 'Failed to update profile');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-md animate-fadeIn">
      <div className="bg-slate-900 border border-slate-700/80 rounded-3xl w-full max-w-lg shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="relative p-6 border-b border-slate-800 bg-gradient-to-r from-slate-950 via-slate-900 to-slate-950 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-emerald-500/20 to-teal-500/20 border border-emerald-500/30 flex items-center justify-center font-bold text-emerald-400 text-xl shadow-lg">
              {currentUser.full_name?.charAt(0) || 'U'}
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-base font-bold text-white">{currentUser.full_name}</h3>
                {currentUser.is_system_admin && (
                  <span className="inline-flex items-center gap-1 text-[10px] font-semibold text-emerald-400 bg-emerald-950/60 border border-emerald-500/30 px-2 py-0.5 rounded-full">
                    <Shield className="w-3 h-3" /> Admin
                  </span>
                )}
              </div>
              <p className="text-xs font-mono text-emerald-400">{currentUser.roll_number}</p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="text-slate-400 hover:text-white p-1.5 rounded-lg hover:bg-slate-800 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6 space-y-6">
          {/* Academic Info */}
          <div className="grid grid-cols-2 gap-3 p-3.5 bg-slate-950 rounded-2xl border border-slate-800 text-xs">
            <div>
              <span className="text-slate-500">Department</span>
              <p className="font-semibold text-white mt-0.5">{currentUser.department}</p>
            </div>
            <div>
              <span className="text-slate-500">Semester</span>
              <p className="font-semibold text-white mt-0.5">Semester {currentUser.semester}</p>
            </div>
            <div>
              <span className="text-slate-500">Official Student Email</span>
              <p className="font-mono text-emerald-400 mt-0.5 truncate">{currentUser.email}</p>
            </div>
            <div>
              <span className="text-slate-500">Account Type</span>
              <p className="font-medium text-white mt-0.5">Verified Student</p>
            </div>
          </div>

          {/* Form to update contact and bio */}
          <form onSubmit={handleSave} className="space-y-4 text-xs">
            <div>
              <label className="text-slate-300 font-medium block mb-1">Contact Phone Number</label>
              <input
                type="text"
                placeholder="+92 300 1234567"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
              />
            </div>

            <div>
              <label className="text-slate-300 font-medium block mb-1">Student Bio / Interests</label>
              <textarea
                rows={2}
                placeholder="Software engineering enthusiast, competitive debater, web lead..."
                value={bio}
                onChange={(e) => setBio(e.target.value)}
                className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500 resize-none"
              />
            </div>

            <div className="flex items-center justify-between pt-1">
              {saveSuccess && (
                <span className="text-emerald-400 flex items-center gap-1 font-semibold">
                  <CheckCircle className="w-3.5 h-3.5" /> Profile Updated!
                </span>
              )}
              <div className="ml-auto">
                <button
                  type="submit"
                  disabled={saving}
                  className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white font-semibold rounded-xl flex items-center gap-1.5 shadow-md shadow-emerald-900/30 transition"
                >
                  <Save className="w-3.5 h-3.5" />
                  <span>{saving ? 'Saving...' : 'Save Profile'}</span>
                </button>
              </div>
            </div>
          </form>

          {/* Submitted Applications History */}
          <div className="pt-2 border-t border-slate-800">
            <h4 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3 flex items-center gap-1.5">
              <Briefcase className="w-3.5 h-3.5 text-emerald-400" /> My Society Applications (
              {applications.length})
            </h4>

            {applications.length > 0 ? (
              <div className="space-y-2.5">
                {applications.map((app) => (
                  <div
                    key={app.id}
                    className="p-3 bg-slate-950 border border-slate-800 rounded-2xl flex items-center justify-between text-xs"
                  >
                    <div>
                      <p className="font-bold text-white">{app.position}</p>
                      <p className="text-[11px] text-slate-400">
                        {app.hiring?.society?.name || 'Society Hub'} &bull;{' '}
                        {new Date(app.created_at).toLocaleDateString()}
                      </p>
                    </div>

                    <span
                      className={`text-[10px] font-semibold uppercase px-2.5 py-1 rounded-full border ${
                        app.status === 'accepted'
                          ? 'bg-emerald-950 text-emerald-400 border-emerald-500/40'
                          : app.status === 'shortlisted'
                          ? 'bg-blue-950 text-blue-400 border-blue-500/40'
                          : 'bg-slate-900 text-amber-300 border-amber-500/30'
                      }`}
                    >
                      {app.status}
                    </span>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-xs text-slate-500 italic">No applications submitted yet.</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
