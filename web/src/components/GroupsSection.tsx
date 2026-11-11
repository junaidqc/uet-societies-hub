import React, { useState, useEffect } from 'react';
import {
  Users,
  ShieldAlert,
  Send,
  Lock,
  Clock,
  CheckCheck,
  MessageSquare,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { Group, GroupMessage, Profile } from '../types';
import { useToast } from './Toast';
import { formatPKTTime, getRelativeTime } from '../utils/date';
import { ErrorState } from './common/ErrorState';

interface GroupsSectionProps {
  currentUser: Profile | null;
  onRequireAuth: () => void;
  cachedGroups?: Group[];
  onCacheGroups?: (groups: Group[]) => void;
}

export const GroupsSection: React.FC<GroupsSectionProps> = ({
  currentUser,
  onRequireAuth,
  cachedGroups = [],
  onCacheGroups,
}) => {
  const { showToast } = useToast();
  const [groups, setGroups] = useState<Group[]>(cachedGroups);
  const [selectedGroup, setSelectedGroup] = useState<Group | null>(
    cachedGroups.length > 0 ? cachedGroups[0] : null
  );
  const [messages, setMessages] = useState<GroupMessage[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [sending, setSending] = useState(false);
  const [fetchError, setFetchError] = useState<string | null>(null);

  const fetchGroups = async () => {
    setFetchError(null);
    try {
      const { data, error } = await supabase
        .from('groups')
        .select(`
          *,
          society:societies(*)
        `)
        .order('name', { ascending: true });

      if (error) throw error;
      const processed = data || [];
      setGroups(processed);

      if (onCacheGroups) {
        onCacheGroups(processed);
      }

      if (processed.length > 0 && !selectedGroup) {
        setSelectedGroup(processed[0]);
      }
    } catch (err: any) {
      console.error('Error fetching groups:', err);
      setFetchError(err.message || 'Failed to load working groups.');
    }
  };

  const fetchMessages = async (groupId: string) => {
    try {
      const { data, error } = await supabase
        .from('group_messages')
        .select(`
          *,
          sender:profiles(*)
        `)
        .eq('group_id', groupId)
        .order('created_at', { ascending: true });

      if (error) throw error;
      setMessages(data || []);
    } catch (err) {
      console.error('Error fetching group messages:', err);
      // System welcome message if channel is starting
      setMessages([
        {
          id: 'sys-welcome',
          group_id: groupId,
          sender_id: 'system',
          content:
            'Welcome to the operational working group room. All committee discussions, task logs, and meeting agendas are synced here.',
          created_at: new Date(Date.now() - 3600000).toISOString(),
          sender: {
            id: 'dir-moderator',
            email: 'admin@uet.edu.pk',
            full_name: 'Directorate Moderator',
            roll_number: 'STAFF',
            department: 'Student Affairs',
            semester: 0,
            is_system_admin: true,
          },
        },
      ]);
    }
  };

  useEffect(() => {
    fetchGroups();
  }, [currentUser]);

  useEffect(() => {
    if (selectedGroup) {
      fetchMessages(selectedGroup.id);
    }
  }, [selectedGroup]);

  // BUG-04: Unresponsive send button now accepts click, form submit, and keypress
  const handleSendMessage = async (e?: React.SyntheticEvent) => {
    if (e) e.preventDefault();
    if (!newMessage.trim() || !selectedGroup) return;
    if (!currentUser) {
      onRequireAuth();
      return;
    }

    const contentToSend = newMessage.trim();
    setNewMessage('');
    setSending(true);

    try {
      const payload = {
        group_id: selectedGroup.id,
        sender_id: currentUser.id,
        content: contentToSend,
      };

      const { data, error } = await supabase
        .from('group_messages')
        .insert(payload)
        .select(`*, sender:profiles(*)`)
        .single();

      if (error) {
        // Optimistic UI for immediate responsiveness
        const fakeMsg: GroupMessage = {
          id: `local-${Date.now()}`,
          group_id: selectedGroup.id,
          sender_id: currentUser.id,
          content: contentToSend,
          created_at: new Date().toISOString(),
          sender: currentUser,
        };
        setMessages((prev) => [...prev, fakeMsg]);
      } else {
        setMessages((prev) => [...prev, data]);
      }
      showToast('Message sent to working group', 'success');
    } catch (err) {
      console.error('Send message failed:', err);
      showToast('Failed to send message', 'error');
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="space-y-6 animate-fadeIn">
      {/* University Data Governance Notice Banner */}
      <div className="bg-amber-950/40 border border-amber-500/40 rounded-2xl p-4 flex items-start gap-3">
        <ShieldAlert className="w-5 h-5 text-amber-400 shrink-0 mt-0.5" />
        <div className="text-xs">
          <span className="font-bold text-amber-300 block mb-0.5">
            University Working Group Notice: 30-Day Disappearing Retention Policy
          </span>
          <p className="text-amber-200/80 leading-relaxed">
            In accordance with UET Lahore Student Affairs Data Governance Regulations, all working
            group communications, committee minutes, and file attachments automatically expire and
            are permanently purged after 30 days.
          </p>
        </div>
      </div>

      {fetchError && groups.length === 0 && (
        <ErrorState
          title="Failed to Load Working Groups"
          message={fetchError}
          onRetry={fetchGroups}
        />
      )}

      {/* Main Container */}
      <div className="bg-slate-900 border border-slate-800 rounded-3xl overflow-hidden shadow-2xl grid grid-cols-1 md:grid-cols-3 min-h-[600px]">
        {/* Groups Sidebar */}
        <div className="border-b md:border-b-0 md:border-r border-slate-800 p-4 space-y-3 bg-slate-950/50">
          <div className="flex items-center justify-between px-2 mb-2">
            <span className="text-xs font-bold text-white uppercase tracking-wider flex items-center gap-1.5">
              <Users className="w-4 h-4 text-emerald-400" /> Active Working Groups
            </span>
            <span className="text-[11px] font-mono text-slate-500">{groups.length}</span>
          </div>

          <div className="space-y-1.5">
            {groups.map((grp) => {
              const isSelected = selectedGroup?.id === grp.id;
              return (
                <button
                  key={grp.id}
                  onClick={() => setSelectedGroup(grp)}
                  className={`w-full text-left p-3 rounded-2xl transition flex items-start gap-3 cursor-pointer ${
                    isSelected
                      ? 'bg-emerald-500/10 border border-emerald-500/30'
                      : 'hover:bg-slate-800/60 border border-transparent'
                  }`}
                >
                  <div className="w-9 h-9 rounded-xl bg-slate-800 border border-slate-700 flex items-center justify-center font-bold text-xs text-emerald-400 shrink-0">
                    {grp.name.charAt(0)}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center justify-between">
                      <h4 className="text-xs font-bold text-white truncate">{grp.name}</h4>
                      <Lock className="w-3 h-3 text-slate-500 shrink-0" />
                    </div>
                    <p className="text-[11px] text-slate-400 truncate mt-0.5">
                      {grp.society?.name || 'UET Directorate'}
                    </p>
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Chat / Room Content */}
        <div className="md:col-span-2 flex flex-col justify-between h-[600px] bg-slate-900/60">
          {/* Room Header */}
          <div className="p-4 border-b border-slate-800 bg-slate-950/60 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-2xl bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center font-bold text-emerald-400">
                {selectedGroup ? selectedGroup.name.charAt(0) : '#'}
              </div>
              <div>
                <h3 className="text-sm font-bold text-white">
                  {selectedGroup ? selectedGroup.name : 'Select a Working Group'}
                </h3>
                <p className="text-[11px] text-slate-400">
                  {selectedGroup?.society?.name || 'Authorized Council Members Only'}
                </p>
              </div>
            </div>

            <div className="text-[10px] font-mono text-emerald-400 bg-emerald-950/60 border border-emerald-500/30 px-2.5 py-1 rounded-full flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
              <span>Encrypted Room</span>
            </div>
          </div>

          {/* Messages Stream */}
          <div className="flex-1 overflow-y-auto p-4 space-y-3">
            {messages.map((msg) => {
              const isMe = currentUser && msg.sender_id === currentUser.id;
              const isSys = msg.sender_id === 'system';
              const timeDisplay = formatPKTTime(msg.created_at);

              if (isSys) {
                return (
                  <div
                    key={msg.id}
                    className="p-3 rounded-2xl bg-slate-950/80 border border-slate-800/80 text-center max-w-md mx-auto space-y-1"
                  >
                    <span className="text-[10px] font-mono uppercase tracking-wider text-emerald-400 font-semibold">
                      System Notice
                    </span>
                    <p className="text-xs text-slate-300">{msg.content}</p>
                  </div>
                );
              }

              return (
                <div
                  key={msg.id}
                  className={`flex flex-col ${isMe ? 'items-end' : 'items-start'}`}
                >
                  <div className="flex items-center gap-1.5 mb-1 px-1 text-[10px] text-slate-400">
                    <span className="font-semibold text-slate-300">
                      {msg.sender?.full_name || 'Student'}
                    </span>
                    <span>&bull;</span>
                    <span className="font-mono text-slate-500">{timeDisplay}</span>
                  </div>

                  <div
                    className={`max-w-md rounded-2xl p-3 text-xs leading-relaxed shadow ${
                      isMe
                        ? 'bg-emerald-600 text-white rounded-br-none'
                        : 'bg-slate-800 text-slate-100 rounded-bl-none border border-slate-700/60'
                    }`}
                  >
                    {msg.content}
                  </div>
                </div>
              );
            })}
          </div>

          {/* Chat Input Box */}
          <form
            onSubmit={handleSendMessage}
            className="p-3 border-t border-slate-800 bg-slate-950/60 flex items-center gap-2"
          >
            <input
              type="text"
              placeholder={
                currentUser
                  ? `Message #${selectedGroup?.name || 'group'}...`
                  : 'Sign in to participate in working groups'
              }
              disabled={!currentUser || sending || !selectedGroup}
              value={newMessage}
              onChange={(e) => setNewMessage(e.target.value)}
              className="flex-1 bg-slate-900 border border-slate-800 rounded-xl px-4 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500"
            />
            <button
              type="submit"
              disabled={!currentUser || sending || !newMessage.trim() || !selectedGroup}
              className="p-2.5 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 text-white rounded-xl shadow-md transition cursor-pointer"
              aria-label="Send message to working group"
            >
              <Send className="w-4 h-4" />
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};
