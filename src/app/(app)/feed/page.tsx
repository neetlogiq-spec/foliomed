import { createClient } from "@/lib/supabase/server";
import { FeedClient } from "./FeedClient";
import { RealtimeProvider } from "@/components/shared/RealtimeProvider";

export default async function FeedPage() {
  const supabase = await createClient();

  const [postsRes, commentsRes] = await Promise.all([
    supabase
      .from("department_feed")
      .select(`*, profiles:author_id ( full_name, avatar_url, role )`)
      .order("is_pinned", { ascending: false })
      .order("created_at", { ascending: false })
      .limit(50),
    supabase
      .from("comments")
      .select(`*, profiles:author_id ( full_name, avatar_url )`)
      .order("created_at", { ascending: true })
      .limit(200),
  ]);

  // Count comments per post
  const commentCounts = new Map<string, number>();
  (commentsRes.data ?? []).forEach((c) => {
    commentCounts.set(c.post_id, (commentCounts.get(c.post_id) || 0) + 1);
  });

  const posts = (postsRes.data ?? []).map((p) => ({
    ...p,
    comment_count: commentCounts.get(p.id) || 0,
  }));

  return (
    <div className="p-6 max-w-3xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">Department Feed</h1>
        <p className="text-sm text-slate-400 mt-1">Discussions, case shares, and announcements</p>
      </div>
      <FeedClient posts={posts} comments={commentsRes.data ?? []} />
      <RealtimeProvider tables={["department_feed", "comments"]} />
    </div>
  );
}
