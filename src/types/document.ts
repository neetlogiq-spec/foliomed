export type BlockType = "heading" | "text" | "list" | "divider" | "findings" | "plan" | "callout" | "quote";

export interface Block {
  id: string;
  type: BlockType;
  content: string;
  meta?: Record<string, string>;
}

export interface CaseDocument {
  id: string;
  patient_id: string;
  title: string;
  content: { blocks: Block[] };
  version: number;
  is_draft: boolean;
  created_by: string;
  created_at: string;
  updated_at: string;
  // joined
  patients?: { first_name: string; last_name?: string; mrd_number: string };
  profiles?: { full_name: string };
}

export const BLOCK_TYPES: { type: BlockType; label: string; icon: string; description?: string }[] = [
  { type: "heading", label: "Heading", icon: "H", description: "Section title" },
  { type: "text", label: "Text", icon: "¶", description: "Plain paragraph" },
  { type: "list", label: "List", icon: "•", description: "Bulleted list" },
  { type: "findings", label: "Findings", icon: "🔍", description: "Clinical findings" },
  { type: "plan", label: "Plan", icon: "📋", description: "Treatment plan" },
  { type: "callout", label: "Callout", icon: "💡", description: "Highlight important info" },
  { type: "quote", label: "Quote", icon: "❝", description: "Quoted text" },
  { type: "divider", label: "Divider", icon: "—", description: "Horizontal rule" },
];

export function emptyBlock(type: BlockType = "text"): Block {
  return {
    id: Math.random().toString(36).slice(2, 10),
    type,
    content: "",
  };
}

export const DEFAULT_CASE_BLOCKS: Block[] = [
  { id: "h1", type: "heading", content: "Chief Complaint" },
  { id: "t1", type: "text", content: "" },
  { id: "h2", type: "heading", content: "History of Present Illness" },
  { id: "t2", type: "text", content: "" },
  { id: "h3", type: "heading", content: "Past History" },
  { id: "t3", type: "text", content: "" },
  { id: "h4", type: "heading", content: "Examination Findings" },
  { id: "f1", type: "findings", content: "" },
  { id: "d1", type: "divider", content: "" },
  { id: "h5", type: "heading", content: "Investigations" },
  { id: "t4", type: "text", content: "" },
  { id: "h6", type: "heading", content: "Diagnosis" },
  { id: "t5", type: "text", content: "" },
  { id: "h7", type: "heading", content: "Treatment Plan" },
  { id: "p1", type: "plan", content: "" },
];
