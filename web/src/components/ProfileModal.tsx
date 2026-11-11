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
import { useToast } from './Toast';
import { Modal } from './common/Modal';

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
  const { showToast } = useToast();
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
      showToast('Profile updated successfully!', 'success');
      setTimeout(() => setSaveSuccess(false), 2000);
    } catch (err: any) {
      // DEF-17 Fix: Use showToast instead of raw browser alert()
      showToast(err.message || 'Failed to update profile', 'error');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Student Profile & Applications"
      description={`Official Academic Record • ${currentUser.roll_number}`}
      maxWidth="max-w-lg"
    >
      <div className="p-6 space-y-6 text-xs max-h-[80vh] overflow-y-auto">
        {/* User Card */}
        <div className="flex items-center gap-4 p-4 rounded-2xl bg-slate-950 border border-slate-800">
          <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-emerald-500/20 to-teal-500/20 border border-emerald-500/30 flex items-center justify-center font-bold text-emerald-400 text-xl shadow-lg shrink-0">
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
            <p className="text-[11px] text-slate-400">{currentUser.department}</p>
          </div>
        </div>

        {/* Academic Details Grid */}
        <div className="grid grid-cols-2 gap-3 p-3.5 bg-slate-950/70 rounded-2xl border border-slate-800 text-[11px]">
          <div>
            <span className="text-slate-500">Official Student Email</span>
            <p className="font-mono text-emerald-400 mt-0.5 truncate">{currentUser.email}</p>
          </div>
          <div>
            <span className="text-slate-500">Semester Standing</span>
            <p className="font-semibold text-white mt-0.5">Semester {currentUser.semester}</p>
          </div>
          <div>
            <span className="text-slate-500">Campus Status</span>
            <p className="font-semibold text-emerald-400 mt-0.5">Enrolled / Active</p>
          </div>
          <div>
            <span className="text-slate-500">Council Placements</span>
            <p className="font-semibold text-white mt-0.5">{applications.length} Submissions</p>
          </div>
        </div>

        {/* Profile Edit Form */}
        <form onSubmit={handleSave} className="space-y-4">
          <div>
            <label htmlFor="student-phone" className="text-slate-300 font-medium block mb-1">
              Contact Phone Number (SMS / WhatsApp)
            </label>
            <input
              id="student-phone"
              type="text"
              placeholder="+92 300 1234567"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
            />
          </div>

          <div>
            <label htmlFor="student-bio" className="text-slate-300 font-medium block mb-1">
              Student Bio & Technical Interests
            </label>
            <textarea
              id="student-bio"
              rows={3}
              placeholder="e.g. Competitive programming, embedded hardware, robotics, declamations..."
              value={bio}
              onChange={(e) => setBio(e.target.value)}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500 resize-none"
            />
          </div>

          <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
            <button
              type="submit"
              disabled={saving}
              className="flex items-center gap-1.5 px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold rounded-xl shadow-md transition cursor-pointer"
            >
              {saveSuccess ? (
                <>
                  <CheckCircle className="w-3.5 h-3.5" />
                  <span>Saved!</span>
                </>
              ) : (
                <>
                  <Save className="w-3.5 h-3.5" />
                  <span>{saving ? 'Saving...' : 'Save Profile'}</span>
                </>
              )}
            </button>
          </div>
        </form>

        {/* My Applications History */}
        {applications.length > 0 && (
          <div className="space-y-3 pt-3 border-t border-slate-800">
            <h4 className="font-bold text-white text-xs uppercase tracking-wider flex items-center gap-1.5">
              <Briefcase className="w-3.5 h-3.5 text-emerald-400" /> Submitted Applications History
            </h4>
            <div className="space-y-2">
              {applications.map((app) => (
                <div
                  key={app.id}
                  className="p-3 rounded-xl bg-slate-950 border border-slate-800/80 flex items-center justify-between"
                >
                  <div>
                    <span className="font-semibold text-white block">{app.position}</span>
                    <span className="text-[11px] text-slate-400">
                      {app.hiring?.society?.name || 'Society Directorate'}
                    </span>
                  </div>
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-mono capitalize bg-emerald-950/60 text-emerald-400 border border-emerald-500/30">
                    {app.status}
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </Modal>
  );
};
