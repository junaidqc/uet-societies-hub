import { Society, Event, Hiring } from '../types';

/**
 * Normalizes a user search query:
 * - Trims leading/trailing whitespace (fixes DEF-04)
 * - Normalizes Unicode combining characters (NFC)
 * - Converts to lowercase for case-insensitive matching
 */
export function normalizeSearchQuery(query: string): string {
  if (!query) return '';
  return query.trim().normalize('NFC').toLowerCase();
}

/**
 * Filters societies with resilient multi-field token matching.
 * Handles whitespace-only queries by returning all matching category societies.
 */
export function filterSocieties(
  societies: Society[],
  rawQuery: string,
  category: string
): Society[] {
  const cleanQuery = normalizeSearchQuery(rawQuery);
  const targetCategory = category.trim().toLowerCase();

  return societies.filter((soc) => {
    // 1. Category check
    const matchesCat =
      targetCategory === 'all' ||
      soc.category.toLowerCase().includes(targetCategory);

    if (!matchesCat) return false;

    // 2. Query check (if empty, matches all within the category)
    if (!cleanQuery) return true;

    // Multi-field check
    const name = (soc.name || '').normalize('NFC').toLowerCase();
    const desc = (soc.description || '').normalize('NFC').toLowerCase();
    const cat = (soc.category || '').normalize('NFC').toLowerCase();
    const email = (soc.email || '').normalize('NFC').toLowerCase();

    return (
      name.includes(cleanQuery) ||
      desc.includes(cleanQuery) ||
      cat.includes(cleanQuery) ||
      email.includes(cleanQuery)
    );
  });
}

/**
 * Filters campus events with upcoming vs past partitioning (fixes DEF-08).
 */
export function filterEvents(
  events: Event[],
  rawQuery: string,
  timeFilter: 'upcoming' | 'past' | 'all',
  referenceNow: Date = new Date()
): Event[] {
  const cleanQuery = normalizeSearchQuery(rawQuery);
  const nowMs = referenceNow.getTime();

  return events.filter((evt) => {
    const endMs = evt.end_time ? new Date(evt.end_time).getTime() : new Date(evt.start_time).getTime();
    
    // Time filter
    if (timeFilter === 'upcoming' && endMs < nowMs) return false;
    if (timeFilter === 'past' && endMs >= nowMs) return false;

    if (!cleanQuery) return true;

    const title = (evt.title || '').normalize('NFC').toLowerCase();
    const desc = (evt.description || '').normalize('NFC').toLowerCase();
    const venue = (evt.venue || '').normalize('NFC').toLowerCase();
    const socName = (evt.society?.name || '').normalize('NFC').toLowerCase();

    return (
      title.includes(cleanQuery) ||
      desc.includes(cleanQuery) ||
      venue.includes(cleanQuery) ||
      socName.includes(cleanQuery)
    );
  });
}

/**
 * Filters executive recruitment positions by query and role.
 */
export function filterHirings(
  hirings: Hiring[],
  rawQuery: string
): Hiring[] {
  const cleanQuery = normalizeSearchQuery(rawQuery);
  if (!cleanQuery) return hirings;

  return hirings.filter((h) => {
    const title = (h.title || '').normalize('NFC').toLowerCase();
    const desc = (h.description || '').normalize('NFC').toLowerCase();
    const socName = (h.society?.name || '').normalize('NFC').toLowerCase();
    const positions = (h.positions || []).join(' ').normalize('NFC').toLowerCase();

    return (
      title.includes(cleanQuery) ||
      desc.includes(cleanQuery) ||
      socName.includes(cleanQuery) ||
      positions.includes(cleanQuery)
    );
  });
}
