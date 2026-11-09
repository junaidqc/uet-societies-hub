import { createClient } from '@supabase/supabase-js';

export const SUPABASE_URL = 'https://efbccttyfinvmypadctj.supabase.co';
export const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVmYmNjdHR5Zmludm15cGFkY3RqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQwMzY5MTksImV4cCI6MjEwOTYxMjkxOX0.Eh11Nsilns68cOCZVc1kgX6PtUXIzOuqjpFWjprbdSw';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});
