"""
DentalPersona — shared base for the 9 dental decision agents.

Mirrors decision-os LendingPersona, minus the Anthropic path (Phase 4
is the deterministic layer; the LLM writes the NARRATIVE later, it
never writes the decision).

THE CONTRACT

  _compute_offline(context) -> list[dict]

  SYNC and DB-LESS (RULE 5)   No await, no conn, no query. Everything
                              is on the PredContext, including the
                              catalogue the enricher attached and the
                              upstream waves' outputs.
  make_signal() ONLY (RULE 7) There is no add_flag. A persona's entire
                              output is a list of signals.
  NEVER RAISES                run() wraps _compute_offline. A persona
                              that blows up would take down its whole
                              wave; instead it emits an error signal
                              the runner can surface.
  NO auto_execute             mode is 'recommend' or 'human_approval'.
                              make_signal REFUSES anything else — the
                              domain has no auto_execute and a typo
                              should fail loudly, not silently create
                              an AI that acts on its own.

PERSONAS READ RESOLVERS. Resolvers never call personas, never import
them, and do not know they exist. A persona's job is to turn findings
into signals a human can act on: the finding is the measurement, the
signal is the sentence.
"""
from __future__ import annotations

import logging
from typing import Any, Optional

logger = logging.getLogger(__name__)

VALID_MODES = ("recommend", "human_approval")


class DentalPersona:
    """Base class for the 9 dental decision agents."""

    decision_id: str = ""
    persona_name: str = ""
    wave: int = 0
    mode: str = "recommend"
    risk_level: str = "medium"
    owner_team: str = "billing"

    # ── Subclass extension point ─────────────────────────────────────

    def _compute_offline(self, context: Any) -> list[dict]:
        """SYNC. DB-LESS. Returns a list of make_signal() dicts."""
        raise NotImplementedError(
            f"{type(self).__name__} must implement _compute_offline()"
        )

    # ── Public entry point ───────────────────────────────────────────

    def run(self, context: Any) -> list[dict]:
        """_compute_offline with the never-raises guarantee applied."""
        try:
            signals = self._compute_offline(context) or []
        except Exception as exc:  # noqa: BLE001 — that is the point
            logger.exception("persona %s failed", self.decision_id)
            return [self.make_signal(
                f"{self.decision_id.upper()}_ERROR",
                f"{type(self).__name__} could not complete: "
                f"{type(exc).__name__}: {exc}",
                mode="human_approval",
                recommended_action="review_manually",
            )]
        for s in signals:
            assert s.get("mode") in VALID_MODES, (
                f"{self.decision_id} emitted mode={s.get('mode')!r}"
            )
        return signals

    # ── Signal construction — the ONLY way to emit output ────────────

    def make_signal(
        self,
        code: str,
        finding: str,
        mode: str = None,
        data: dict = None,
        citation: str = None,
        payer_citation: str = None,
        recommended_action: str = None,
        sla_hours: int = None,
        assignee: str = None,
    ) -> dict:
        """Every signal must have a code, a finding and a mode."""
        mode = mode or self.mode
        if mode not in VALID_MODES:
            raise ValueError(
                f"{self.decision_id}: mode {mode!r} is not permitted. This "
                f"domain has no auto_execute — decisions.yaml carries no "
                f"automate_if clause and recommend is the ceiling."
            )
        if not code or not finding:
            raise ValueError(
                f"{self.decision_id}: a signal needs both a code and a "
                f"finding. A code with no sentence is not actionable."
            )
        return {
            "signal_code": code,
            "finding": finding,
            "mode": mode,
            "decision_id": self.decision_id,
            "wave": self.wave,
            "owner_team": self.owner_team,
            "risk_level": self.risk_level,
            "data": data or {},
            "citation": citation,
            "payer_citation": payer_citation,
            "recommended_action": recommended_action,
            "sla_hours": sla_hours,
            "assignee": assignee or self.owner_team,
        }

    def signal_from_catalogue(
        self,
        context: Any,
        code: str,
        finding: str,
        mode: str = None,
        data: dict = None,
        **overrides: Any,
    ) -> dict:
        """make_signal with citation / SLA / assignee read from the
        conditions_library rather than hardcoded (RULE 1, RULE 8).

        A condition code with no library row still produces a signal —
        the finding is what the human reads — but it arrives with no
        citation and no SLA, which is the gap validate_catalogue.py
        blocks a deploy on. Two of those exist today
        (CLINICAL_MEDICAL_HISTORY_FLAG, PROVIDER_OIG_EXCLUDED).
        """
        lib = (getattr(context, "catalogue_rules", {}) or {}).get(
            "conditions_library"
        ) or {}
        entry = lib.get(code) or {}
        if not entry:
            logger.warning(
                "conditions_library has no row for %r — signal emitted with "
                "no citation, SLA or assignee. Seed it in dental-simulator.",
                code,
            )
        kwargs = {
            "payer_citation": entry.get("payer_citation"),
            "sla_hours": entry.get("sla_hours"),
            "assignee": entry.get("assignee") or self.owner_team,
            "recommended_action": entry.get("recommended_action"),
        }
        kwargs.update({k: v for k, v in overrides.items() if v is not None})
        return self.make_signal(code, finding, mode=mode, data=data, **kwargs)

    # ── Upstream access ──────────────────────────────────────────────

    def upstream_payload(self, context: Any, decision_id: str) -> dict:
        """Read a Wave N-1 output. Empty dict when it has not run."""
        return (getattr(context, "upstream_outputs", {}) or {}).get(decision_id, {})

    def upstream_signals(self, context: Any, decision_id: str) -> list[dict]:
        return self.upstream_payload(context, decision_id).get("signals", []) or []

    def upstream_has(self, context: Any, decision_id: str, code: str) -> bool:
        return any(
            s.get("signal_code") == code
            for s in self.upstream_signals(context, decision_id)
        )

    def upstream_blocked(self, context: Any, decision_id: str) -> bool:
        """True when an upstream persona escalated to a human.

        A human_approval signal upstream does not stop this persona from
        running — a blocked case still needs its findings assembled so
        the reviewer sees the whole picture. It changes what gets said,
        not whether the work happens.
        """
        return any(
            s.get("mode") == "human_approval"
            for s in self.upstream_signals(context, decision_id)
        )

    # ── Shared helpers ───────────────────────────────────────────────

    def rules(self, context: Any) -> dict:
        return getattr(context, "catalogue_rules", {}) or {}

    def has_open_condition(self, context: Any, code: str) -> bool:
        return code in (getattr(context, "open_conditions", []) or [])

    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<{type(self).__name__} {self.decision_id} wave={self.wave} "
            f"mode={self.mode} owner={self.owner_team}>"
        )
