import { NavTab } from '../components/Navbar';

export interface AppUrlState {
  tab: NavTab;
  query: string;
  category: string;
  societyId: string | null;
  hiringId: string | null;
}

/**
 * Parses application state from window.location search params.
 * Resolves DEF-01 (URL Routing & Deep Linking).
 */
export function getAppUrlState(): AppUrlState {
  if (typeof window === 'undefined') {
    return { tab: 'feed', query: '', category: 'All', societyId: null, hiringId: null };
  }

  const params = new URLSearchParams(window.location.search);
  const rawTab = params.get('tab') || window.location.hash.replace('#', '') || 'feed';
  const validTabs: NavTab[] = ['feed', 'societies', 'hirings', 'calendar', 'groups', 'admin'];
  const tab: NavTab = validTabs.includes(rawTab as NavTab) ? (rawTab as NavTab) : 'feed';

  return {
    tab,
    query: params.get('q') || '',
    category: params.get('cat') || 'All',
    societyId: params.get('society'),
    hiringId: params.get('hiring'),
  };
}

/**
 * Updates browser URL query parameters without reloading the page.
 */
export function syncAppUrl(state: Partial<AppUrlState>, replace: boolean = false) {
  if (typeof window === 'undefined') return;

  const current = getAppUrlState();
  const next = { ...current, ...state };

  const params = new URLSearchParams();
  if (next.tab && next.tab !== 'feed') params.set('tab', next.tab);
  if (next.query && next.query.trim()) params.set('q', next.query.trim());
  if (next.category && next.category !== 'All') params.set('cat', next.category);
  if (next.societyId) params.set('society', next.societyId);
  if (next.hiringId) params.set('hiring', next.hiringId);

  const queryString = params.toString();
  const newUrl = `${window.location.pathname}${queryString ? `?${queryString}` : ''}`;

  if (replace) {
    window.history.replaceState(null, '', newUrl);
  } else {
    window.history.pushState(null, '', newUrl);
  }
}
