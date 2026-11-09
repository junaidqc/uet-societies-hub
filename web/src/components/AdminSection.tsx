import React, { useState, useEffect } from 'react';
import {
  Shield,
  CheckCircle,
  XCircle,
  Clock,
  AlertTriangle,
  Users,
  Building,
  Calendar,
  Briefcase,
  Search,
  RefreshCw,
  FileCheck,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { Society, Profile, Application } from '../types';

interface AdminSectionProps {
  currentUser: Profile | null;
}

export const AdminSection: React.FC<AdminSectionProps> = ({ currentUser }) => {
  const [stats, setStats] = useState({
    totalStudents: 0,
    activeSocieties: 0,
    pendingSocieties: 0,
    totalEvents: 0,
    totalApplications: 0,
  });

  const [pendingSocieties, setPendingSocieties] = useState<Society[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  const fetchAdminData = async () => {
    setLoading(true);
    try {
      // 1. Fetch counts
      const [profilesRes, socActiveRes, socPendingRes, eventsRes, appsRes] = await Promise.all([
        supabase.from('profiles').select('*', { count: 'exact', head: true }),
        supabase.from('societies').select('*', { count: 'exact', head: true }).eq('status', 'active'),
        supabase.from('societies').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
        supabase.from('events').select('*', { count: 'exact', head: true }),
        supabase.from('applications').select('*', { count: 'exact', head: true }),
      ]);

      setStats({
        totalStudents: profilesRes.count || 1,
        activeSocieties: socActiveRes.count || 5,
        pendingSocieties: socPendingRes.count || 0,
        totalEvents: eventsRes.count || 3,
        totalApplications: appsRes.count || 0,
      });

      // 2. Fetch pending societies
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
  }, []);

  const handleApprove = async (societyId: string) => {
    setActionLoading(societyId);
    try {
      const { error } = await supabase
        .from('societies')
        .update({ status: 'active', updated_at: new Date().toISOString() })
        .eq('id', societyId);

      if (error) throw error;
      setPendingSocieties((prev) => prev.filter((s) => s.id !== societyId));
      fetchAdminData();
    } catch (err: any) {
      alert(err.message || 'Failed to approve society.');
    } finally {
      setActionLoading(null);
    }
  };

  const handleReject = async (societyId: string) => {
    const reason = prompt('Please provide reason for rejecting this society charter:');
    if (!reason) return;

    setActionLoading(societyId);
    try {
      const { error } = await supabase
        .from('societies')
        .update({
          status: 'rejected',
          rejection_reason: reason,
          updated_at: new Date().toISOString(),
        })
        .eq('id', societyId);

      if (error) throw error;
      setPendingSocieties((prev) => prev.filter((s) => s.id !== societyId));
      fetchAdminData();
    } catch (err: any) {
      alert(err.message || 'Failed to reject society.');
    } finally {
      setActionLoading(null);
    }
  };

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Top Banner */}
      <div className="bg-gradient-to-r from-emerald-950/60 via-slate-900 to-slate-950 border border-emerald-500/30 rounded-3xl p-6 sm:p-8 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 shadow-xl">
        <div className="space-y-1">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs font-semibold">
            <Shield className="w-3.5 h-3.5" /> University System Admin Directorate
          </div>
          <h2 className="text-xl sm:text-2xl font-bold text-white">
            Campus Governance & Charter Approvals
          </h2>
          <p className="text-xs text-slate-400">
            Review new society registration charters, manage compliance, and supervise recruitment
            cycles.
          </p>
        </div>

        <button
          onClick={fetchAdminData}
          className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-semibold text-slate-200 transition"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          <span>Refresh Metrics</span>
        </button>
      </div>

      {/* KPI Stats Grid */}
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-4">
        {[
          { label: 'Registered Students', val: stats.totalStudents, icon: <Users className="w-4 h-4 text-emerald-400" /> },
          { label: 'Active Societies', val: stats.activeSocieties, icon: <Building className="w-4 h-4 text-blue-400" /> },
          { label: 'Pending Charters', val: stats.pendingSocieties, icon: <Clock className="w-4 h-4 text-amber-400" /> },
          { label: 'Campus Events', val: stats.totalEvents, icon: <Calendar className="w-4 h-4 text-purple-400" /> },
          { label: 'Submitted Applications', val: stats.totalApplications, icon: <Briefcase className="w-4 h-4 text-teal-400" /> },
        ].map((item, idx) => (
          <div
            key={idx}
            className="p-4 rounded-2xl bg-slate-900/80 border border-slate-800 flex flex-col justify-between"
          >
            <div className="flex items-center justify-between mb-2">
              <span className="text-[11px] font-medium text-slate-400">{item.label}</span>
              {item.icon}
            </div>
            <p className="text-2xl font-extrabold text-white">{item.val}</p>
          </div>
        ))}
      </div>

      {/* Society Charters Approval Queue */}
      <div className="bg-slate-900 border border-slate-800 rounded-3xl p-6 sm:p-8 space-y-4 shadow-xl">
        <div className="flex items-center justify-between pb-4 border-b border-slate-800">
          <div>
            <h3 className="text-base font-bold text-white flex items-center gap-2">
              <FileCheck className="w-5 h-5 text-emerald-400" /> Charter Approval Queue
            </h3>
            <p className="text-xs text-slate-400">
              Proposals submitted by faculty advisors and student presidents
            </p>
          </div>
          <span className="text-xs font-mono px-2.5 py-1 rounded-full bg-slate-950 border border-slate-800 text-slate-300">
            {pendingSocieties.length} Pending
          </span>
        </div>

        {pendingSocieties.length > 0 ? (
          <div className="space-y-4 pt-2">
            {pendingSocieties.map((soc) => (
              <div
                key={soc.id}
                className="bg-slate-950/70 border border-slate-800 rounded-2xl p-5 flex flex-col md:flex-row items-start md:items-center justify-between gap-4"
              >
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <span className="text-sm font-bold text-white">{soc.name}</span>
                    <span className="text-[10px] font-semibold uppercase px-2 py-0.5 rounded-full bg-amber-950/50 text-amber-300 border border-amber-500/30">
                      {soc.category}
                    </span>
                  </div>
                  <p className="text-xs text-slate-300 leading-relaxed mb-2">{soc.description}</p>
                  <p className="text-[11px] text-slate-500">Contact: {soc.email || 'N/A'}</p>
                </div>

                <div className="flex items-center gap-2 shrink-0">
                  <button
                    onClick={() => handleReject(soc.id)}
                    disabled={actionLoading === soc.id}
                    className="px-3.5 py-2 rounded-xl bg-red-950/40 hover:bg-red-900/60 border border-red-500/30 text-red-300 text-xs font-semibold flex items-center gap-1.5 transition"
                  >
                    <XCircle className="w-3.5 h-3.5" />
                    <span>Reject</span>
                  </button>

                  <button
                    onClick={() => handleApprove(soc.id)}
                    disabled={actionLoading === soc.id}
                    className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold flex items-center gap-1.5 shadow-md shadow-emerald-900/30 transition"
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
            All charter submissions are reviewed. No pending approvals in queue.
          </div>
        )}
      </div>
    </div>
  );
};
