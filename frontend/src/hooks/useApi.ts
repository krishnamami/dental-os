/**
 * dental-os API access. One axios client, one query key convention.
 *
 * Every path goes through "/api", which vite.config.ts proxies to
 * localhost:9010 in development. No component may hardcode a host —
 * that is what lets the same build run against a local API, a staging
 * one, or CloudFront without a rebuild.
 */
import axios from "axios";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";

import type {
  Appeal,
  ConditionsResponse,
  Decision,
  FeedbackRequest,
  FeedbackResponse,
  Health,
  PatientSummary,
  Portfolio,
} from "../types/dental";

export const api = axios.create({
  baseURL: "/api",
  timeout: 60_000,
  headers: { "Content-Type": "application/json" },
});

/**
 * FastAPI puts its message in `detail`. Surfacing that instead of
 * axios's generic "Request failed with status code 404" is the
 * difference between "not found" and "this pre-D is approved, so there
 * is nothing to appeal" — the API writes useful 404s and throwing them
 * away would waste them.
 */
export class ApiError extends Error {
  // Declared and assigned explicitly rather than as a constructor
  // parameter property: this template sets `erasableSyntaxOnly`, which
  // rejects any TypeScript that is not pure type annotation.
  status?: number;

  constructor(message: string, status?: number) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

async function get<T>(path: string): Promise<T> {
  try {
    const { data } = await api.get<T>(path);
    return data;
  } catch (err) {
    if (axios.isAxiosError(err)) {
      const detail = (err.response?.data as { detail?: string } | undefined)
        ?.detail;
      throw new ApiError(detail ?? err.message, err.response?.status);
    }
    throw err;
  }
}

/** Query keys, in one place so invalidation cannot miss one. */
export const keys = {
  health: ["health"] as const,
  decision: (id: string) => ["decision", id] as const,
  conditions: (id: string) => ["conditions", id] as const,
  patientSummary: (id: string) => ["patient-summary", id] as const,
  appeal: (id: string) => ["appeal", id] as const,
  portfolio: ["portfolio"] as const,
};

// A pre-D's decision bundle never changes unless someone forces a
// re-run, so it is worth caching hard. The portfolio moves with every
// new case, so it is not.
const STABLE = { staleTime: 5 * 60_000, refetchOnWindowFocus: false };

export function useHealth() {
  return useQuery({
    queryKey: keys.health,
    queryFn: () => get<Health>("/health"),
    refetchInterval: 60_000,
  });
}

export function useDecision(predRequestId?: string) {
  return useQuery({
    queryKey: keys.decision(predRequestId ?? ""),
    queryFn: () => get<Decision>(`/decisions/${predRequestId}`),
    enabled: Boolean(predRequestId),
    ...STABLE,
  });
}

export function useConditions(predRequestId?: string) {
  return useQuery({
    queryKey: keys.conditions(predRequestId ?? ""),
    queryFn: () => get<ConditionsResponse>(`/decisions/${predRequestId}/conditions`),
    enabled: Boolean(predRequestId),
    ...STABLE,
  });
}

export function usePatientSummary(predRequestId?: string) {
  return useQuery({
    queryKey: keys.patientSummary(predRequestId ?? ""),
    queryFn: () => get<PatientSummary>(`/decisions/${predRequestId}/patient-summary`),
    enabled: Boolean(predRequestId),
    ...STABLE,
  });
}

/**
 * 404 is a VALID answer here, not a failure: an approved pre-D has
 * nothing to appeal. Retrying it would be pure latency, so don't.
 */
export function useAppeal(predRequestId?: string) {
  return useQuery({
    queryKey: keys.appeal(predRequestId ?? ""),
    queryFn: () => get<Appeal>(`/decisions/${predRequestId}/appeal`),
    enabled: Boolean(predRequestId),
    retry: (count, error) =>
      error instanceof ApiError && error.status === 404 ? false : count < 2,
    ...STABLE,
  });
}

export function usePortfolio() {
  return useQuery({
    queryKey: keys.portfolio,
    queryFn: () => get<Portfolio>("/portfolio/summary"),
    staleTime: 60_000,
  });
}

/**
 * Human verdict on one signal. Invalidates the conditions queue so the
 * item the user just actioned stops staring at them.
 */
export function useSubmitFeedback(predRequestId?: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: FeedbackRequest) => {
      const { data } = await api.post<FeedbackResponse>(
        `/decisions/${predRequestId}/feedback`,
        body,
      );
      return data;
    },
    onSuccess: () => {
      if (predRequestId) {
        qc.invalidateQueries({ queryKey: keys.conditions(predRequestId) });
      }
    },
  });
}
