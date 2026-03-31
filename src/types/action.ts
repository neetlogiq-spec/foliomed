/**
 * Standard discriminated-union return type for server actions.
 *
 * Usage:
 *   async function myAction(): Promise<ActionResult> { ... }
 *   async function createDoc(): Promise<ActionResult<{ id: string }>> { ... }
 */
export type ActionResult<T extends Record<string, unknown> = Record<never, never>> =
  | { error: string; success?: never }
  | ({ error?: never; success: true } & T);
