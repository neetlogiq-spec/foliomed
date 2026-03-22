"use client";

import { useState, useTransition } from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { createFeedPost, addComment } from "./actions";
import type { FeedPost, FeedComment, FeedPostType } from "@/types/feed";
import { POST_TYPE_CONFIG } from "@/types/feed";
import { cn } from "@/lib/utils";

interface FeedClientProps {
  posts: (FeedPost & { comment_count: number })[];
  comments: FeedComment[];
}

export function FeedClient({ posts, comments }: FeedClientProps) {
  const [showCompose, setShowCompose] = useState(false);
  const [expandedPost, setExpandedPost] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const handleCreatePost = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);
    const fd = new FormData(e.currentTarget);
    startTransition(async () => {
      const result = await createFeedPost({
        type: (fd.get("type") as string) || "discussion",
        title: fd.get("title") as string,
        body: (fd.get("body") as string) || undefined,
      });
      if (result?.error) setError(result.error);
      else setShowCompose(false);
    });
  };

  const handleComment = (postId: string, body: string) => {
    startTransition(async () => {
      await addComment(postId, body);
    });
  };

  return (
    <div className="space-y-4">
      {/* Compose */}
      <div className="flex items-center justify-between">
        <div />
        <Button size="sm" onClick={() => setShowCompose(!showCompose)}
          className="bg-blue-600 hover:bg-blue-700 text-white text-xs">
          {showCompose ? "Cancel" : "+ New Post"}
        </Button>
      </div>

      {showCompose && (
        <Card className="bg-white/5 border-white/10">
          <CardContent className="pt-4">
            <form onSubmit={handleCreatePost} className="space-y-3">
              {error && <p className="text-xs text-red-400">{error}</p>}
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Type</Label>
                  <select name="type"
                    className="w-full rounded-md border border-white/10 bg-white/5 px-2 py-1.5 text-sm text-white h-8">
                    {(Object.keys(POST_TYPE_CONFIG) as FeedPostType[]).map((t) => (
                      <option key={t} value={t} className="bg-slate-900">
                        {POST_TYPE_CONFIG[t].emoji} {POST_TYPE_CONFIG[t].label}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="space-y-1">
                  <Label className="text-xs text-slate-400">Title *</Label>
                  <Input name="title" required placeholder="Post title"
                    className="bg-white/5 border-white/10 text-white text-sm h-8 placeholder:text-slate-600" />
                </div>
              </div>
              <div className="space-y-1">
                <Label className="text-xs text-slate-400">Body</Label>
                <Textarea name="body" rows={3} placeholder="Write your post..."
                  className="bg-white/5 border-white/10 text-white text-sm placeholder:text-slate-600 min-h-[60px]" />
              </div>
              <Button type="submit" disabled={isPending} size="sm" className="bg-blue-600 hover:bg-blue-700">
                {isPending ? "Posting..." : "Post"}
              </Button>
            </form>
          </CardContent>
        </Card>
      )}

      {/* Posts */}
      {posts.length === 0 ? (
        <div className="text-center py-16">
          <p className="text-slate-400 font-medium">No posts yet</p>
          <p className="text-sm text-slate-500 mt-1">Start a discussion with your department</p>
        </div>
      ) : (
        posts.map((post) => {
          const typeConf = POST_TYPE_CONFIG[(post.type as FeedPostType) || "discussion"];
          const postComments = comments.filter((c) => c.post_id === post.id);
          const isExpanded = expandedPost === post.id;

          return (
            <Card key={post.id} className={cn("bg-white/5 border-white/5", post.is_pinned && "border-amber-500/20")}>
              <CardContent className="pt-4">
                {/* Header */}
                <div className="flex items-start gap-3 mb-2">
                  <div className="w-8 h-8 rounded-full bg-linear-to-br from-blue-500 to-purple-600 flex items-center justify-center text-xs font-bold text-white shrink-0">
                    {post.profiles?.full_name?.charAt(0) || "?"}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="text-sm font-medium text-white">{post.profiles?.full_name || "Unknown"}</span>
                      <span className={cn("text-[10px] font-medium", typeConf.color)}>
                        {typeConf.emoji} {typeConf.label}
                      </span>
                      {post.is_pinned && <span className="text-[10px] text-amber-400">📌 Pinned</span>}
                    </div>
                    <span className="text-[10px] text-slate-500">
                      {new Date(post.created_at).toLocaleString("en-IN", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" })}
                    </span>
                  </div>
                </div>

                {/* Content */}
                <h3 className="text-sm font-semibold text-white mb-1">{post.title}</h3>
                {post.body && <p className="text-sm text-slate-300 whitespace-pre-wrap mb-3">{post.body}</p>}

                {/* Actions */}
                <div className="flex items-center gap-3 pt-2 border-t border-white/5">
                  <button
                    onClick={() => setExpandedPost(isExpanded ? null : post.id)}
                    className="text-xs text-slate-400 hover:text-slate-200 transition-colors"
                  >
                    💬 {postComments.length} comment{postComments.length !== 1 ? "s" : ""}
                  </button>
                </div>

                {/* Comments */}
                {isExpanded && (
                  <div className="mt-3 pl-4 border-l border-white/10 space-y-2">
                    {postComments.map((c) => (
                      <div key={c.id} className="text-xs">
                        <span className="text-blue-400 font-medium">{c.profiles?.full_name || "Unknown"}</span>
                        <span className="text-slate-500 ml-2">
                          {new Date(c.created_at).toLocaleString("en-IN", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" })}
                        </span>
                        <p className="text-slate-300 mt-0.5">{c.body}</p>
                      </div>
                    ))}
                    <CommentInput postId={post.id} onSubmit={handleComment} isPending={isPending} />
                  </div>
                )}
              </CardContent>
            </Card>
          );
        })
      )}
    </div>
  );
}

function CommentInput({ postId, onSubmit, isPending }: { postId: string; onSubmit: (id: string, body: string) => void; isPending: boolean }) {
  const [body, setBody] = useState("");
  return (
    <div className="flex gap-2 pt-1">
      <Input
        value={body}
        onChange={(e) => setBody(e.target.value)}
        placeholder="Write a comment..."
        className="bg-white/5 border-white/10 text-white text-xs h-7 placeholder:text-slate-600"
        onKeyDown={(e) => {
          if (e.key === "Enter" && body.trim()) {
            onSubmit(postId, body.trim());
            setBody("");
          }
        }}
      />
      <Button size="sm" disabled={isPending || !body.trim()}
        onClick={() => { onSubmit(postId, body.trim()); setBody(""); }}
        className="bg-blue-600 hover:bg-blue-700 text-[10px] h-7 px-2">
        Send
      </Button>
    </div>
  );
}
