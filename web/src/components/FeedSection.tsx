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
  X,
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { Post, Event, Profile, PostComment } from '../types';
import { useToast } from './Toast';

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
  const [filterCategory, setFilterCategory] = useState<string>('all');

  // Comments modal state
  const [activeCommentsPost, setActiveCommentsPost] = useState<Post | null>(null);
  const [comments, setComments] = useState<PostComment[]>([]);
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
    } catch (err) {
      console.error('Error fetching feed:', err);
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
    }
  };

  // Submit comment (BUG-10: supports Enter key and button click)
  const handleAddComment = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!newCommentText.trim() || !activeCommentsPost) return;
    if (!currentUser) {
      onRequireAuth();
      return;
    }

    setSubmittingComment(true);
    try {
      // Ensure active session exists
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

      // Update post comment count optimistically
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

  // BUG-12: Share button with visual toast feedback
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
        // Ignored if cancelled
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
      showToast(err.message || 'Failed to create post. Only society admins can publish.', 'error');
    } finally {
      setSubmittingPost(false);
    }
  };

  const filteredPosts = posts.filter((p) => {
    if (filterCategory === 'all') return true;
    if (filterCategory === 'technical') return p.society?.category === 'Technical';
    if (filterCategory === 'literary') return p.society?.category === 'Literary';
    if (filterCategory === 'social') return p.society?.category === 'Social';
    return true;
  });

  return (
    <div className="space-y-8 animate-fadeIn">
      {/* Top Banner: Upcoming Events Carousel */}
      <section className="bg-gradient-to-r from-slate-900 via-slate-900/95 to-slate-900 border border-slate-800 rounded-3xl p-5 sm:p-6 shadow-xl relative overflow-hidden">
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
            className="flex items-center gap-1.5 text-xs font-semibold text-emerald-400 hover:text-emerald-300 transition"
          >
            <span>View Full Calendar</span>
            <ChevronRight className="w-4 h-4" />
          </button>
        </div>

        {/* Horizontal Event Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {events.length > 0 ? (
            events.map((evt) => {
              const startDate = new Date(evt.start_time).toLocaleDateString('en-US', {
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
              });
              return (
                <div
                  key={evt.id}
                  className="bg-slate-950/70 border border-slate-800 hover:border-emerald-500/40 rounded-2xl p-4 flex flex-col justify-between transition group"
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

                    {/* BUG-03: Route event registration through internal registration modal */}
                    <button
                      type="button"
                      onClick={() => onRegisterEvent(evt)}
                      className="text-xs font-semibold text-emerald-400 hover:text-emerald-300 hover:underline flex items-center gap-1"
                    >
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

      {/* Main Feed Header & Filters */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        {/* Category Filter Pills */}
        <div className="flex items-center gap-2 overflow-x-auto w-full sm:w-auto pb-1">
          {[
            { id: 'all', label: 'All Updates' },
            { id: 'technical', label: 'Technical & Hackathons' },
            { id: 'literary', label: 'Debating & Literary' },
            { id: 'social', label: 'Social & Welfare' },
          ].map((cat) => (
            <button
              key={cat.id}
              onClick={() => setFilterCategory(cat.id)}
              className={`px-3 py-1.5 rounded-xl text-xs font-medium whitespace-nowrap transition ${
                filterCategory === cat.id
                  ? 'bg-emerald-600 text-white shadow-md shadow-emerald-900/30'
                  : 'bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800'
              }`}
            >
              {cat.label}
            </button>
          ))}
        </div>

        {/* Action: Create Announcement */}
        {currentUser && (
          <button
            onClick={() => setCreatePostOpen(true)}
            className="flex items-center gap-2 px-3.5 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-xs font-semibold text-white transition"
          >
            <PlusCircle className="w-4 h-4 text-emerald-400" />
            <span>Post Update</span>
          </button>
        )}
      </div>

      {/* BUG-08 Fix: Beautiful Skeleton Wireframes with Shimmer Content instead of Blank Dark Rectangles */}
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
            const timeAgo = new Date(post.created_at).toLocaleDateString('en-US', {
              month: 'short',
              day: 'numeric',
            });
            return (
              <article
                key={post.id}
                className="bg-slate-900/80 border border-slate-800/90 hover:border-slate-700/80 rounded-3xl p-5 sm:p-6 shadow-xl transition"
              >
                {/* Author / Society Header */}
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-2xl bg-gradient-to-br from-emerald-500/20 to-teal-500/20 border border-emerald-500/30 flex items-center justify-center font-bold text-emerald-400 text-sm">
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
                <h3 className="text-base sm:text-lg font-bold text-white mb-2 leading-snug">
                  {post.title}
                </h3>
                <p className="text-sm text-slate-300 leading-relaxed whitespace-pre-line">
                  {post.content}
                </p>

                {/* Media gallery if any */}
                {post.media_urls && post.media_urls.length > 0 && (
                  <div className="mt-4 rounded-2xl overflow-hidden border border-slate-800">
                    <img
                      src={post.media_urls[0]}
                      alt="Post visual"
                      className="w-full max-h-96 object-cover"
                    />
                  </div>
                )}

                {/* Interaction Footer */}
                <div className="mt-5 pt-4 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-400">
                  <div className="flex items-center gap-4">
                    {/* Like button */}
                    <button
                      onClick={() => handleToggleLike(post)}
                      className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition ${
                        post.user_has_liked
                          ? 'text-red-400 bg-red-950/40 font-medium'
                          : 'hover:text-red-400 hover:bg-slate-800/60'
                      }`}
                    >
                      <Heart
                        className={`w-4 h-4 ${
                          post.user_has_liked ? 'fill-current text-red-400' : ''
                        }`}
                      />
                      <span>{post.likes_count || 0}</span>
                    </button>

                    {/* Comments button */}
                    <button
                      onClick={() => handleOpenComments(post)}
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg hover:text-white hover:bg-slate-800/60 transition"
                    >
                      <MessageCircle className="w-4 h-4" />
                      <span>{post.comments_count || 0} Comments</span>
                    </button>
                  </div>

                  {/* BUG-12: Share button with visual toast */}
                  <button
                    onClick={() => handleSharePost(post)}
                    className="p-1.5 rounded-lg hover:text-white hover:bg-slate-800/60 transition"
                    title="Share announcement link"
                  >
                    <Share2 className="w-4 h-4" />
                  </button>
                </div>
              </article>
            );
          })}
        </div>
      ) : (
        <div className="bg-slate-900 border border-slate-800 rounded-3xl p-12 text-center">
          <p className="text-slate-400 text-sm">No announcements found in this category.</p>
        </div>
      )}

      {/* Comments Slide-out Drawer */}
      {activeCommentsPost && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/75 backdrop-blur-sm animate-fadeIn">
          <div className="bg-slate-900 border border-slate-700/80 rounded-t-3xl sm:rounded-3xl w-full max-w-lg shadow-2xl h-[80vh] sm:h-[600px] flex flex-col overflow-hidden">
            {/* Header */}
            <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 bg-slate-950/50">
              <div>
                <h3 className="font-bold text-white text-sm sm:text-base">Comments</h3>
                <p className="text-xs text-slate-400 truncate max-w-xs">
                  {activeCommentsPost.title}
                </p>
              </div>
              <button
                onClick={() => setActiveCommentsPost(null)}
                className="text-slate-400 hover:text-white p-1.5 rounded-lg hover:bg-slate-800 transition"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Comments List */}
            <div className="flex-1 overflow-y-auto p-6 space-y-4">
              {comments.length > 0 ? (
                comments.map((c) => (
                  <div key={c.id} className="flex items-start gap-3">
                    <div className="w-8 h-8 rounded-full bg-slate-800 border border-slate-700 flex items-center justify-center font-bold text-xs text-emerald-400 shrink-0">
                      {c.user?.full_name?.charAt(0) || 'U'}
                    </div>
                    <div className="flex-1 bg-slate-950/70 border border-slate-800 rounded-2xl p-3.5">
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-xs font-bold text-white">
                          {c.user?.full_name || 'UET Student'}
                        </span>
                        <span className="text-[10px] text-slate-500 font-mono">
                          {new Date(c.created_at).toLocaleTimeString([], {
                            hour: '2-digit',
                            minute: '2-digit',
                          })}
                        </span>
                      </div>
                      <p className="text-xs text-slate-300 leading-relaxed">{c.content}</p>
                    </div>
                  </div>
                ))
              ) : (
                <div className="py-12 text-center text-xs text-slate-500">
                  No comments yet. Be the first to share your thoughts!
                </div>
              )}
            </div>

            {/* Add Comment Input (BUG-10: handles Enter key and Send button) */}
            <div className="p-4 border-t border-slate-800 bg-slate-950/60">
              {currentUser ? (
                <form onSubmit={handleAddComment} className="flex gap-2">
                  <input
                    type="text"
                    placeholder="Write a comment as student... (Press Enter to post)"
                    value={newCommentText}
                    onChange={(e) => setNewCommentText(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' && !e.shiftKey) {
                        e.preventDefault();
                        handleAddComment();
                      }
                    }}
                    className="flex-1 bg-slate-900 border border-slate-800 rounded-xl px-4 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500"
                  />
                  <button
                    type="submit"
                    onClick={() => handleAddComment()}
                    disabled={submittingComment || !newCommentText.trim()}
                    className="p-2.5 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 text-white rounded-xl transition"
                    title="Send comment"
                  >
                    <Send className="w-4 h-4 pointer-events-none" />
                  </button>
                </form>
              ) : (
                <div className="text-center py-2">
                  <button
                    onClick={() => {
                      setActiveCommentsPost(null);
                      onRequireAuth();
                    }}
                    className="text-xs font-semibold text-emerald-400 hover:underline"
                  >
                    Sign in to participate in the discussion &rarr;
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Create Announcement Modal */}
      {createPostOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-md animate-fadeIn">
          <div className="bg-slate-900 border border-slate-700/80 rounded-2xl w-full max-w-lg shadow-2xl overflow-hidden flex flex-col">
            <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 bg-slate-950/40">
              <h3 className="font-bold text-white text-base">Publish Society Announcement</h3>
              <button
                onClick={() => setCreatePostOpen(false)}
                className="text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleCreatePost} className="p-6 space-y-4">
              <div>
                <label className="text-xs font-medium text-slate-300 mb-1 block">
                  Select Publishing Society
                </label>
                <select
                  value={selectedSocietyId}
                  onChange={(e) => setSelectedSocietyId(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-white focus:outline-none focus:border-emerald-500"
                >
                  {societiesList.map((soc) => (
                    <option key={soc.id} value={soc.id}>
                      {soc.name}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-xs font-medium text-slate-300 mb-1 block">
                  Announcement Title
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Registrations Open for Annual Tech Fest"
                  value={newPostTitle}
                  onChange={(e) => setNewPostTitle(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2 text-sm text-white focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="text-xs font-medium text-slate-300 mb-1 block">
                  Detailed Content / Guidelines
                </label>
                <textarea
                  required
                  rows={4}
                  placeholder="Provide schedule, venue, eligibility, and rules..."
                  value={newPostContent}
                  onChange={(e) => setNewPostContent(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2 text-sm text-white focus:outline-none focus:border-emerald-500 resize-none"
                />
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setCreatePostOpen(false)}
                  className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white hover:bg-slate-800"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submittingPost}
                  className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-xs font-semibold text-white shadow-md shadow-emerald-900/40"
                >
                  {submittingPost ? 'Publishing...' : 'Publish Update'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
