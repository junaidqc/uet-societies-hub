import React, { useState, useEffect } from 'react';
import {
  Compass,
  Search,
  Users,
  CheckCircle,
  ExternalLink,
  Mail,
  Globe,
  Calendar,
  Briefcase,
  X,
  PlusCircle,
  ShieldCheck,
  Heart,
  ChevronRight,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { Society, Profile, Post, Event, Hiring } from '../types';

interface SocietiesSectionProps {
  currentUser: Profile | null;
  onRequireAuth: () => void;
  onApplyHiring: (hiring: Hiring) => void;
}

export const SocietiesSection: React.FC<SocietiesSectionProps> = ({
  currentUser,
  onRequireAuth,
  onApplyHiring,
}) => {
  const [societies, setSocieties] = useState<Society[]>([]);
  const [followedSet, setFollowedSet] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('All');

  // Society Detail Modal
  const [activeSociety, setActiveSociety] = useState<Society | null>(null);
  const [societyPosts, setSocietyPosts] = useState<Post[]>([]);
  const [societyEvents, setSocietyEvents] = useState<Event[]>([]);
  const [societyHirings, setSocietyHirings] = useState<Hiring[]>([]);
  const [loadingDetail, setLoadingDetail] = useState(false);

  // Propose society modal
  const [proposeModalOpen, setProposeModalOpen] = useState(false);
  const [propName, setPropName] = useState('');
  const [propCategory, setPropCategory] = useState('Technical');
  const [propDesc, setPropDesc] = useState('');
  const [propEmail, setPropEmail] = useState('');
  const [submittingProp, setSubmittingProp] = useState(false);

  const fetchSocieties = async () => {
    setLoading(true);
    try {
      // 1. Fetch societies
      const { data, error } = await supabase
        .from('societies')
        .select('*')
        .eq('status', 'active')
        .order('name', { ascending: true });

      if (error) throw error;

      // 2. Fetch follower counts & user follows
      const { data: followsData } = await supabase.from('follows').select('society_id, user_id');
      const counts: Record<string, number> = {};
      const userFollows = new Set<string>();

      (followsData || []).forEach((f) => {
        counts[f.society_id] = (counts[f.society_id] || 0) + 1;
        if (currentUser && f.user_id === currentUser.id) {
          userFollows.add(f.society_id);
        }
      });

      const processed = (data || []).map((s) => ({
        ...s,
        follower_count: counts[s.id] || 0,
      }));

      setSocieties(processed);
      setFollowedSet(userFollows);
    } catch (err) {
      console.error('Error fetching societies:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchSocieties();
  }, [currentUser]);

  // Handle follow toggle
  const handleToggleFollow = async (society: Society, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!currentUser) {
      onRequireAuth();
      return;
    }

    const isFollowing = followedSet.has(society.id);
    const nextSet = new Set(followedSet);

    if (isFollowing) {
      nextSet.delete(society.id);
    } else {
      nextSet.add(society.id);
    }
    setFollowedSet(nextSet);

    // Optimistic count
    setSocieties((prev) =>
      prev.map((s) =>
        s.id === society.id
          ? {
              ...s,
              follower_count: Math.max(0, (s.follower_count || 0) + (isFollowing ? -1 : 1)),
            }
          : s
      )
    );

    try {
      if (isFollowing) {
        await supabase
          .from('follows')
          .delete()
          .eq('society_id', society.id)
          .eq('user_id', currentUser.id);
      } else {
        await supabase
          .from('follows')
          .insert({ society_id: society.id, user_id: currentUser.id });
      }
    } catch (err) {
      console.error('Follow toggle error:', err);
      fetchSocieties();
    }
  };

  // Open Society Detail
  const handleOpenDetail = async (society: Society) => {
    setActiveSociety(society);
    setLoadingDetail(true);
    try {
      // Fetch posts
      const { data: pData } = await supabase
        .from('posts')
        .select('*')
        .eq('society_id', society.id)
        .order('created_at', { ascending: false });
      setSocietyPosts(pData || []);

      // Fetch events
      const { data: eData } = await supabase
        .from('events')
        .select('*')
        .eq('society_id', society.id)
        .order('start_time', { ascending: true });
      setSocietyEvents(eData || []);

      // Fetch hirings
      const { data: hData } = await supabase
        .from('hirings')
        .select('*')
        .eq('society_id', society.id)
        .eq('status', 'open');
      setSocietyHirings(hData || []);
    } catch (err) {
      console.error('Error fetching society details:', err);
    } finally {
      setLoadingDetail(false);
    }
  };

  // Submit Propose Society
  const handleProposeSociety = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!currentUser) {
      onRequireAuth();
      return;
    }

    setSubmittingProp(true);
    try {
      const slug = propName.toLowerCase().replace(/[^a-z0-9]+/g, '-');
      const { error } = await supabase.from('societies').insert({
        name: propName.trim(),
        slug,
        category: propCategory,
        description: propDesc.trim(),
        email: propEmail.trim() || null,
        status: 'pending',
        created_by: currentUser.id,
        social_links: {},
      });

      if (error) throw error;
      alert('Your society charter proposal has been submitted to the Admin Directorate for approval!');
      setProposeModalOpen(false);
      setPropName('');
      setPropDesc('');
      setPropEmail('');
    } catch (err: any) {
      console.error('Charter proposal error:', err);
      alert(err.message || 'Failed to submit proposal.');
    } finally {
      setSubmittingProp(false);
    }
  };

  const categories = ['All', 'Technical', 'Literary', 'Social'];

  const filtered = societies.filter((s) => {
    const matchesCat = selectedCategory === 'All' || s.category.toLowerCase().includes(selectedCategory.toLowerCase());
    const matchesSearch =
      s.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      s.description.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesCat && matchesSearch;
  });

  return (
    <div className="space-y-6 animate-fadeIn">
      {/* Search and Action Bar */}
      <div className="flex flex-col md:flex-row items-stretch md:items-center justify-between gap-4">
        {/* Search Input */}
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-3" />
          <input
            type="text"
            placeholder="Search societies, technical branches, clubs..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-slate-900 border border-slate-800 rounded-2xl pl-10 pr-4 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500 transition"
          />
        </div>

        {/* Category Filter Pills & Charter Button */}
        <div className="flex items-center gap-2 overflow-x-auto pb-1">
          {categories.map((cat) => (
            <button
              key={cat}
              onClick={() => setSelectedCategory(cat)}
              className={`px-3 py-1.5 rounded-xl text-xs font-medium whitespace-nowrap transition ${
                selectedCategory === cat
                  ? 'bg-emerald-600 text-white shadow-md shadow-emerald-900/30'
                  : 'bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800'
              }`}
            >
              {cat}
            </button>
          ))}

          <button
            onClick={() => {
              if (!currentUser) onRequireAuth();
              else setProposeModalOpen(true);
            }}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-xs font-semibold text-emerald-400 whitespace-nowrap transition ml-auto"
          >
            <PlusCircle className="w-3.5 h-3.5" />
            <span>Charter Society</span>
          </button>
        </div>
      </div>

      {/* Grid of Society Cards */}
      {loading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {[1, 2, 3, 4, 5, 6].map((i) => (
            <div
              key={i}
              className="bg-slate-900/60 border border-slate-800 rounded-3xl p-6 h-64 animate-pulse"
            />
          ))}
        </div>
      ) : filtered.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {filtered.map((soc) => {
            const isFollowing = followedSet.has(soc.id);
            return (
              <div
                key={soc.id}
                onClick={() => handleOpenDetail(soc)}
                className="bg-slate-900/80 hover:bg-slate-900 border border-slate-800 hover:border-emerald-500/40 rounded-3xl p-6 flex flex-col justify-between shadow-xl transition duration-200 cursor-pointer group"
              >
                <div>
                  {/* Top Header */}
                  <div className="flex items-start justify-between gap-3 mb-4">
                    <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-emerald-500/20 to-teal-500/20 border border-emerald-500/30 flex items-center justify-center font-bold text-emerald-400 text-lg">
                      {soc.name.charAt(0)}
                    </div>
                    <span className="text-[10px] font-semibold uppercase tracking-wider px-2.5 py-1 rounded-full bg-slate-950 border border-slate-800 text-slate-300">
                      {soc.category}
                    </span>
                  </div>

                  {/* Society Title */}
                  <h3 className="text-base font-bold text-white group-hover:text-emerald-300 transition line-clamp-1">
                    {soc.name}
                  </h3>
                  <p className="text-xs text-slate-400 mt-2 line-clamp-3 leading-relaxed">
                    {soc.description}
                  </p>
                </div>

                {/* Footer with Follow Button */}
                <div className="mt-5 pt-4 border-t border-slate-800/80 flex items-center justify-between">
                  <div className="flex items-center gap-1.5 text-xs text-slate-400">
                    <Users className="w-3.5 h-3.5 text-emerald-400" />
                    <span>{soc.follower_count || 0} Followers</span>
                  </div>

                  <button
                    type="button"
                    onClick={(e) => handleToggleFollow(soc, e)}
                    className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition ${
                      isFollowing
                        ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/40'
                        : 'bg-slate-800 hover:bg-slate-700 text-white'
                    }`}
                  >
                    {isFollowing ? 'Following' : '+ Follow'}
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        <div className="bg-slate-900 border border-slate-800 rounded-3xl p-12 text-center">
          <p className="text-slate-400 text-sm">No societies found matching your criteria.</p>
        </div>
      )}

      {/* Society Detail Modal */}
      {activeSociety && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-md animate-fadeIn">
          <div className="bg-slate-900 border border-slate-700/80 rounded-3xl w-full max-w-2xl shadow-2xl overflow-hidden flex flex-col max-h-[88vh]">
            {/* Modal Header */}
            <div className="relative p-6 border-b border-slate-800 bg-gradient-to-r from-slate-950 via-slate-900 to-slate-950">
              <button
                onClick={() => setActiveSociety(null)}
                className="absolute top-4 right-4 text-slate-400 hover:text-white p-1.5 rounded-lg hover:bg-slate-800 transition"
              >
                <X className="w-5 h-5" />
              </button>

              <div className="flex items-center gap-4">
                <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-emerald-500/20 to-teal-500/20 border border-emerald-500/30 flex items-center justify-center font-bold text-emerald-400 text-2xl shadow-lg">
                  {activeSociety.name.charAt(0)}
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h2 className="text-lg font-bold text-white">{activeSociety.name}</h2>
                    <ShieldCheck className="w-4 h-4 text-emerald-400" />
                  </div>
                  <p className="text-xs text-slate-400 mt-0.5">
                    {activeSociety.category} &bull; Official UET Directorate Chartered
                  </p>
                </div>
              </div>
            </div>

            {/* Modal Body */}
            <div className="flex-1 overflow-y-auto p-6 space-y-6">
              {/* About */}
              <div>
                <h4 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-2">
                  About Society
                </h4>
                <p className="text-xs sm:text-sm text-slate-300 leading-relaxed">
                  {activeSociety.description}
                </p>
              </div>

              {/* Contact info */}
              <div className="grid grid-cols-2 gap-3 p-3.5 bg-slate-950 rounded-2xl border border-slate-800 text-xs">
                <div className="flex items-center gap-2 text-slate-300">
                  <Mail className="w-4 h-4 text-emerald-400 shrink-0" />
                  <span className="truncate">{activeSociety.email || 'info@uet.edu.pk'}</span>
                </div>
                <div className="flex items-center gap-2 text-slate-300">
                  <Globe className="w-4 h-4 text-emerald-400 shrink-0" />
                  <span className="truncate">{activeSociety.website || 'uet.edu.pk/societies'}</span>
                </div>
              </div>

              {/* Open Hirings Section */}
              <div>
                <div className="flex items-center justify-between mb-3">
                  <h4 className="text-xs font-semibold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
                    <Briefcase className="w-3.5 h-3.5 text-emerald-400" /> Open Recruitments (
                    {societyHirings.length})
                  </h4>
                </div>
                {societyHirings.length > 0 ? (
                  <div className="space-y-2.5">
                    {societyHirings.map((h) => (
                      <div
                        key={h.id}
                        className="p-3.5 rounded-2xl bg-slate-950 border border-slate-800 flex items-center justify-between"
                      >
                        <div>
                          <p className="text-xs font-bold text-white">{h.title}</p>
                          <p className="text-[11px] text-slate-400">
                            Deadline: {new Date(h.deadline).toLocaleDateString()} &bull;{' '}
                            {h.total_seats || 10} Seats
                          </p>
                        </div>
                        <button
                          onClick={() => {
                            setActiveSociety(null);
                            onApplyHiring(h);
                          }}
                          className="px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold"
                        >
                          Apply Now
                        </button>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="text-xs text-slate-500 italic">No active recruitment cycles.</p>
                )}
              </div>

              {/* Upcoming Events */}
              <div>
                <h4 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3 flex items-center gap-1.5">
                  <Calendar className="w-3.5 h-3.5 text-emerald-400" /> Upcoming Events (
                  {societyEvents.length})
                </h4>
                {societyEvents.length > 0 ? (
                  <div className="space-y-2">
                    {societyEvents.map((e) => (
                      <div
                        key={e.id}
                        className="p-3 rounded-2xl bg-slate-950 border border-slate-800 flex items-center justify-between text-xs"
                      >
                        <div>
                          <p className="font-semibold text-white">{e.title}</p>
                          <p className="text-[11px] text-slate-400">{e.venue}</p>
                        </div>
                        <span className="text-[11px] font-mono text-emerald-400">
                          {new Date(e.start_time).toLocaleDateString('en-US', {
                            month: 'short',
                            day: 'numeric',
                          })}
                        </span>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="text-xs text-slate-500 italic">No upcoming events scheduled.</p>
                )}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Propose Society Modal */}
      {proposeModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-md animate-fadeIn">
          <div className="bg-slate-900 border border-slate-700/80 rounded-2xl w-full max-w-md shadow-2xl p-6">
            <div className="flex items-center justify-between pb-4 border-b border-slate-800 mb-4">
              <h3 className="font-bold text-white text-base">Charter a Society</h3>
              <button
                onClick={() => setProposeModalOpen(false)}
                className="text-slate-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleProposeSociety} className="space-y-4 text-xs">
              <div>
                <label className="text-slate-300 font-medium block mb-1">Society Name</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. UET Artificial Intelligence Society"
                  value={propName}
                  onChange={(e) => setPropName(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="text-slate-300 font-medium block mb-1">Category</label>
                <select
                  value={propCategory}
                  onChange={(e) => setPropCategory(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                >
                  <option value="Technical">Technical</option>
                  <option value="Literary">Literary</option>
                  <option value="Social">Social</option>
                  <option value="Sports">Sports</option>
                </select>
              </div>

              <div>
                <label className="text-slate-300 font-medium block mb-1">Official Society Email</label>
                <input
                  type="email"
                  placeholder="ai.society@uet.edu.pk"
                  value={propEmail}
                  onChange={(e) => setPropEmail(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="text-slate-300 font-medium block mb-1">
                  Charter Objective & Vision
                </label>
                <textarea
                  required
                  rows={3}
                  placeholder="Explain purpose, faculty advisor, target student community..."
                  value={propDesc}
                  onChange={(e) => setPropDesc(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500 resize-none"
                />
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setProposeModalOpen(false)}
                  className="px-4 py-2 rounded-xl text-slate-400 hover:text-white"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submittingProp}
                  className="px-5 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold rounded-xl"
                >
                  {submittingProp ? 'Submitting...' : 'Submit Charter'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
