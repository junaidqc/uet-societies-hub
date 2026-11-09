export interface Profile {
  id: string;
  email: string;
  full_name: string;
  roll_number: string;
  department: string;
  semester: number;
  avatar_url?: string | null;
  bio?: string | null;
  phone_number?: string | null;
  is_system_admin: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface Society {
  id: string;
  name: string;
  slug: string;
  category: string;
  description: string;
  logo_url?: string | null;
  banner_url?: string | null;
  status: 'active' | 'pending' | 'suspended' | 'rejected';
  email?: string | null;
  website?: string | null;
  social_links?: Record<string, string>;
  created_at: string;
  updated_at: string;
  created_by?: string | null;
  rejection_reason?: string | null;
  follower_count?: number;
}

export interface Post {
  id: string;
  society_id: string;
  author_id: string;
  title: string;
  content: string;
  media_urls?: string[];
  is_pinned: boolean;
  is_public: boolean;
  created_at: string;
  updated_at: string;
  society?: Society;
  author?: Profile;
  likes_count?: number;
  comments_count?: number;
  user_has_liked?: boolean;
}

export interface PostComment {
  id: string;
  post_id: string;
  user_id: string;
  content: string;
  created_at: string;
  updated_at: string;
  user?: Profile;
}

export interface Event {
  id: string;
  society_id: string;
  title: string;
  description: string;
  venue: string;
  start_time: string;
  end_time: string;
  banner_url?: string | null;
  registration_link?: string | null;
  is_public: boolean;
  created_at: string;
  updated_at: string;
  society?: Society;
  is_interested?: boolean;
}

export interface CustomQuestion {
  id: string;
  question: string;
  type: 'text' | 'textarea';
  required: boolean;
}

export interface Hiring {
  id: string;
  society_id: string;
  title: string;
  description: string;
  positions: string[];
  deadline: string;
  status: 'draft' | 'open' | 'closed';
  requirements?: string | null;
  custom_questions?: CustomQuestion[];
  selection_method?: string;
  total_seats?: number;
  created_at: string;
  updated_at: string;
  society?: Society;
}

export interface Application {
  id: string;
  hiring_id: string;
  user_id: string;
  position: string;
  status: 'submitted' | 'reviewing' | 'shortlisted' | 'accepted' | 'rejected';
  answers: Record<string, string>;
  resume_url?: string | null;
  feedback?: string | null;
  created_at: string;
  updated_at: string;
  hiring?: Hiring;
}

export interface Group {
  id: string;
  society_id: string;
  name: string;
  description?: string | null;
  is_private: boolean;
  created_at: string;
  updated_at: string;
  society?: Society;
}

export interface GroupMessage {
  id: string;
  group_id: string;
  sender_id: string;
  content: string;
  attachment_url?: string | null;
  created_at: string;
  sender?: Profile;
}
