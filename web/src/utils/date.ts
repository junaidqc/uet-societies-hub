const PKT_TIMEZONE = 'Asia/Karachi';

/**
 * Formats a date string or object explicitly in Asia/Karachi (PKT - UTC+5) timezone.
 * Resolves DEF-09 (Timezone drift).
 */
export function formatPKTDate(
  dateInput: string | Date,
  options?: Intl.DateTimeFormatOptions
): string {
  try {
    const d = typeof dateInput === 'string' ? new Date(dateInput) : dateInput;
    if (isNaN(d.getTime())) return 'TBA';

    const defaultOptions: Intl.DateTimeFormatOptions = {
      timeZone: PKT_TIMEZONE,
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      ...options,
    };

    return new Intl.DateTimeFormat('en-US', defaultOptions).format(d);
  } catch (_) {
    return 'TBA';
  }
}

/**
 * Formats a time explicitly in Asia/Karachi (PKT) timezone.
 */
export function formatPKTTime(dateInput: string | Date): string {
  try {
    const d = typeof dateInput === 'string' ? new Date(dateInput) : dateInput;
    if (isNaN(d.getTime())) return '';

    return new Intl.DateTimeFormat('en-US', {
      timeZone: PKT_TIMEZONE,
      hour: '2-digit',
      minute: '2-digit',
      hour12: true,
    }).format(d);
  } catch (_) {
    return '';
  }
}

/**
 * Checks if a deadline is closing within threshold hours (defaults to 72 hours).
 */
export function isClosingSoon(deadlineInput: string | Date, thresholdHours: number = 72): boolean {
  try {
    const d = typeof deadlineInput === 'string' ? new Date(deadlineInput) : deadlineInput;
    const diffMs = d.getTime() - Date.now();
    return diffMs > 0 && diffMs < thresholdHours * 60 * 60 * 1000;
  } catch (_) {
    return false;
  }
}

/**
 * Returns human-readable relative time string.
 */
export function getRelativeTime(dateInput: string | Date): string {
  try {
    const d = typeof dateInput === 'string' ? new Date(dateInput) : dateInput;
    const diffSeconds = Math.floor((Date.now() - d.getTime()) / 1000);

    if (diffSeconds < 60) return 'Just now';
    if (diffSeconds < 3600) return `${Math.floor(diffSeconds / 60)}m ago`;
    if (diffSeconds < 86400) return `${Math.floor(diffSeconds / 3600)}h ago`;
    if (diffSeconds < 604800) return `${Math.floor(diffSeconds / 86400)}d ago`;

    return formatPKTDate(d, { month: 'short', day: 'numeric' });
  } catch (_) {
    return '';
  }
}
