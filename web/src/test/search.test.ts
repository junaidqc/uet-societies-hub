import { describe, it, expect } from 'vitest';
import { normalizeSearchQuery, filterSocieties, filterEvents } from '../utils/search';
import { Society, Event } from '../types';

const mockSocieties: Society[] = [
  {
    id: '1',
    name: 'ACM UET Lahore',
    slug: 'acm-uet',
    category: 'Technical',
    description: 'Premier computing society advancing software engineering, AI, and competitive programming.',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    status: 'active',
  },
  {
    id: '2',
    name: 'IEEE UET Student Branch',
    slug: 'ieee-uet',
    category: 'Technical',
    description: 'Advancing technology for humanity with robotics, circuits, and technical workshops.',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    status: 'active',
  },
  {
    id: '3',
    name: 'UET Debating Society (بزمِ مباحثہ)',
    slug: 'uet-debating',
    category: 'Literary',
    description: 'Fostering parliamentary debates, bilingual declamations, and public speaking excellence.',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    status: 'active',
  },
  {
    id: '4',
    name: 'Environmental Protection Society (EPS)',
    slug: 'eps-uet',
    category: 'Social',
    description: 'Leading campus green drives, urban plantation, and sustainable climate initiatives.',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    status: 'active',
  },
];

describe('Search & Query Normalization Logic (DEF-04 & DEF-05)', () => {
  it('normalizes queries by trimming whitespace and lowercasing', () => {
    expect(normalizeSearchQuery('   ACM   ')).toBe('acm');
    expect(normalizeSearchQuery('  IEEE UET  ')).toBe('ieee uet');
    expect(normalizeSearchQuery('')).toBe('');
    expect(normalizeSearchQuery('   ')).toBe('');
  });

  it('DEF-04 FIX: whitespace query "   " returns all societies instead of 0 results', () => {
    const results = filterSocieties(mockSocieties, '   ', 'All');
    expect(results.length).toBe(mockSocieties.length);
  });

  it('matches correctly with leading and trailing whitespace', () => {
    const results = filterSocieties(mockSocieties, '  acm  ', 'All');
    expect(results.length).toBe(1);
    expect(results[0].slug).toBe('acm-uet');
  });

  it('handles case-insensitive matching', () => {
    const lower = filterSocieties(mockSocieties, 'acm', 'All');
    const upper = filterSocieties(mockSocieties, 'ACM', 'All');
    const mixed = filterSocieties(mockSocieties, 'AcM', 'All');
    expect(lower.length).toBe(1);
    expect(upper.length).toBe(1);
    expect(mixed.length).toBe(1);
  });

  it('handles Urdu and multilingual Unicode characters gracefully', () => {
    const urduSearch = filterSocieties(mockSocieties, 'مباحثہ', 'All');
    expect(urduSearch.length).toBe(1);
    expect(urduSearch[0].slug).toBe('uet-debating');
  });

  it('handles regex and special characters without throwing syntax errors', () => {
    expect(() => filterSocieties(mockSocieties, 'C++', 'All')).not.toThrow();
    expect(() => filterSocieties(mockSocieties, '[(*+?^$)]', 'All')).not.toThrow();
    const result = filterSocieties(mockSocieties, '(EPS)', 'All');
    expect(result.length).toBe(1);
    expect(result[0].slug).toBe('eps-uet');
  });

  it('handles extremely long input strings without freezing', () => {
    const hugeString = 'a'.repeat(20000);
    const start = performance.now();
    const result = filterSocieties(mockSocieties, hugeString, 'All');
    const duration = performance.now() - start;
    expect(result.length).toBe(0);
    expect(duration).toBeLessThan(100); // Must execute in under 100ms
  });

  it('correctly filters by category and search query combined', () => {
    const techOnly = filterSocieties(mockSocieties, '', 'Technical');
    expect(techOnly.length).toBe(2);

    const techWithQuery = filterSocieties(mockSocieties, 'robotics', 'Technical');
    expect(techWithQuery.length).toBe(1);
    expect(techWithQuery[0].slug).toBe('ieee-uet');

    const literaryWithTechQuery = filterSocieties(mockSocieties, 'robotics', 'Literary');
    expect(literaryWithTechQuery.length).toBe(0);
  });
});

describe('Campus Events Filtering (DEF-08 & DEF-09)', () => {
  const mockEvents: Event[] = [
    {
      id: 'e1',
      society_id: '1',
      title: 'Upcoming CodeSpree Hackathon',
      description: '24 hour hackathon',
      venue: 'CS Labs',
      start_time: '2026-11-20T10:00:00Z',
      end_time: '2026-11-21T10:00:00Z',
      is_public: true,
      created_at: '2026-01-01T00:00:00Z',
      updated_at: '2026-01-01T00:00:00Z',
    },
    {
      id: 'e2',
      society_id: '3',
      title: 'Past Declamation Contest',
      description: 'Debating championship',
      venue: 'Auditorium',
      start_time: '2026-10-01T10:00:00Z',
      end_time: '2026-10-02T10:00:00Z',
      is_public: true,
      created_at: '2026-01-01T00:00:00Z',
      updated_at: '2026-01-01T00:00:00Z',
    },
  ];

  it('DEF-08 FIX: separates upcoming events from past events cleanly', () => {
    // Current test date: 2026-11-11
    const referenceNow = new Date('2026-11-11T12:00:00Z');
    const upcoming = filterEvents(mockEvents, '', 'upcoming', referenceNow);
    const past = filterEvents(mockEvents, '', 'past', referenceNow);

    expect(upcoming.length).toBe(1);
    expect(upcoming[0].id).toBe('e1');

    expect(past.length).toBe(1);
    expect(past[0].id).toBe('e2');
  });
});
