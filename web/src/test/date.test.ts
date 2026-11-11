import { describe, it, expect } from 'vitest';
import { formatPKTDate, formatPKTTime, isClosingSoon, getRelativeTime } from '../utils/date';

describe('Date & PKT Timezone Utils', () => {
  it('formats dates specifically in Asia/Karachi timezone', () => {
    // 2026-11-15T00:00:00Z is 2026-11-15 05:00:00 PKT
    const formatted = formatPKTDate('2026-11-15T00:00:00Z');
    expect(formatted).toContain('Nov');
    expect(formatted).toContain('15');
    expect(formatted).toContain('2026');
  });

  it('formats times accurately in Asia/Karachi', () => {
    // 2026-11-15T09:30:00Z in UTC is 14:30 PKT (02:30 PM)
    const formatted = formatPKTTime('2026-11-15T09:30:00Z');
    expect(formatted).toMatch(/02:30\s*PM|2:30\s*pm|14:30/i);
  });

  it('detects if deadline is closing within specified threshold hours', () => {
    const futureDate = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
    expect(isClosingSoon(futureDate, 72)).toBe(true);

    const farFutureDate = new Date(Date.now() + 10 * 24 * 60 * 60 * 1000).toISOString();
    expect(isClosingSoon(farFutureDate, 72)).toBe(false);
  });

  it('generates human-readable relative time', () => {
    const justNow = new Date(Date.now() - 30 * 1000).toISOString();
    expect(getRelativeTime(justNow)).toBe('Just now');

    const minutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
    expect(getRelativeTime(minutesAgo)).toBe('5m ago');

    const hoursAgo = new Date(Date.now() - 3 * 3600 * 1000).toISOString();
    expect(getRelativeTime(hoursAgo)).toBe('3h ago');
  });
});
