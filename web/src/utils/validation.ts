/**
 * Strict URL validator.
 * Requires http:// or https:// protocol.
 * Rejects javascript:, data:, and raw strings (Resolves DEF-06 & Security XSS).
 */
export function isValidUrl(urlInput: string): boolean {
  if (!urlInput || typeof urlInput !== 'string') return false;
  const clean = urlInput.trim();
  if (!clean) return false;

  try {
    const parsed = new URL(clean);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch (_) {
    return false;
  }
}

/**
 * Validates official UET student or faculty email domain.
 */
export function isValidUetEmail(email: string): boolean {
  if (!email || typeof email !== 'string') return false;
  const clean = email.trim().toLowerCase();
  return clean.endsWith('@uet.edu.pk') || clean.endsWith('@student.uet.edu.pk');
}

/**
 * Sanitizes external URL to prevent javascript: or malformed links.
 */
export function sanitizeExternalUrl(urlInput: string | null | undefined): string | null {
  if (!urlInput) return null;
  const clean = urlInput.trim();
  if (!clean) return null;
  if (!/^https?:\/\//i.test(clean)) {
    return `https://${clean}`;
  }
  return isValidUrl(clean) ? clean : null;
}
