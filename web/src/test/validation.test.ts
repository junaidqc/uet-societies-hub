import { describe, it, expect } from 'vitest';
import { isValidUrl, isValidUetEmail } from '../utils/validation';
import { formatPKTDate, formatPKTTime } from '../utils/date';

describe('Form & Input Validation (DEF-06)', () => {
  it('DEF-06 FIX: validates proper HTTP and HTTPS URLs', () => {
    expect(isValidUrl('https://github.com/myuser/resume.pdf')).toBe(true);
    expect(isValidUrl('http://drive.google.com/file/d/123')).toBe(true);
    expect(isValidUrl('https://linkedin.com/in/student')).toBe(true);
  });

  it('DEF-06 FIX: strictly rejects invalid non-URL resume strings and malicious protocols', () => {
    expect(isValidUrl('none')).toBe(false);
    expect(isValidUrl('check drive')).toBe(false);
    expect(isValidUrl('abc.xyz')).toBe(false); // Missing protocol
    expect(isValidUrl('javascript:alert(1)')).toBe(false); // XSS attack vector
    expect(isValidUrl('data:text/html,<script>')).toBe(false);
    expect(isValidUrl('')).toBe(false);
    expect(isValidUrl('   ')).toBe(false);
  });

  it('validates official UET student email domains', () => {
    expect(isValidUetEmail('2025cs81@student.uet.edu.pk')).toBe(true);
    expect(isValidUetEmail('director@uet.edu.pk')).toBe(true);
    expect(isValidUetEmail('student@gmail.com')).toBe(false);
    expect(isValidUetEmail('hacker@uet.edu.pk.evil.com')).toBe(false);
  });
});

describe('Timezone Standardization (DEF-09)', () => {
  it('DEF-09 FIX: formats dates and times explicitly in Asia/Karachi (PKT UTC+5)', () => {
    // 2026-11-10T20:00:00Z is 2026-11-11 01:00:00 in PKT (UTC+5)
    const utcIso = '2026-11-10T20:00:00Z';
    const formattedDate = formatPKTDate(utcIso);
    expect(formattedDate).toContain('Nov 11'); // In Karachi timezone it must be Nov 11, not Nov 10!

    const formattedTime = formatPKTTime(utcIso);
    expect(formattedTime).toMatch(/01:00|1:00/);
  });
});
