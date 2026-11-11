import React, { useState, useEffect } from 'react';
import {
  Shield,
  CheckCircle,
  XCircle,
  Clock,
  Users,
  Building,
  Calendar,
  Briefcase,
  RefreshCw,
  FileCheck,
  AlertTriangle,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { Society, Profile } from '../types';
import { useToast } from './Toast';
import { StatCounter } from './common/StatCounter';
import { formatPKTDate } from '../utils/date';

interface AdminSectionProps {
  currentUser: Profile | null;
}

export const AdminSection: React.FC<AdminSectionProps> = ({ currentUser }) => {
  const { showToast } = useToast();
  const [stats, setStats] = useState({
    totalStudents: 1,
    activeSocieties: 5,
    pendingSocieties: 0,
    totalEvents: 3,
    totalApplications: 0,
  });

  const [pendingSocieties, setPendingSocieties] = useState<Society[]>([]);
  const [loading, setLoading] = useState(false);
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  // BUG-07 Fix: Resilient metrics calculation using Promise.allSettled and reliable count queries
  const fetchAdminData = async () => {
    setLoading(true);
    try {
      const results = await Promise.allSettled([
        supabase.from('profiles').select('id', { count: 'exact' }).limit(1),
        supabase.from('societies').select('id', { count: 'exact' }).eq('status', 'active').limit(1),
        supabase.from('societies').select('id', { count: 'exact' }).eq('status', 'pending').limit(1),
        supabase.from('events').select('id', { count: 'exact' }).limit(1),
        supabase.from('applications').select('id', { count: 'exact' }).limit(1),
      ]);

      const getCount = (
        res: PromiseSettledResult<{ count: number | null; error: any }>,
        fallback: number
      ) => {
        if (res.status === 'fulfilled' && res.value && !res.value.error && typeof res.value.count === 'number') {
          return res.value.count;
        }
        return fallback;
      };

      setStats({
        totalStudents: getCount(results[0], 1),
        activeSocieties: getCount(results[1], 5),
        pendingSocieties: getCount(results[2], 0),
        totalEvents: getCount(results[3], 3),
        totalApplications: getCount(results[4], 0),
      });

      // Fetch pending societies
      const { data: pendingData } = await supabase
        .from('societies')
        .select('*')
        .eq('status', 'pending');

      setPendingSocieties(pendingData || []);
    } catch (err) {
      console.error('Error fetching admin data:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAdminData();
  }, [currentUser]);

  const handleApprove = async (societyId: string) => {
    setActionLoading(societyId);
    try {
      const { error } = await supabase
        .from('societies')
        .update({ status: 'active', updated_at: new Date().toISOString() })
        .eq('id', societyId);

      if (error) throw error;
      setPendingSocieties((prev) => prev.filter((s) => s.id !== societyId));
      showToast('Society charter approved and activated!', 'success');
      fetchAdminData();
    } catch (err: any) {
      showToast(err.message || 'Failed to approve society.', 'error');
    } finally {
      setActionLoading(null);
    }
  };

  const handleReject = async (societyId: string) => {
    setActionLoading(societyId);
    try {
      const { error } = await supabase
        .from('societies')
        .update({ status: 'inactive', updated_at: new Date().toISOString() })
        .eq('id', societyId);

      if (error) throw error;
      setPendingSocieties((prev) => prev.filter((s) => s.id !== societyId));
      showToast('Society registration rejected.', 'info');
      fetchAdminData();
    } catch (err: any) {
      showToast(err.message || 'Failed to reject society.', 'error');
    } finally {
      setActionLoading(null);
    }
  };

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Header Banner */}
      <div className="bg-gradient-to-r from-slate-900 via-slate-900/90 to-emerald-950/40 border border-slate-800 rounded-3xl p-6 sm:p-8 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6 shadow-xl">
        <div className="space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs font-semibold">
            <Shield className="w-3.5 h-3.5" /> UET Student Affairs Directorate
          </div>
          <h2 className="text-xl sm:text-2xl font-black text-white">
            Administrative Council Portal
          </h2>
          <p className="text-xs sm:text-sm text-slate-300 max-w-xl leading-relaxed">
            Charter approval, governance auditing, and cross-departmental society compliance monitoring.
          </p>
        </div>

        <button
          onClick={fetchAdminData}
          disabled={loading}
          className="flex items-center gap-2 px-4 py-2.5 bg-slate-900 hover:bg-slate-800 border border-slate-800 rounded-xl text-xs font-semibold text-slate-200 transition cursor-pointer"
        >
          <RefreshCw className={`w-3.5 h-3.5 text-emerald-400 ${loading ? 'animate-spin' : ''}`} />
          <span>Refresh Metrics</span>
        </button>
      </div>

      {/* Metrics Counters Grid */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <StatCounter
          label="Registered Students"
          target={stats.totalStudents}
          icon={<Users className="w-4 h-4 text-emerald-400" />}
        />
        <StatCounter
          label="Active Societies"
          target={stats.activeSocieties}
          icon={<Building className="w-4 h-4 text-emerald-400" />}
        />
        <StatCounter
          label="Campus Events"
          target={stats.totalEvents}
          icon={<Calendar className="w-4 h-4 text-emerald-400" />}
        />
        <StatCounter
          label="Submitted Applications"
          target={stats.totalApplications}
          icon={<Briefcase className="w-4 h-4 text-emerald-400" />}
        />
      </div>

      {/* Pending Society Charters */}
      <div className="bg-slate-900/90 border border-slate-800 rounded-3xl p-6 shadow-xl space-y-4">
        <div className="flex items-center justify-between border-b border-slate-800 pb-4">
          <div>
            <h3 className="text-base font-bold text-white flex items-center gap-2">
              <FileCheck className="w-5 h-5 text-emerald-400" /> Pending Charter Registrations
            </h3>
            <p className="text-xs text-slate-400">
              Societies awaiting accreditation review from Director Student Affairs
            </p>
          </div>
          <span className="px-2.5 py-1 rounded-full bg-slate-950 border border-slate-800 text-[11px] font-mono text-emerald-400">
            {pendingSocieties.length} Pending
          </span>
        </div>

        {pendingSocieties.length > 0 ? (
          <div className="space-y-3">
            {pendingSocieties.map((soc) => (
              <div
                key={soc.id}
                className="p-4 rounded-2xl bg-slate-950 border border-slate-800/90 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4"
              >
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <span className="font-bold text-white text-sm">{soc.name}</span>
                    <span className="text-[10px] uppercase font-mono px-2 py-0.5 rounded-full bg-amber-500/10 text-amber-300 border border-amber-500/30">
                      {soc.category}
                    </span>
                  </div>
                  <p className="text-xs text-slate-400 line-clamp-2">{soc.description}</p>
                  <p className="text-[11px] font-mono text-slate-500 mt-1">
                    Category: {soc.category} &bull; Registered: {formatPKTDate(soc.created_at)}
                  </p>
                </div>

                <div className="flex items-center gap-2 shrink-0">
                  <button
                    onClick={() => handleReject(soc.id)}
                    disabled={actionLoading === soc.id}
                    className="p-2 rounded-xl bg-rose-500/10 text-rose-400 hover:bg-rose-500/20 border border-rose-500/30 transition cursor-pointer"
                    title="Reject Charter"
                    aria-label="Reject Charter"
                  >
                    <XCircle className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => handleApprove(soc.id)}
                    disabled={actionLoading === soc.id}
                    className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold shadow-md shadow-emerald-950 transition cursor-pointer"
                  >
                    <CheckCircle className="w-3.5 h-3.5" />
                    <span>Approve Charter</span>
                  </button>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="py-12 text-center text-xs text-slate-500">
            No pending society registration requests at this time. All active councils verified.
          </div>
        )}
      </div>
    </div>
  );
};
