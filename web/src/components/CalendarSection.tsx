import React, { useState, useEffect } from 'react';
import {
  Calendar as CalendarIcon,
  Clock,
  MapPin,
  ExternalLink,
  PlusCircle,
  CheckCircle,
  Share2,
  Filter,
  X,
  Sparkles,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { Event, Profile } from '../types';

interface CalendarSectionProps {
  currentUser: Profile | null;
  onRequireAuth: () => void;
}

export const CalendarSection: React.FC<CalendarSectionProps> = ({
  currentUser,
  onRequireAuth,
}) => {
  const [events, setEvents] = useState<Event[]>([]);
  const [loading, setLoading] = useState(true);
  const [interestedSet, setInterestedSet] = useState<Set<string>>(new Set());
  const [filterType, setFilterType] = useState('all');

  // Submit event modal
  const [createModalOpen, setCreateModalOpen] = useState(false);
  const [title, setTitle] = useState('');
  const [venue, setVenue] = useState('');
  const [description, setDescription] = useState('');
  const [startDate, setStartDate] = useState('');
  const [regLink, setRegLink] = useState('');
  const [selectedSocietyId, setSelectedSocietyId] = useState('');
  const [societiesList, setSocietiesList] = useState<{ id: string; name: string }[]>([]);
  const [submittingEvent, setSubmittingEvent] = useState(false);

  const fetchEvents = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('events')
        .select(`
          *,
          society:societies(*)
        `)
        .order('start_time', { ascending: true });

      if (error) throw error;
      setEvents(data || []);

      if (currentUser) {
        const { data: intData } = await supabase
          .from('event_interests')
          .select('event_id')
          .eq('user_id', currentUser.id);
        const set = new Set<string>((intData || []).map((i) => i.event_id));
        setInterestedSet(set);
      }

      const { data: socData } = await supabase
        .from('societies')
        .select('id, name')
        .eq('status', 'active');
      setSocietiesList(socData || []);
      if (socData && socData.length > 0) setSelectedSocietyId(socData[0].id);
    } catch (err) {
      console.error('Error fetching calendar events:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchEvents();
  }, [currentUser]);

  const handleToggleRSVP = async (event: Event) => {
    if (!currentUser) {
      onRequireAuth();
      return;
    }

    const isInterested = interestedSet.has(event.id);
    const nextSet = new Set(interestedSet);
    if (isInterested) {
      nextSet.delete(event.id);
    } else {
      nextSet.add(event.id);
    }
    setInterestedSet(nextSet);

    try {
      if (isInterested) {
        await supabase
          .from('event_interests')
          .delete()
          .eq('event_id', event.id)
          .eq('user_id', currentUser.id);
      } else {
        await supabase
          .from('event_interests')
          .insert({ event_id: event.id, user_id: currentUser.id, status: 'going' });
      }
    } catch (err) {
      console.error('RSVP error:', err);
      fetchEvents();
    }
  };

  const getGoogleCalendarUrl = (event: Event) => {
    const startTime = new Date(event.start_time).toISOString().replace(/-|:|\.\d\d\d/g, '');
    const endTime = new Date(event.end_time).toISOString().replace(/-|:|\.\d\d\d/g, '');
    const text = encodeURIComponent(event.title);
    const details = encodeURIComponent(
      `${event.description}\n\nOrganized by: ${event.society?.name || 'UET Campus'}`
    );
    const location = encodeURIComponent(event.venue);
    return `https://calendar.google.com/calendar/render?action=TEMPLATE&text=${text}&dates=${startTime}/${endTime}&details=${details}&location=${location}`;
  };

  const handleCreateEvent = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!currentUser) {
      onRequireAuth();
      return;
    }

    setSubmittingEvent(true);
    try {
      const startIso = new Date(startDate).toISOString();
      const endIso = new Date(new Date(startDate).getTime() + 4 * 3600 * 1000).toISOString();

      const { data, error } = await supabase
        .from('events')
        .insert({
          society_id: selectedSocietyId,
          title: title.trim(),
          description: description.trim(),
          venue: venue.trim(),
          start_time: startIso,
          end_time: endIso,
          registration_link: regLink.trim() || null,
          is_public: true,
        })
        .select(`*, society:societies(*)`)
        .single();

      if (error) throw error;
      setEvents((prev) => [...prev, data]);
      setCreateModalOpen(false);
      setTitle('');
      setVenue('');
      setDescription('');
      setStartDate('');
      setRegLink('');
    } catch (err: any) {
      console.error('Create event error:', err);
      alert(err.message || 'Failed to create event. Society authorization needed.');
    } finally {
      setSubmittingEvent(false);
    }
  };

  const filteredEvents = events.filter((e) => {
    if (filterType === 'all') return true;
    if (filterType === 'technical') return e.society?.category === 'Technical';
    if (filterType === 'literary') return e.society?.category === 'Literary';
    if (filterType === 'social') return e.society?.category === 'Social';
    return true;
  });

  return (
    <div className="space-y-6 animate-fadeIn">
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-xl sm:text-2xl font-bold text-white flex items-center gap-2">
            <CalendarIcon className="w-6 h-6 text-emerald-400" /> Campus Schedule & Hackathons
          </h2>
          <p className="text-xs text-slate-400 mt-1">
            Never miss an official UET competition, annual dinner, or workshop
          </p>
        </div>

        <div className="flex items-center gap-2">
          {currentUser && (
            <button
              onClick={() => setCreateModalOpen(true)}
              className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-xs font-semibold text-white transition"
            >
              <PlusCircle className="w-4 h-4 text-emerald-400" />
              <span>Schedule Event</span>
            </button>
          )}
        </div>
      </div>

      {/* Filter Tabs */}
      <div className="flex items-center gap-2 overflow-x-auto pb-1">
        {[
          { id: 'all', label: 'All Events' },
          { id: 'technical', label: 'Tech & Hackathons' },
          { id: 'literary', label: 'Debates & Arts' },
          { id: 'social', label: 'Social & Environment' },
        ].map((tab) => (
          <button
            key={tab.id}
            onClick={() => setFilterType(tab.id)}
            className={`px-3 py-1.5 rounded-xl text-xs font-medium whitespace-nowrap transition ${
              filterType === tab.id
                ? 'bg-emerald-600 text-white shadow-md shadow-emerald-900/30'
                : 'bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Event Cards Grid */}
      {loading ? (
        <div className="space-y-4">
          {[1, 2, 3].map((i) => (
            <div
              key={i}
              className="bg-slate-900/60 border border-slate-800 rounded-3xl p-6 h-40 animate-pulse"
            />
          ))}
        </div>
      ) : filteredEvents.length > 0 ? (
        <div className="space-y-4">
          {filteredEvents.map((evt) => {
            const startDate = new Date(evt.start_time);
            const isRSVPed = interestedSet.has(evt.id);

            return (
              <div
                key={evt.id}
                className="bg-slate-900/80 border border-slate-800 hover:border-emerald-500/40 rounded-3xl p-6 flex flex-col md:flex-row items-start md:items-center justify-between gap-6 shadow-xl transition"
              >
                {/* Date Badge + Details */}
                <div className="flex items-start gap-4">
                  {/* Big Date Badge */}
                  <div className="w-16 h-16 rounded-2xl bg-slate-950 border border-slate-800 flex flex-col items-center justify-center shrink-0">
                    <span className="text-[10px] font-bold text-emerald-400 uppercase tracking-wider">
                      {startDate.toLocaleDateString('en-US', { month: 'short' })}
                    </span>
                    <span className="text-xl font-black text-white leading-tight">
                      {startDate.getDate()}
                    </span>
                  </div>

                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-[11px] font-semibold text-emerald-400 uppercase tracking-wider">
                        {evt.society?.name || 'Campus Wide'}
                      </span>
                      <span className="text-slate-600">&bull;</span>
                      <span className="text-[11px] text-slate-400 flex items-center gap-1 font-mono">
                        <Clock className="w-3 h-3 text-slate-500" />
                        {startDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                      </span>
                    </div>

                    <h3 className="text-base font-bold text-white mb-1.5">{evt.title}</h3>
                    <p className="text-xs text-slate-300 max-w-xl line-clamp-2 leading-relaxed mb-2">
                      {evt.description}
                    </p>

                    <div className="flex items-center gap-1.5 text-xs text-slate-400">
                      <MapPin className="w-3.5 h-3.5 text-slate-500 shrink-0" />
                      <span>{evt.venue}</span>
                    </div>
                  </div>
                </div>

                {/* Right Action buttons */}
                <div className="flex items-center gap-2 shrink-0 w-full md:w-auto justify-end pt-3 md:pt-0 border-t md:border-t-0 border-slate-800">
                  {/* Google Calendar Sync */}
                  <a
                    href={getGoogleCalendarUrl(evt)}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="p-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition"
                    title="Add to Google Calendar"
                  >
                    <CalendarIcon className="w-4 h-4 text-emerald-400" />
                  </a>

                  {/* External Reg Link if available */}
                  {evt.registration_link && (
                    <a
                      href={evt.registration_link}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-semibold text-slate-200 hover:text-white flex items-center gap-1.5 transition"
                    >
                      <ExternalLink className="w-3.5 h-3.5" />
                      <span>Register</span>
                    </a>
                  )}

                  {/* RSVP Button */}
                  <button
                    onClick={() => handleToggleRSVP(evt)}
                    className={`px-4 py-2 rounded-xl text-xs font-semibold flex items-center gap-1.5 transition ${
                      isRSVPed
                        ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/40'
                        : 'bg-emerald-600 hover:bg-emerald-500 text-white shadow-md shadow-emerald-900/30'
                    }`}
                  >
                    <CheckCircle className="w-3.5 h-3.5" />
                    <span>{isRSVPed ? 'Going' : 'RSVP'}</span>
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        <div className="bg-slate-900 border border-slate-800 rounded-3xl p-12 text-center">
          <p className="text-slate-400 text-sm">No scheduled events in this category.</p>
        </div>
      )}

      {/* Schedule Event Modal */}
      {createModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-md animate-fadeIn">
          <div className="bg-slate-900 border border-slate-700/80 rounded-2xl w-full max-w-md shadow-2xl p-6">
            <div className="flex items-center justify-between pb-4 border-b border-slate-800 mb-4">
              <h3 className="font-bold text-white text-base">Schedule Campus Event</h3>
              <button
                onClick={() => setCreateModalOpen(false)}
                className="text-slate-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleCreateEvent} className="space-y-4 text-xs">
              <div>
                <label className="text-slate-300 font-medium block mb-1">Hosting Society</label>
                <select
                  value={selectedSocietyId}
                  onChange={(e) => setSelectedSocietyId(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                >
                  {societiesList.map((soc) => (
                    <option key={soc.id} value={soc.id}>
                      {soc.name}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-slate-300 font-medium block mb-1">Event Title</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. AI Prompt Engineering Workshop"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="text-slate-300 font-medium block mb-1">Date & Time</label>
                <input
                  type="datetime-local"
                  required
                  value={startDate}
                  onChange={(e) => setStartDate(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="text-slate-300 font-medium block mb-1">Venue / Hall</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Chemical Seminar Hall or CS Lab 4"
                  value={venue}
                  onChange={(e) => setVenue(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="text-slate-300 font-medium block mb-1">Description</label>
                <textarea
                  required
                  rows={3}
                  placeholder="Brief details about session, speakers, or competition..."
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500 resize-none"
                />
              </div>

              <div>
                <label className="text-slate-300 font-medium block mb-1">
                  Registration Form Link (Optional)
                </label>
                <input
                  type="url"
                  placeholder="https://forms.gle/..."
                  value={regLink}
                  onChange={(e) => setRegLink(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500 font-mono"
                />
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setCreateModalOpen(false)}
                  className="px-4 py-2 rounded-xl text-slate-400 hover:text-white"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submittingEvent}
                  className="px-5 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold rounded-xl"
                >
                  {submittingEvent ? 'Publishing...' : 'Schedule Event'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
