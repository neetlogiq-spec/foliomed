export type FeedPostType = "discussion" | "case_share" | "announcement" | "question";

export interface FeedPost {
  id: string;
  department_id: string;
  author_id: string;
  type: FeedPostType;
  title: string;
  body: string | null;
  linked_patient_id: string | null;
  is_pinned: boolean;
  created_at: string;
  updated_at: string;
  // joined
  profiles?: { full_name: string; avatar_url: string | null; role: string } | null;
  patients?: { first_name: string; last_name: string | null } | null;
}

export interface FeedComment {
  id: string;
  post_id: string;
  author_id: string;
  body: string;
  created_at: string;
  profiles?: { full_name: string; avatar_url: string | null } | null;
}

export interface HandoverNote {
  id: string;
  department_id: string;
  from_user_id: string;
  to_user_id: string | null;
  handover_date: string;
  shift: string | null;
  patients_summary: string | null;
  pending_tasks: string | null;
  critical_alerts: string | null;
  notes: string | null;
  acknowledged: boolean;
  created_at: string;
  // joined
  from_profile?: { full_name: string } | null;
  to_profile?: { full_name: string } | null;
}

export interface CaseLogEntry {
  id: string;
  user_id: string;
  patient_id: string;
  department_id: string | null;
  diagnosis: string;
  procedure_done: string | null;
  learning_points: string | null;
  is_interesting: boolean;
  logged_at: string;
  created_at: string;
  // joined
  profiles?: { full_name: string } | null;
  patients?: { first_name: string; last_name: string | null; mrd_number: string } | null;
}

export const POST_TYPE_CONFIG: Record<FeedPostType, { label: string; emoji: string; color: string }> = {
  discussion: { label: "Discussion", emoji: "💬", color: "text-blue-400" },
  case_share: { label: "Case Share", emoji: "🏥", color: "text-emerald-400" },
  announcement: { label: "Announcement", emoji: "📢", color: "text-amber-400" },
  question: { label: "Question", emoji: "❓", color: "text-purple-400" },
};
