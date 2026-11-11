import React, { useState, useEffect } from 'react';
import {
  Calendar as CalendarIcon,
  Clock,
  MapPin,
  Ticket,
  PlusCircle,
  CheckCircle,
  History,
  Sparkles,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { Event, Profile } from '../types';
import { useToast } from './Toast';
import { formatPKTDate, formatPKTTime } from '../utils/date';
import { ErrorState } from './common/ErrorState';
import { Modal } from './common/Modal';

interface CalendarSectionProps {
  currentUser: Profile | null;
  onRequireAuth: () => void;
  onRegisterEvent: (event: Event) => void;
  cachedEvents?: Event[];
  onCacheEvents?: (events: Event[]) => void;
}

export const CalendarSection: React.FC<CalendarSectionProps> = ({
  currentUser,
  onRequireAuth,
  onRegisterEvent,
  cachedEvents = [],
  onCacheEvents,
}) => {
  const { showToast } = useToast();
  const [events, setEvents] = useState<Event[]>(cachedEvents);
  const [loading, setLoading] = useState(cachedEvents.length === 0);
  const [fetchError, setFetchError] = useState<string | null>(null);
  const [interestedSet, setInterestedSet] = useState<Set<string>>(new Set());
  
  // DEF-08: Time filter (Upcoming vs Past Archive) & Category filter
  const [timeFilter, setTimeFilter] = useState<'upcoming' | 'past'>('upcoming');
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
    if (events.length === 0) setLoading(true);
    setFetchError(null);
    try {
      const { data, error } = await supabase
        .from('events')
        .select(`
          *,
          society:societies(*)
        `)
        .order('start_time', { ascending: true });

      if (error) throw error;
      const processed = data || [];
      setEvents(processed);

      if (onCacheEvents) {
        onCacheEvents(processed);
      }

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
    } catch (err: any) {
      console.error('Error fetching calendar events:', err);
      setFetchError(err.message || 'Failed to load campus calendar.');
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
      showToast(`Removed RSVP for ${event.title}`, 'info');
    } else {
      nextSet.add(event.id);
      showToast(`You're going to ${event.title}!`, 'success');
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
    const start = new Date(event.start_time);
    const end = event.end_time
      ? new Date(event.end_time)
      : new Date(start.getTime() + 3 * 3600 * 1000);

    const startTime = start.toISOString().replace(/-|:|\.\d\d\d/g, '');
    const endTime = end.toISOString().replace(/-|:|\.\d\d\d/g, '');
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
      showToast('Event successfully added to campus calendar!', 'success');
    } catch (err: any) {
      console.error('Create event error:', err);
      showToast(err.message || 'Failed to create event. Society authorization needed.', 'error');
    } finally {
      setSubmittingEvent(false);
    }
  };

  // DEF-08: Split upcoming vs past events
  const nowTime = Date.now();
  const upcomingEvents = events.filter((e) => {
    const end = e.end_time ? new Date(e.end_time).getTime() : new Date(e.start_time).getTime() + 3 * 3600 * 1000;
    return end >= nowTime;
  });

  const pastEvents = events.filter((e) => {
    const end = e.end_time ? new Date(e.end_time).getTime() : new Date(e.start_time).getTime() + 3 * 3600 * 1000;
    return end < nowTime;
  });

  const baseEventsList = timeFilter === 'upcoming' ? upcomingEvents : pastEvents;

  const filteredEvents = baseEventsList.filter((e) => {
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
          <h2 className="text-xl sm:text-2xl font-black text-white flex items-center gap-2">
            <CalendarIcon className="w-6 h-6 text-emerald-400" /> Campus Schedule & Flagship Hackathons
          </h2>
          <p className="text-xs text-slate-400 mt-1">
            Verified schedules for competitions, guest lectures, annual dinners, and technical workshops (Asia/Karachi)
          </p>
        </div>

        <div className="flex items-center gap-2">
          {currentUser && (
            <button
              onClick={() => setCreateModalOpen(true)}
              className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-xs font-semibold text-white transition cursor-pointer"
            >
              <PlusCircle className="w-4 h-4 text-emerald-400" />
              <span>Schedule Event</span>
            </button>
          )}
        </div>
      </div>

      {/* DEF-08: Time Segment Control (Upcoming vs Past Archive) */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-800 pb-3">
        <div className="inline-flex p-1 rounded-2xl bg-slate-900 border border-slate-800">
          <button
            type="button"
            onClick={() => setTimeFilter('upcoming')}
            className={`px-4 py-2 rounded-xl text-xs font-bold transition flex items-center gap-2 ${
              timeFilter === 'upcoming'
                ? 'bg-emerald-600 text-white shadow-md shadow-emerald-950'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <CalendarIcon className="w-3.5 h-3.5" />
            <span>Upcoming ({upcomingEvents.length})</span>
          </button>
          <button
            type="button"
            onClick={() => setTimeFilter('past')}
            className={`px-4 py-2 rounded-xl text-xs font-bold transition flex items-center gap-2 ${
              timeFilter === 'past'
                ? 'bg-slate-800 text-white shadow-md'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <History className="w-3.5 h-3.5" />
            <span>Past Archive ({pastEvents.length})</span>
          </button>
        </div>

        {/* Category Filter Tabs */}
        <div className="flex items-center gap-2 overflow-x-auto pb-1">
          {[
            { id: 'all', label: 'All Categories' },
            { id: 'technical', label: 'Tech & Hackathons' },
            { id: 'literary', label: 'Debates & Arts' },
            { id: 'social', label: 'Social & Environment' },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setFilterType(tab.id)}
              className={`px-3 py-1.5 rounded-xl text-xs font-medium whitespace-nowrap transition cursor-pointer ${
                filterType === tab.id
                  ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/40'
                  : 'bg-slate-900/60 hover:bg-slate-800 text-slate-300 border border-slate-800'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* Error state */}
      {fetchError && events.length === 0 && (
        <ErrorState
          title="Failed to Load Calendar Events"
          message={fetchError}
          onRetry={fetchEvents}
        />
      )}

      {/* Event Cards Grid */}
      {loading ? (
        <div className="space-y-4">
          {[1, 2, 3].map((i) => (
            <div
              key={i}
              className="bg-slate-900/80 border border-slate-800 rounded-3xl p-6 flex gap-4 animate-pulse"
            >
              <div className="w-16 h-16 rounded-2xl bg-slate-800 shrink-0" />
              <div className="flex-1 space-y-2.5">
                <div className="h-4 w-40 bg-slate-800 rounded" />
                <div className="h-5 w-60 bg-slate-800 rounded" />
                <div className="h-3 w-full bg-slate-800/60 rounded" />
              </div>
            </div>
          ))}
        </div>
      ) : filteredEvents.length > 0 ? (
        <div className="space-y-4">
          {filteredEvents.map((evt) => {
            const isRSVPed = interestedSet.has(evt.id);
            const dateStr = formatPKTDate(evt.start_time);
            const timeStr = formatPKTTime(evt.start_time);
            const rawDate = new Date(evt.start_time);

            return (
              <div
                key={evt.id}
                className="tech-card bg-slate-900/90 border border-slate-800/90 hover:border-emerald-500/40 rounded-3xl p-6 flex flex-col md:flex-row items-start md:items-center justify-between gap-6 shadow-xl transition-all"
              >
                {/* Date Badge + Details */}
                <div className="flex items-start gap-4">
                  {/* Big Date Badge */}
                  <div className="w-16 h-16 rounded-2xl bg-slate-950 border border-slate-800 flex flex-col items-center justify-center shrink-0 shadow-inner">
                    <span className="text-[10px] font-bold text-emerald-400 uppercase tracking-wider">
                      {rawDate.toLocaleDateString('en-US', { month: 'short', timeZone: 'Asia/Karachi' })}
                    </span>
                    <span className="text-xl font-black text-white leading-tight">
                      {rawDate.toLocaleDateString('en-US', { day: 'numeric', timeZone: 'Asia/Karachi' })}
                    </span>
                  </div>

                  <div>
                    <div className="flex items-center gap-2 mb-1 flex-wrap">
                      <span className="text-[11px] font-semibold text-emerald-400 uppercase tracking-wider">
                        {evt.society?.name || 'Campus Wide'}
                      </span>
                      <span className="text-slate-600">&bull;</span>
                      <span className="text-[11px] text-slate-400 flex items-center gap-1 font-mono">
                        <Clock className="w-3 h-3 text-slate-500" />
                        {timeStr} PKT
                      </span>
                      <span className="text-slate-600">&bull;</span>
                      <span className="text-[11px] text-slate-500 font-mono">
                        {dateStr}
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
                    className="p-2.5 rounded-xl bg-slate-800/90 hover:bg-slate-700 text-slate-300 hover:text-white transition cursor-pointer"
                    title="Add to Google Calendar"
                    aria-label="Add to Google Calendar"
                  >
                    <CalendarIcon className="w-4 h-4 text-emerald-400" />
                  </a>

                  {/* DEF-18 Fix: Unambiguous Ticket icon for event registration */}
                  <button
                    type="button"
                    onClick={() => onRegisterEvent(evt)}
                    className="px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-semibold text-slate-200 hover:text-white flex items-center gap-1.5 transition cursor-pointer"
                  >
                    <Ticket className="w-3.5 h-3.5 text-emerald-400" />
                    <span>Register</span>
                  </button>

                  {/* RSVP Button */}
                  <button
                    type="button"
                    onClick={() => handleToggleRSVP(evt)}
                    className={`px-4 py-2 rounded-xl text-xs font-semibold flex items-center gap-1.5 transition cursor-pointer ${
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
      ) : !fetchError ? (
        <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-12 text-center">
          <p className="text-slate-400 text-sm">
            {timeFilter === 'upcoming'
              ? 'No upcoming events scheduled in this category.'
              : 'No past archived events in this category.'}
          </p>
        </div>
      ) : null}

      {/* Accessible Schedule Event Modal */}
      <Modal
        isOpen={createModalOpen}
        onClose={() => setCreateModalOpen(false)}
        title="Schedule Campus Event"
        description="Publish an official competition or session to the student calendar"
        maxWidth="max-w-md"
      >
        <form onSubmit={handleCreateEvent} className="p-6 space-y-4 text-xs">
          <div>
            <label htmlFor="create-event-society" className="text-slate-300 font-medium block mb-1">
              Hosting Society
            </label>
            <select
              id="create-event-society"
              value={selectedSocietyId}
              onChange={(e) => setSelectedSocietyId(e.target.value)}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500 cursor-pointer"
            >
              {societiesList.map((soc) => (
                <option key={soc.id} value={soc.id}>
                  {soc.name}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label htmlFor="create-event-title" className="text-slate-300 font-medium block mb-1">
              Event Title
            </label>
            <input
              id="create-event-title"
              type="text"
              required
              placeholder="e.g. AI Prompt Engineering Workshop"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
            />
          </div>

          <div>
            <label htmlFor="create-event-datetime" className="text-slate-300 font-medium block mb-1">
              Date & Time (Asia/Karachi)
            </label>
            <input
              id="create-event-datetime"
              type="datetime-local"
              required
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
            />
          </div>

          <div>
            <label htmlFor="create-event-venue" className="text-slate-300 font-medium block mb-1">
              Venue / Hall
            </label>
            <input
              id="create-event-venue"
              type="text"
              required
              placeholder="e.g. Chemical Seminar Hall or CS Lab 4"
              value={venue}
              onChange={(e) => setVenue(e.target.value)}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
            />
          </div>

          <div>
            <label htmlFor="create-event-desc" className="text-slate-300 font-medium block mb-1">
              Description
            </label>
            <textarea
              id="create-event-desc"
              required
              rows={3}
              placeholder="Brief details about session, speakers, or competition..."
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500 resize-none"
            />
          </div>

          <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
            <button
              type="button"
              onClick={() => setCreateModalOpen(false)}
              className="px-4 py-2 rounded-xl text-slate-400 hover:text-white transition cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={submittingEvent}
              className="px-5 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold rounded-xl shadow-md shadow-emerald-950/40 transition cursor-pointer"
            >
              {submittingEvent ? 'Publishing...' : 'Schedule Event'}
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
};
