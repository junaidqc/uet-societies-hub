import React, { useState, useEffect } from 'react';
import {
  Heart,
  MessageCircle,
  Share2,
  Calendar,
  MapPin,
  Pin,
  Clock,
  ChevronRight,
  PlusCircle,
  Send,
  Search,
  X,
  Ticket,
  Sparkles,
  Users,
  Award,
  Flame,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { Post, Event, Profile, PostComment } from '../types';
import { useToast } from './Toast';
import { formatPKTDate, getRelativeTime } from '../utils/date';
import { normalizeSearchQuery } from '../utils/search';
import { ErrorState } from './common/ErrorState';
import { Modal } from './common/Modal';
import { MarqueeTicker } from './common/MarqueeTicker';
import { StatCounter } from './common/StatCounter';

interface FeedSectionProps {
  currentUser: Profile | null;
  onRequireAuth: () => void;
  onNavigateToCalendar: () => void;
  onNavigateToSocieties: () => void;
  onRegisterEvent: (event: Event) => void;
  cachedPosts?: Post[];
  cachedEvents?: Event[];
  onCacheData?: (posts: Post[], events: Event[]) => void;
}

export const FeedSection: React.FC<FeedSectionProps> = ({
  currentUser,
  onRequireAuth,
  onNavigateToCalendar,
  onNavigateToSocieties,
  onRegisterEvent,
  cachedPosts = [],
  cachedEvents = [],
  onCacheData,
}) => {
  const { showToast } = useToast();
  const [posts, setPosts] = useState<Post[]>(cachedPosts);
  const [events, setEvents] = useState<Event[]>(cachedEvents);
  const [loading, setLoading] = useState(cachedPosts.length === 0);
  const [fetchError, setFetchError] = useState<string | null>(null);
  const [filterCategory, setFilterCategory] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');

  // Comments modal state
  const [activeCommentsPost, setActiveCommentsPost] = useState<Post | null>(null);
  const [comments, setComments] = useState<PostComment[]>([]);
  const [loadingComments, setLoadingComments] = useState(false);
  const [newCommentText, setNewCommentText] = useState('');
  const [submittingComment, setSubmittingComment] = useState(false);

  // Create post modal state
  const [createPostOpen, setCreatePostOpen] = useState(false);
  const [newPostTitle, setNewPostTitle] = useState('');
  const [newPostContent, setNewPostContent] = useState('');
  const [selectedSocietyId, setSelectedSocietyId] = useState('');
  const [submittingPost, setSubmittingPost] = useState(false);
  const [societiesList, setSocietiesList] = useState<{ id: string; name: string }[]>([]);

  // Fetch posts and events
  const fetchData = async () => {
    if (posts.length === 0) setLoading(true);
    setFetchError(null);
    try {
      // 1. Fetch posts with society info
      const { data: postsData, error: postsErr } = await supabase
        .from('posts')
        .select(`
          *,
          society:societies(*),
          author:profiles(*)
        `)
        .order('is_pinned', { ascending: false })
        .order('created_at', { ascending: false });

      if (postsErr) throw postsErr;

      // 2. Fetch likes counts and user status
      const { data: likesData } = await supabase.from('post_likes').select('post_id, user_id');
      const { data: commentsCountData } = await supabase.from('post_comments').select('post_id');

      const likesCountMap: Record<string, number> = {};
      const userLikedSet = new Set<string>();

      (likesData || []).forEach((like) => {
        likesCountMap[like.post_id] = (likesCountMap[like.post_id] || 0) + 1;
        if (currentUser && like.user_id === currentUser.id) {
          userLikedSet.add(like.post_id);
        }
      });

      const commentsCountMap: Record<string, number> = {};
      (commentsCountData || []).forEach((c) => {
        commentsCountMap[c.post_id] = (commentsCountMap[c.post_id] || 0) + 1;
      });

      const processedPosts: Post[] = (postsData || []).map((p: any) => ({
        ...p,
        likes_count: likesCountMap[p.id] || 0,
        comments_count: commentsCountMap[p.id] || 0,
        user_has_liked: userLikedSet.has(p.id),
      }));

      setPosts(processedPosts);

      // 3. Fetch upcoming events
      const { data: eventsData } = await supabase
        .from('events')
        .select(`
          *,
          society:societies(*)
        `)
        .gte('end_time', new Date().toISOString())
        .order('start_time', { ascending: true })
        .limit(4);

      const processedEvents = eventsData || [];
      setEvents(processedEvents);

      if (onCacheData) {
        onCacheData(processedPosts, processedEvents);
      }

      // 4. Fetch societies list for create post modal
      const { data: socData } = await supabase
        .from('societies')
        .select('id, name')
        .eq('status', 'active');
      setSocietiesList(socData || []);
      if (socData && socData.length > 0) {
        setSelectedSocietyId(socData[0].id);
      }
    } catch (err: any) {
      console.error('Error fetching feed:', err);
      setFetchError(err.message || 'Failed to load campus announcements.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [currentUser]);

  // Handle like toggle
  const handleToggleLike = async (post: Post) => {
    if (!currentUser) {
      onRequireAuth();
      return;
    }

    const hasLiked = post.user_has_liked;
    const newCount = (post.likes_count || 0) + (hasLiked ? -1 : 1);

    // Optimistic UI update
    setPosts((prev) =>
      prev.map((p) =>
        p.id === post.id
          ? { ...p, user_has_liked: !hasLiked, likes_count: Math.max(0, newCount) }
          : p
      )
    );

    try {
      if (hasLiked) {
        await supabase
          .from('post_likes')
          .delete()
          .eq('post_id', post.id)
          .eq('user_id', currentUser.id);
      } else {
        await supabase
          .from('post_likes')
          .insert({ post_id: post.id, user_id: currentUser.id });
      }
    } catch (err) {
      console.error('Like toggle failed:', err);
      fetchData();
    }
  };

  // Open comments
  const handleOpenComments = async (post: Post) => {
    setActiveCommentsPost(post);
    setLoadingComments(true);
    try {
      const { data, error } = await supabase
        .from('post_comments')
        .select(`
          *,
          user:profiles(*)
        `)
        .eq('post_id', post.id)
        .order('created_at', { ascending: true });

      if (error) throw error;
      setComments(data || []);
    } catch (err) {
      console.error('Error fetching comments:', err);
    } finally {
      setLoadingComments(false);
    }
  };

  // Submit comment
  const handleAddComment = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!newCommentText.trim() || !activeCommentsPost) return;
    if (!currentUser) {
      onRequireAuth();
      return;
    }

    setSubmittingComment(true);
    try {
      const { data: sessionData } = await supabase.auth.getSession();
      if (!sessionData.session) {
        onRequireAuth();
        return;
      }

      const newComment = {
        post_id: activeCommentsPost.id,
        user_id: sessionData.session.user.id,
        content: newCommentText.trim(),
      };

      const { data, error } = await supabase
        .from('post_comments')
        .insert(newComment)
        .select(`*, user:profiles(*)`)
        .single();

      if (error) throw error;

      setComments((prev) => [...prev, data]);
      setNewCommentText('');
      showToast('Comment posted successfully!', 'success');

      setPosts((prev) =>
        prev.map((p) =>
          p.id === activeCommentsPost.id
            ? { ...p, comments_count: (p.comments_count || 0) + 1 }
            : p
        )
      );
    } catch (err: any) {
      console.error('Error posting comment:', err);
      showToast(err?.message || 'Failed to post comment.', 'error');
    } finally {
      setSubmittingComment(false);
    }
  };

  // Share post with visual toast feedback
  const handleSharePost = async (post: Post) => {
    const shareUrl = window.location.href;
    const shareText = `${post.title} | UET Societies Hub`;

    if (navigator.clipboard) {
      try {
        await navigator.clipboard.writeText(`${shareText}\n${shareUrl}`);
        showToast('Link copied to clipboard!', 'success');
        return;
      } catch (err) {
        console.warn('Clipboard write error:', err);
      }
    }

    if (navigator.share) {
      try {
        await navigator.share({
          title: post.title,
          text: post.content.slice(0, 100),
          url: shareUrl,
        });
        showToast('Shared successfully!', 'success');
      } catch (e) {
        // Ignored
      }
    } else {
      showToast('Link copied to clipboard!', 'success');
    }
  };

  // Create post
  const handleCreatePost = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newPostTitle.trim() || !newPostContent.trim() || !selectedSocietyId) return;
    if (!currentUser) {
      onRequireAuth();
      return;
    }

    setSubmittingPost(true);
    try {
      const postPayload = {
        society_id: selectedSocietyId,
        author_id: currentUser.id,
        title: newPostTitle.trim(),
        content: newPostContent.trim(),
        media_urls: [],
        is_pinned: false,
        is_public: true,
      };

      const { data, error } = await supabase
        .from('posts')
        .insert(postPayload)
        .select(`*, society:societies(*), author:profiles(*)`)
        .single();

      if (error) throw error;

      setPosts((prev) => [
        { ...data, likes_count: 0, comments_count: 0, user_has_liked: false },
        ...prev,
      ]);
      setCreatePostOpen(false);
      setNewPostTitle('');
      setNewPostContent('');
      showToast('Announcement published successfully!', 'success');
    } catch (err: any) {
      console.error('Error creating post:', err);
      showToast(err.message || 'Failed to create post. Only authorized society leads can publish.', 'error');
    } finally {
      setSubmittingPost(false);
    }
  };

  // Filter posts by category and normalized search query
  const normalizedQuery = normalizeSearchQuery(searchQuery);
  const filteredPosts = posts.filter((p) => {
    if (filterCategory === 'technical' && p.society?.category !== 'Technical') return false;
    if (filterCategory === 'literary' && p.society?.category !== 'Literary') return false;
    if (filterCategory === 'social' && p.society?.category !== 'Social') return false;

    if (!normalizedQuery) return true;
    const titleMatch = normalizeSearchQuery(p.title).includes(normalizedQuery);
    const contentMatch = normalizeSearchQuery(p.content).includes(normalizedQuery);
    const societyMatch = p.society?.name
      ? normalizeSearchQuery(p.society.name).includes(normalizedQuery)
      : false;
    return titleMatch || contentMatch || societyMatch;
  });

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Step 3 Redesign: Modern Editorial Campus-Tech Hero */}
      <section className="relative overflow-hidden bg-gradient-to-br from-slate-900 via-slate-900/90 to-emerald-950/30 border border-slate-800 rounded-3xl p-6 sm:p-8 shadow-2xl">
        <div className="absolute top-0 right-0 w-96 h-96 bg-emerald-500/5 rounded-full blur-3xl pointer-events-none" />
        
        <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-6 relative z-10">
          <div className="space-y-3 max-w-2xl">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs font-semibold">
              <Sparkles className="w-3.5 h-3.5" /> Official UET Student Council Platform
            </div>
            <h1 className="text-2xl sm:text-4xl font-black text-white tracking-tight leading-tight">
              Where Engineering Leadership Meets Innovation
            </h1>
            <p className="text-xs sm:text-sm text-slate-300 leading-relaxed max-w-xl">
              Stay ahead with real-time official bulletins, hackathons, annual symposiums, and recruitment drives across all chartered societies of UET Lahore.
            </p>
          </div>

          {/* Quick Metrics Counter Grid */}
          <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-2 gap-3 w-full lg:w-auto shrink-0">
            <StatCounter label="Chartered Societies" target={24} suffix="+" icon={<Award className="w-4 h-4 text-emerald-400" />} />
            <StatCounter label="Active Members" target={1850} suffix="+" icon={<Users className="w-4 h-4 text-emerald-400" />} />
            <StatCounter label="Campus Hackathons" target={42} suffix="" icon={<Flame className="w-4 h-4 text-emerald-400" />} />
            <StatCounter label="Flagship Events" target={115} suffix="+" icon={<Calendar className="w-4 h-4 text-emerald-400" />} />
          </div>
        </div>

        {/* Step 3: Infinite Marquee of Chartered Society Emblems */}
        <div className="mt-6 pt-6 border-t border-slate-800/80">
          <div className="flex items-center justify-between text-[11px] font-mono text-slate-500 mb-2 uppercase tracking-wider">
            <span>Official Chartered Student Societies</span>
            <span>UET Lahore Accreditation</span>
          </div>
          <MarqueeTicker />
        </div>
      </section>

      {/* Flagship Events Carousel Banner */}
      <section className="bg-slate-900/90 border border-slate-800 rounded-3xl p-5 sm:p-6 shadow-xl relative overflow-hidden">
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 mb-4">
          <div className="flex items-center gap-2.5">
            <div className="p-2 bg-emerald-500/10 border border-emerald-500/20 rounded-xl text-emerald-400">
              <Calendar className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-base sm:text-lg font-bold text-white">
                Upcoming Flagship Events & Hackathons
              </h2>
              <p className="text-xs text-slate-400">
                Official UET student competitions, declamations & symposiums
              </p>
            </div>
          </div>
          <button
            onClick={onNavigateToCalendar}
            className="flex items-center gap-1.5 text-xs font-semibold text-emerald-400 hover:text-emerald-300 transition cursor-pointer"
          >
            <span>View Full Calendar</span>
            <ChevronRight className="w-4 h-4" />
          </button>
        </div>

        {/* Horizontal Event Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {events.length > 0 ? (
            events.map((evt) => {
              const startDate = formatPKTDate(evt.start_time);
              return (
                <div
                  key={evt.id}
                  className="tech-card bg-slate-950/80 border border-slate-800/90 hover:border-emerald-500/40 rounded-2xl p-4 flex flex-col justify-between transition group"
                >
                  <div>
                    <div className="flex items-center justify-between gap-2 mb-2">
                      <span className="text-[10px] font-semibold tracking-wider uppercase px-2 py-0.5 rounded-full bg-emerald-950/60 border border-emerald-500/30 text-emerald-300 truncate">
                        {evt.society?.name || 'UET Campus'}
                      </span>
                      <span className="text-[11px] font-mono text-slate-400 flex items-center gap-1">
                        <Clock className="w-3 h-3 text-emerald-400" /> {startDate}
                      </span>
                    </div>

                    <h4 className="text-sm font-bold text-white group-hover:text-emerald-300 transition line-clamp-2">
                      {evt.title}
                    </h4>
                    <p className="text-xs text-slate-400 mt-1 line-clamp-2">{evt.description}</p>
                  </div>

                  <div className="mt-4 pt-3 border-t border-slate-800/80 flex items-center justify-between">
                    <span className="text-[11px] text-slate-400 flex items-center gap-1 truncate max-w-[60%]">
                      <MapPin className="w-3 h-3 text-slate-500 shrink-0" />
                      <span className="truncate">{evt.venue}</span>
                    </span>

                    <button
                      type="button"
                      onClick={() => onRegisterEvent(evt)}
                      className="text-xs font-semibold text-emerald-400 hover:text-emerald-300 hover:underline flex items-center gap-1 cursor-pointer"
                    >
                      <Ticket className="w-3 h-3" />
                      <span>Register</span>
                      <span>&rarr;</span>
                    </button>
                  </div>
                </div>
              );
            })
          ) : (
            <div className="col-span-full py-8 text-center text-sm text-slate-400">
              No upcoming events scheduled right now.
            </div>
          )}
        </div>
      </section>

      {/* Main Feed Header, Search & Filter Controls */}
      <div className="flex flex-col md:flex-row items-stretch md:items-center justify-between gap-4">
        {/* Category Filter Pills */}
        <div className="flex items-center gap-2 overflow-x-auto pb-1">
          {[
            { id: 'all', label: 'All Updates' },
            { id: 'technical', label: 'Technical & Hackathons' },
            { id: 'literary', label: 'Debating & Literary' },
            { id: 'social', label: 'Social & Welfare' },
          ].map((cat) => (
            <button
              key={cat.id}
              onClick={() => setFilterCategory(cat.id)}
              className={`px-3 py-1.5 rounded-xl text-xs font-medium whitespace-nowrap transition cursor-pointer ${
                filterCategory === cat.id
                  ? 'bg-emerald-600 text-white shadow-md shadow-emerald-950'
                  : 'bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800'
              }`}
            >
              {cat.label}
            </button>
          ))}
        </div>

        {/* Search announcements input & create post action */}
        <div className="flex items-center gap-2">
          <div className="relative flex-1 sm:w-64">
            <Search className="w-4 h-4 text-slate-500 absolute left-3 top-2.5" />
            <input
              type="text"
              placeholder="Search announcements..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full bg-slate-900 border border-slate-800 rounded-xl pl-9 pr-8 py-1.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500"
            />
            {searchQuery && (
              <button
                type="button"
                onClick={() => setSearchQuery('')}
                className="absolute right-2.5 top-2 text-slate-400 hover:text-white"
                aria-label="Clear announcement search"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            )}
          </div>

          {currentUser && (
            <button
              onClick={() => setCreatePostOpen(true)}
              className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-xs font-semibold text-white transition cursor-pointer shrink-0"
            >
              <PlusCircle className="w-4 h-4 text-emerald-400" />
              <span>Post Update</span>
            </button>
          )}
        </div>
      </div>

      {/* Error state banner */}
      {fetchError && posts.length === 0 && (
        <ErrorState
          title="Failed to Load Campus Bulletins"
          message={fetchError}
          onRetry={fetchData}
        />
      )}

      {/* Feed Cards List */}
      {loading ? (
        <div className="space-y-4">
          {[1, 2, 3].map((i) => (
            <div
              key={i}
              className="bg-slate-900/80 border border-slate-800 rounded-3xl p-6 space-y-4 animate-pulse"
            >
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-slate-800" />
                <div className="space-y-1.5 flex-1">
                  <div className="h-4 w-40 bg-slate-800 rounded" />
                  <div className="h-3 w-24 bg-slate-800/60 rounded" />
                </div>
              </div>
              <div className="h-5 w-3/4 bg-slate-800 rounded" />
              <div className="space-y-2">
                <div className="h-3.5 w-full bg-slate-800/70 rounded" />
                <div className="h-3.5 w-5/6 bg-slate-800/70 rounded" />
              </div>
              <div className="pt-3 border-t border-slate-800 flex justify-between">
                <div className="h-6 w-20 bg-slate-800 rounded" />
                <div className="h-6 w-8 bg-slate-800 rounded" />
              </div>
            </div>
          ))}
        </div>
      ) : filteredPosts.length > 0 ? (
        <div className="space-y-5">
          {filteredPosts.map((post) => {
            const timeAgo = getRelativeTime(post.created_at);
            return (
              <article
                key={post.id}
                className="tech-card bg-slate-900/90 border border-slate-800/90 hover:border-slate-700/80 rounded-3xl p-5 sm:p-6 shadow-xl transition-all"
              >
                {/* Author / Society Header */}
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-2xl bg-gradient-to-br from-emerald-500/20 to-teal-500/20 border border-emerald-500/30 flex items-center justify-center font-bold text-emerald-400 text-sm shadow">
                      {post.society?.name?.charAt(0) || 'U'}
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-white text-sm">
                          {post.society?.name || 'UET Campus'}
                        </span>
                        {post.is_pinned && (
                          <span className="inline-flex items-center gap-1 text-[10px] font-semibold text-amber-400 bg-amber-950/40 border border-amber-500/30 px-2 py-0.5 rounded-full">
                            <Pin className="w-2.5 h-2.5" /> Pinned
                          </span>
                        )}
                      </div>
                      <p className="text-[11px] text-slate-400">
                        {post.society?.category} &bull; {timeAgo}
                      </p>
                    </div>
                  </div>
                </div>

                {/* Content */}
                <div className="space-y-2 mb-4">
                  <h3 className="text-base font-bold text-white leading-snug">{post.title}</h3>
                  <p className="text-xs sm:text-sm text-slate-300 whitespace-pre-line leading-relaxed">
                    {post.content}
                  </p>
                </div>

                {/* Actions & Counters */}
                <div className="pt-3 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-400">
                  <div className="flex items-center gap-4">
                    <button
                      type="button"
                      onClick={() => handleToggleLike(post)}
                      className={`flex items-center gap-1.5 transition cursor-pointer ${
                        post.user_has_liked
                          ? 'text-rose-400 font-semibold'
                          : 'hover:text-rose-400 text-slate-400'
                      }`}
                      aria-label="Like post"
                    >
                      <Heart
                        className={`w-4 h-4 ${post.user_has_liked ? 'fill-rose-500 text-rose-500' : ''}`}
                      />
                      <span>{post.likes_count || 0}</span>
                    </button>

                    <button
                      type="button"
                      onClick={() => handleOpenComments(post)}
                      className="flex items-center gap-1.5 hover:text-emerald-400 transition cursor-pointer"
                      aria-label="View comments"
                    >
                      <MessageCircle className="w-4 h-4" />
                      <span>{post.comments_count || 0}</span>
                    </button>
                  </div>

                  <button
                    type="button"
                    onClick={() => handleSharePost(post)}
                    className="flex items-center gap-1.5 hover:text-white transition cursor-pointer"
                    aria-label="Share announcement"
                  >
                    <Share2 className="w-4 h-4" />
                    <span>Share</span>
                  </button>
                </div>
              </article>
            );
          })}
        </div>
      ) : (
        <div className="bg-slate-900 border border-slate-800 rounded-3xl p-12 text-center">
          <p className="text-slate-400 text-sm">
            {searchQuery
              ? `No announcements matching "${searchQuery}".`
              : 'No bulletins found in this category.'}
          </p>
        </div>
      )}

      {/* Accessible Comments Modal */}
      <Modal
        isOpen={!!activeCommentsPost}
        onClose={() => setActiveCommentsPost(null)}
        title="Official Discussion Thread"
        description={activeCommentsPost ? `${activeCommentsPost.society?.name || 'UET Campus'} • ${activeCommentsPost.title}` : undefined}
        maxWidth="max-w-lg"
      >
        <div className="p-6 space-y-4 max-h-[75vh] flex flex-col">
          {/* Scrollable Comments list */}
          <div className="flex-1 overflow-y-auto space-y-3 min-h-[200px] max-h-[360px] pr-1">
            {loadingComments ? (
              <div className="py-8 text-center text-xs text-slate-500">Loading comments...</div>
            ) : comments.length > 0 ? (
              comments.map((comment) => (
                <div key={comment.id} className="p-3 bg-slate-950 rounded-2xl border border-slate-800/80 text-xs space-y-1">
                  <div className="flex items-center justify-between">
                    <span className="font-semibold text-white">
                      {comment.user?.full_name || 'UET Student'}
                    </span>
                    <span className="text-[10px] text-slate-500 font-mono">
                      {getRelativeTime(comment.created_at)}
                    </span>
                  </div>
                  <p className="text-slate-300 leading-relaxed">{comment.content}</p>
                </div>
              ))
            ) : (
              <div className="py-8 text-center text-xs text-slate-500">
                No comments yet. Start the conversation below!
              </div>
            )}
          </div>

          {/* Comment Form (supports Enter and button click) */}
          <form onSubmit={handleAddComment} className="pt-3 border-t border-slate-800 flex items-center gap-2">
            <input
              type="text"
              placeholder={currentUser ? 'Write a respectful comment...' : 'Sign in to comment'}
              disabled={!currentUser || submittingComment}
              value={newCommentText}
              onChange={(e) => setNewCommentText(e.target.value)}
              className="flex-1 bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500"
            />
            <button
              type="submit"
              disabled={!currentUser || submittingComment || !newCommentText.trim()}
              className="p-2.5 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 text-white rounded-xl shadow-md transition cursor-pointer"
              aria-label="Post comment"
            >
              <Send className="w-4 h-4" />
            </button>
          </form>
        </div>
      </Modal>

      {/* Accessible Create Post Modal */}
      <Modal
        isOpen={createPostOpen}
        onClose={() => setCreatePostOpen(false)}
        title="Publish Campus Bulletin"
        description="Official communication for registered student societies"
        maxWidth="max-w-md"
      >
        <form onSubmit={handleCreatePost} className="p-6 space-y-4 text-xs">
          <div>
            <label htmlFor="create-post-society" className="text-slate-300 font-medium block mb-1">
              Publishing Society
            </label>
            <select
              id="create-post-society"
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
            <label htmlFor="create-post-title" className="text-slate-300 font-medium block mb-1">
              Bulletin Headline
            </label>
            <input
              id="create-post-title"
              type="text"
              required
              placeholder="e.g. CodeSpree 2026: Round 1 Qualification Results"
              value={newPostTitle}
              onChange={(e) => setNewPostTitle(e.target.value)}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
            />
          </div>

          <div>
            <label htmlFor="create-post-content" className="text-slate-300 font-medium block mb-1">
              Official Body / Announcement Text
            </label>
            <textarea
              id="create-post-content"
              required
              rows={4}
              placeholder="Detailed announcement, guidelines, venue details, and requirements..."
              value={newPostContent}
              onChange={(e) => setNewPostContent(e.target.value)}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500 resize-none"
            />
          </div>

          <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
            <button
              type="button"
              onClick={() => setCreatePostOpen(false)}
              className="px-4 py-2 rounded-xl text-slate-400 hover:text-white transition cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={submittingPost}
              className="px-5 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold rounded-xl shadow-md shadow-emerald-950 transition cursor-pointer"
            >
              {submittingPost ? 'Publishing...' : 'Publish Announcement'}
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
};
