import { describe, it, expect, beforeEach } from 'vitest';
import { getAppUrlState, syncAppUrl } from '../utils/urlState';

describe('URL State Deep Linking & Syncing', () => {
  beforeEach(() => {
    window.history.replaceState(null, '', '/');
  });

  it('reads default state when no search params exist', () => {
    const state = getAppUrlState();
    expect(state.tab).toBe('feed');
    expect(state.query).toBe('');
    expect(state.societyId).toBeNull();
  });

  it('reads tab and query from search params', () => {
    window.history.replaceState(null, '', '/?tab=societies&q=acm');
    const state = getAppUrlState();
    expect(state.tab).toBe('societies');
    expect(state.query).toBe('acm');
  });

  it('syncs new tab and query without full page reload', () => {
    syncAppUrl({ tab: 'calendar' });
    let state = getAppUrlState();
    expect(state.tab).toBe('calendar');

    syncAppUrl({ tab: 'societies', query: 'robotics' });
    state = getAppUrlState();
    expect(state.tab).toBe('societies');
    expect(state.query).toBe('robotics');
  });
});
