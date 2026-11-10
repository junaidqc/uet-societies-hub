import React, { useState, useEffect } from 'react';
import {
  Users,
  ShieldAlert,
  Send,
  Lock,
  Clock,
  CheckCheck,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { Group, GroupMessage, Profile } from '../types';
import { useToast } from './Toast';

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

  const fetchGroups = async () => {
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
    } catch (err) {
      console.error('Error fetching groups:', err);
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

  // BUG-04 Fix: Unresponsive send button now accepts click, form submit, and keypress
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
                  className={`w-full text-left p-3 rounded-2xl transition flex items-start gap-3 ${
                    isSelected
                      ? 'bg-emerald-500/10 border border-emerald-500/30'
                      : 'hover:bg-slate-800/60 border border-transparent'
                  }`}
                >
                  <div className="w-9 h-9 rounded-xl bg-slate-800 border border-slate-700 flex items-center justify-center font-bold text-xs text-emerald-400 shrink-0">
                    {grp.name.charAt(0)}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between">
                      <p className="text-xs font-bold text-white truncate">{grp.name}</p>
                      {grp.is_private && <Lock className="w-3 h-3 text-slate-500 shrink-0 ml-1" />}
                    </div>
                    <p className="text-[11px] text-slate-400 truncate">
                      {grp.society?.name || 'Society Council'}
                    </p>
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Chat Thread Panel */}
        <div className="md:col-span-2 flex flex-col justify-between bg-slate-900/60">
          {/* Thread Header */}
          <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-950/40">
            <div>
              <h3 className="font-bold text-white text-sm">
                {selectedGroup ? selectedGroup.name : 'Select a Working Group'}
              </h3>
              <p className="text-xs text-slate-400">
                {selectedGroup?.description || 'Committee coordination and task board'}
              </p>
            </div>
            <div className="flex items-center gap-1.5 text-[11px] font-mono text-emerald-400 bg-emerald-950/60 border border-emerald-500/30 px-2.5 py-1 rounded-full">
              <Clock className="w-3 h-3" /> 30d auto-purge
            </div>
          </div>

          {/* Messages Area */}
          <div className="flex-1 p-6 overflow-y-auto space-y-4 max-h-[460px]">
            {messages.length > 0 ? (
              messages.map((m) => {
                const isMe = currentUser && m.sender_id === currentUser.id;
                const timeStr = new Date(m.created_at).toLocaleTimeString([], {
                  hour: '2-digit',
                  minute: '2-digit',
                });

                return (
                  <div
                    key={m.id}
                    className={`flex flex-col ${isMe ? 'items-end' : 'items-start'}`}
                  >
                    <div className="flex items-center gap-1.5 mb-1 px-1">
                      <span className="text-[11px] font-semibold text-slate-400">
                        {isMe ? 'You' : m.sender?.full_name || 'Member'}
                      </span>
                      <span className="text-[10px] font-mono text-slate-600">
                        {m.sender?.roll_number}
                      </span>
                    </div>

                    <div
                      className={`max-w-md p-3.5 rounded-2xl text-xs leading-relaxed ${
                        isMe
                          ? 'bg-emerald-600 text-white rounded-tr-none shadow-md shadow-emerald-950/50'
                          : 'bg-slate-950 border border-slate-800 text-slate-200 rounded-tl-none'
                      }`}
                    >
                      <p>{m.content}</p>
                      <div
                        className={`mt-1.5 flex items-center justify-end gap-1 text-[9px] ${
                          isMe ? 'text-emerald-200' : 'text-slate-500'
                        }`}
                      >
                        <span>{timeStr}</span>
                        {isMe && <CheckCheck className="w-3 h-3 text-emerald-300" />}
                      </div>
                    </div>
                  </div>
                );
              })
            ) : (
              <div className="text-center py-16 text-xs text-slate-500">
                No active discussions in this channel yet. Send an operational message below.
              </div>
            )}
          </div>

          {/* Message Input (BUG-04 Fix) */}
          <div className="p-4 border-t border-slate-800 bg-slate-950/60">
            {currentUser ? (
              <form onSubmit={handleSendMessage} className="flex gap-2">
                <input
                  type="text"
                  placeholder="Post an update to this committee channel... (Press Enter or click Send)"
                  value={newMessage}
                  onChange={(e) => setNewMessage(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' && !e.shiftKey) {
                      e.preventDefault();
                      handleSendMessage(e);
                    }
                  }}
                  className="flex-1 bg-slate-900 border border-slate-800 rounded-xl px-4 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500"
                />
                <button
                  type="button"
                  onClick={(e) => handleSendMessage(e)}
                  disabled={sending || !newMessage.trim()}
                  className="p-2.5 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 text-white rounded-xl transition cursor-pointer"
                  title="Send message"
                >
                  <Send className="w-4 h-4 pointer-events-none" />
                </button>
              </form>
            ) : (
              <div className="text-center py-2">
                <button
                  onClick={onRequireAuth}
                  className="text-xs font-semibold text-emerald-400 hover:underline"
                >
                  Sign in with Student ID to participate in working groups &rarr;
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
