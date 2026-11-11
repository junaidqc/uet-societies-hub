import React, { useState, useEffect, useRef } from 'react';
import {
  Search,
  Users,
  Mail,
  Globe,
  Calendar,
  Briefcase,
  X,
  PlusCircle,
  ShieldCheck,
  Compass,
  FileText,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { Society, Profile, Event, Hiring } from '../types';
import { useToast } from './Toast';
import { filterSocieties } from '../utils/search';
import { formatPKTDate } from '../utils/date';
import { syncAppUrl } from '../utils/urlState';
import { Modal } from './common/Modal';
import { ErrorState } from './common/ErrorState';

interface SocietiesSectionProps {
  currentUser: Profile | null;
  onRequireAuth: () => void;
  onApplyHiring: (hiring: Hiring) => void;
  cachedSocieties?: Society[];
  onCacheSocieties?: (societies: Society[]) => void;
  initialQuery?: string;
  initialCategory?: string;
}

export const SocietiesSection: React.FC<SocietiesSectionProps> = ({
  currentUser,
  onRequireAuth,
  onApplyHiring,
  cachedSocieties = [],
  onCacheSocieties,
  initialQuery = '',
  initialCategory = 'All',
}) => {
  const { showToast } = useToast();
  const searchInputRef = useRef<HTMLInputElement>(null);

  const [societies, setSocieties] = useState<Society[]>(cachedSocieties);
  const [allEvents, setAllEvents] = useState<Event[]>([]);
  const [followedSet, setFollowedSet] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(cachedSocieties.length === 0);
  const [error, setError] = useState<string | null>(null);

  const [searchQuery, setSearchQuery] = useState(initialQuery);
  const [selectedCategory, setSelectedCategory] = useState(initialCategory);

  // Society Detail Modal
  const [activeSociety, setActiveSociety] = useState<Society | null>(null);
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

  // Focus search bar on '/' keypress
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === '/' && document.activeElement !== searchInputRef.current) {
        if (!['INPUT', 'TEXTAREA'].includes((document.activeElement as HTMLElement)?.tagName)) {
          e.preventDefault();
          searchInputRef.current?.focus();
        }
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  const fetchSocieties = async () => {
    if (societies.length === 0) setLoading(true);
    setError(null);
    try {
      // 1. Fetch societies
      const { data, error: socErr } = await supabase
        .from('societies')
        .select('*')
        .eq('status', 'active')
        .order('name', { ascending: true });

      if (socErr) throw socErr;

      // 2. Pre-fetch all events so Society modal has 0ms hydration
      const { data: eventsData } = await supabase
        .from('events')
        .select('*, society:societies(*)')
        .order('start_time', { ascending: true });

      if (eventsData) {
        setAllEvents(eventsData);
      }

      // 3. Fetch follower counts & user follows
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

      if (onCacheSocieties) {
        onCacheSocieties(processed);
      }
    } catch (err: any) {
      console.error('Error fetching societies:', err);
      setError(err?.message || 'Could not load official student societies.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchSocieties();
  }, [currentUser]);

  // Sync search state to URL
  const handleSearchChange = (val: string) => {
    setSearchQuery(val);
    syncAppUrl({ tab: 'societies', query: val, category: selectedCategory }, true);
  };

  const handleCategoryChange = (cat: string) => {
    setSelectedCategory(cat);
    syncAppUrl({ tab: 'societies', query: searchQuery, category: cat }, true);
  };

  // Follow toggle
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
      showToast(`Unfollowed ${society.name}`, 'info');
    } else {
      nextSet.add(society.id);
      showToast(`Now following ${society.name}!`, 'success');
    }
    setFollowedSet(nextSet);

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
    syncAppUrl({ tab: 'societies', societyId: society.slug }, true);

    const preFiltered = allEvents.filter((e) => e.society_id === society.id);
    setSocietyEvents(preFiltered);

    setLoadingDetail(true);
    try {
      const { data: hiringsData } = await supabase
        .from('hirings')
        .select('*')
        .eq('society_id', society.id)
        .eq('status', 'open');

      setSocietyHirings(hiringsData || []);
    } catch (err) {
      console.error('Error fetching society detail:', err);
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
      const { error: insErr } = await supabase.from('societies').insert({
        name: propName.trim(),
        slug: slug || `soc-${Date.now()}`,
        category: propCategory,
        description: propDesc.trim(),
        email: propEmail.trim() || null,
        status: 'pending',
        created_by: currentUser.id,
        social_links: {},
      });

      if (insErr) throw insErr;
      showToast('Society charter submitted to Admin Directorate for approval!', 'success');
      setProposeModalOpen(false);
      setPropName('');
      setPropDesc('');
      setPropEmail('');
    } catch (err: any) {
      console.error('Charter proposal error:', err);
      showToast(err.message || 'Failed to submit proposal.', 'error');
    } finally {
      setSubmittingProp(false);
    }
  };

  const categories = ['All', 'Technical', 'Literary', 'Social'];
  const filtered = filterSocieties(societies, searchQuery, selectedCategory);

  return (
    <div className="space-y-6">
      {/* Search and Action Bar */}
      <div className="flex flex-col md:flex-row items-stretch md:items-center justify-between gap-4">
        {/* Search Input with Clear Button and Shortcut */}
        <div className="relative flex-1 max-w-md">
          <label htmlFor="society-search" className="sr-only">
            Search societies
          </label>
          <Search className="w-4 h-4 text-zinc-400 absolute left-3.5 top-3" aria-hidden="true" />
          <input
            id="society-search"
            ref={searchInputRef}
            type="text"
            placeholder="Search societies, technical branches, clubs... (Press / to focus)"
            value={searchQuery}
            onChange={(e) => handleSearchChange(e.target.value)}
            className="w-full bg-zinc-900 border border-zinc-800 rounded-2xl pl-10 pr-9 py-2.5 text-xs text-white placeholder-zinc-500 focus:outline-none focus:border-emerald-500 transition shadow-inner"
          />
          {searchQuery && (
            <button
              type="button"
              onClick={() => handleSearchChange('')}
              aria-label="Clear search input"
              className="absolute right-3 top-2.5 p-0.5 rounded-md text-zinc-400 hover:text-white hover:bg-zinc-800 transition"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>

        {/* Category Filter Pills & Charter Button */}
        <div className="flex items-center gap-2 overflow-x-auto pb-1" role="toolbar" aria-label="Society Filters">
          {categories.map((cat) => (
            <button
              key={cat}
              onClick={() => handleCategoryChange(cat)}
              className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition cursor-pointer ${
                selectedCategory === cat
                  ? 'bg-emerald-600 text-white shadow-md shadow-emerald-950'
                  : 'bg-zinc-900 hover:bg-zinc-800 text-zinc-300 border border-zinc-800'
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
            className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl bg-zinc-900 hover:bg-zinc-800 border border-emerald-500/30 text-xs font-semibold text-emerald-400 whitespace-nowrap transition ml-auto cursor-pointer"
          >
            <PlusCircle className="w-3.5 h-3.5" />
            <span>Charter Society</span>
          </button>
        </div>
      </div>

      {/* Error state */}
      {error && <ErrorState message={error} onRetry={fetchSocieties} retrying={loading} />}

      {/* Grid of Society Cards */}
      {loading && !error ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {[1, 2, 3, 4, 5, 6].map((i) => (
            <div
              key={i}
              className="bg-zinc-900/80 border border-zinc-800 rounded-3xl p-6 h-64 space-y-4 animate-pulse"
            >
              <div className="flex justify-between items-start">
                <div className="w-12 h-12 rounded-2xl bg-zinc-800" />
                <div className="w-16 h-5 rounded-full bg-zinc-800" />
              </div>
              <div className="h-5 w-40 bg-zinc-800 rounded" />
              <div className="space-y-2">
                <div className="h-3 w-full bg-zinc-800/60 rounded" />
                <div className="h-3 w-4/5 bg-zinc-800/60 rounded" />
              </div>
              <div className="pt-4 border-t border-zinc-800/80 flex justify-between">
                <div className="h-4 w-20 bg-zinc-800 rounded" />
                <div className="h-6 w-16 bg-zinc-800 rounded" />
              </div>
            </div>
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
                className="tech-card bg-zinc-900/80 hover:bg-zinc-900 border border-zinc-800/80 hover:border-emerald-500/40 rounded-3xl p-6 flex flex-col justify-between shadow-xl cursor-pointer group"
              >
                <div>
                  {/* Top Header */}
                  <div className="flex items-start justify-between gap-3 mb-4">
                    <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-emerald-500/20 to-teal-500/20 border border-emerald-500/30 flex items-center justify-center font-bold text-emerald-400 text-lg group-hover:scale-105 transition">
                      {soc.name.charAt(0)}
                    </div>
                    <span className="text-[10px] font-semibold uppercase tracking-wider px-2.5 py-1 rounded-full bg-zinc-950 border border-zinc-800 text-zinc-300">
                      {soc.category}
                    </span>
                  </div>

                  {/* Society Title */}
                  <h3 className="text-base font-bold text-white group-hover:text-emerald-300 transition line-clamp-1">
                    {soc.name}
                  </h3>
                  <p className="text-xs text-zinc-400 mt-2 line-clamp-3 leading-relaxed">
                    {soc.description}
                  </p>
                </div>

                {/* Footer with Follow Button */}
                <div className="mt-5 pt-4 border-t border-zinc-800/80 flex items-center justify-between">
                  <div className="flex items-center gap-1.5 text-xs text-zinc-400">
                    <Users className="w-3.5 h-3.5 text-emerald-400" />
                    <span>{soc.follower_count || 0} Followers</span>
                  </div>

                  <button
                    type="button"
                    onClick={(e) => handleToggleFollow(soc, e)}
                    className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition cursor-pointer ${
                      isFollowing
                        ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/40'
                        : 'bg-zinc-800 hover:bg-zinc-700 text-white'
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
        <div className="bg-zinc-900/60 border border-zinc-800 rounded-3xl p-12 text-center max-w-lg mx-auto">
          <div className="w-12 h-12 rounded-2xl bg-zinc-800/80 text-zinc-500 flex items-center justify-center mx-auto mb-3">
            <Compass className="w-6 h-6" />
          </div>
          <h4 className="text-base font-bold text-white mb-1">No Societies Found</h4>
          <p className="text-zinc-400 text-xs mb-5">
            We couldn't find any student societies matching <span className="text-emerald-400 font-mono">"{searchQuery}"</span> in the {selectedCategory} category.
          </p>
          <button
            type="button"
            onClick={() => {
              handleSearchChange('');
              handleCategoryChange('All');
            }}
            className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold rounded-xl transition cursor-pointer"
          >
            Reset All Filters
          </button>
        </div>
      )}

      {/* Accessible Society Detail Modal */}
      {activeSociety && (
        <Modal
          isOpen={!!activeSociety}
          onClose={() => {
            setActiveSociety(null);
            syncAppUrl({ tab: 'societies', societyId: null }, true);
          }}
          title={activeSociety.name}
          subtitle={`${activeSociety.category} • Official UET Directorate Chartered`}
          icon={<ShieldCheck className="w-5 h-5 text-emerald-400" />}
          maxWidth="2xl"
        >
          <div className="space-y-6">
            {/* About */}
            <div>
              <h4 className="text-xs font-semibold uppercase tracking-wider text-zinc-400 mb-2">
                About Society
              </h4>
              <p className="text-xs sm:text-sm text-zinc-300 leading-relaxed">
                {activeSociety.description}
              </p>
            </div>

            {/* Contact info */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 p-3.5 bg-zinc-950 rounded-2xl border border-zinc-800 text-xs">
              <div className="flex items-center gap-2 text-zinc-300">
                <Mail className="w-4 h-4 text-emerald-400 shrink-0" />
                <span className="truncate">{activeSociety.email || 'info@uet.edu.pk'}</span>
              </div>
              <div className="flex items-center gap-2 text-zinc-300">
                <Globe className="w-4 h-4 text-emerald-400 shrink-0" />
                <span className="truncate">{activeSociety.website || 'uet.edu.pk/societies'}</span>
              </div>
            </div>

            {/* Open Hirings Section */}
            <div>
              <h4 className="text-xs font-semibold uppercase tracking-wider text-zinc-400 mb-3 flex items-center gap-1.5">
                <Briefcase className="w-3.5 h-3.5 text-emerald-400" /> Open Recruitments ({societyHirings.length})
              </h4>
              {societyHirings.length > 0 ? (
                <div className="space-y-2.5">
                  {societyHirings.map((h) => (
                    <div
                      key={h.id}
                      className="p-3.5 rounded-2xl bg-zinc-950 border border-zinc-800 flex items-center justify-between"
                    >
                      <div>
                        <p className="text-xs font-bold text-white">{h.title}</p>
                        <p className="text-[11px] text-zinc-400">
                          Deadline: {formatPKTDate(h.deadline)} &bull; {h.total_seats || 10} Seats
                        </p>
                      </div>
                      <button
                        onClick={() => {
                          setActiveSociety(null);
                          onApplyHiring({
                            ...h,
                            society: activeSociety,
                          });
                        }}
                        className="px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold cursor-pointer"
                      >
                        Apply Now
                      </button>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-xs text-zinc-500 italic">No active recruitment cycles at this time.</p>
              )}
            </div>

            {/* Upcoming Events */}
            <div>
              <h4 className="text-xs font-semibold uppercase tracking-wider text-zinc-400 mb-3 flex items-center gap-1.5">
                <Calendar className="w-3.5 h-3.5 text-emerald-400" /> Upcoming Events ({loadingDetail && societyEvents.length === 0 ? '...' : societyEvents.length})
              </h4>
              {societyEvents.length > 0 ? (
                <div className="space-y-2">
                  {societyEvents.map((e) => (
                    <div
                      key={e.id}
                      className="p-3 rounded-2xl bg-zinc-950 border border-zinc-800 flex items-center justify-between text-xs"
                    >
                      <div>
                        <p className="font-semibold text-white">{e.title}</p>
                        <p className="text-[11px] text-zinc-400">{e.venue}</p>
                      </div>
                      <span className="text-[11px] font-mono text-emerald-400">
                        {formatPKTDate(e.start_time, { month: 'short', day: 'numeric' })}
                      </span>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-xs text-zinc-500 italic">No upcoming events scheduled currently.</p>
              )}
            </div>
          </div>
        </Modal>
      )}

      {/* Accessible Propose Society Charter Modal */}
      {proposeModalOpen && (
        <Modal
          isOpen={proposeModalOpen}
          onClose={() => setProposeModalOpen(false)}
          title="Charter a Student Society"
          subtitle="Submit formal charter proposal to UET Directorate of Student Affairs"
          icon={<FileText className="w-5 h-5 text-emerald-400" />}
          maxWidth="md"
        >
          <form onSubmit={handleProposeSociety} className="space-y-4 text-xs">
            <div>
              <label htmlFor="prop-name" className="text-zinc-300 font-medium block mb-1">
                Society Name
              </label>
              <input
                id="prop-name"
                type="text"
                required
                placeholder="e.g. UET Artificial Intelligence Society"
                value={propName}
                onChange={(e) => setPropName(e.target.value)}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
              />
            </div>

            <div>
              <label htmlFor="prop-category" className="text-zinc-300 font-medium block mb-1">
                Category
              </label>
              <select
                id="prop-category"
                value={propCategory}
                onChange={(e) => setPropCategory(e.target.value)}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
              >
                <option value="Technical">Technical</option>
                <option value="Literary">Literary</option>
                <option value="Social">Social</option>
                <option value="Sports">Sports</option>
              </select>
            </div>

            <div>
              <label htmlFor="prop-email" className="text-zinc-300 font-medium block mb-1">
                Official Society Email
              </label>
              <input
                id="prop-email"
                type="email"
                placeholder="society@uet.edu.pk"
                value={propEmail}
                onChange={(e) => setPropEmail(e.target.value)}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500 font-mono"
              />
            </div>

            <div>
              <label htmlFor="prop-desc" className="text-zinc-300 font-medium block mb-1">
                Charter Objective & Mission
              </label>
              <textarea
                id="prop-desc"
                required
                rows={3}
                placeholder="Explain purpose, faculty advisor, target student community..."
                value={propDesc}
                onChange={(e) => setPropDesc(e.target.value)}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500 resize-none"
              />
            </div>

            <div className="flex justify-end gap-2 pt-2 border-t border-zinc-800">
              <button
                type="button"
                onClick={() => setProposeModalOpen(false)}
                className="px-4 py-2 rounded-xl text-zinc-400 hover:text-white cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={submittingProp}
                className="px-5 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold rounded-xl transition cursor-pointer disabled:opacity-50"
              >
                {submittingProp ? 'Submitting...' : 'Submit Charter'}
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
};
