"use client";

import { Component, type ReactNode } from "react";

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
  message: string | null;
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, message: null };
  }

  static getDerivedStateFromError(error: unknown): State {
    const message = error instanceof Error ? error.message : "An unexpected error occurred.";
    return { hasError: true, message };
  }

  override render() {
    if (this.state.hasError) {
      if (this.props.fallback) return this.props.fallback;

      return (
        <div className="flex flex-col items-center justify-center py-16 text-center px-4">
          <div className="w-10 h-10 rounded-full bg-red-500/10 flex items-center justify-center mb-3">
            <svg className="w-5 h-5 text-red-400" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" />
            </svg>
          </div>
          <p className="text-sm font-medium text-white mb-1">Something went wrong</p>
          <p className="text-xs text-slate-400 max-w-sm">{this.state.message}</p>
          <button
            onClick={() => this.setState({ hasError: false, message: null })}
            className="mt-4 text-xs text-blue-400 hover:text-blue-300 underline underline-offset-2"
          >
            Try again
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}
