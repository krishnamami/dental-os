"""
T-23 — Provider credentialing. Wave 1, human_approval, billing.

No resolver: the credentialing posture is already on the context.

An OIG exclusion is the hardest stop in the system. No federal
healthcare programme may pay an excluded provider (42 CFR
1001.1901(b)), so this is not "review before submitting" — it is "do
not submit under any circumstances".
"""
from __future__ import annotations

from typing import Any

from domains.dental.personas.base import DentalPersona

# NO HARDCODED SPECIALTY GATING (RULE 1: zero hardcoded values).
#
# An earlier draft carried a dict of "codes a general dentist cannot
# bill". It was wrong twice over. It flagged DA-A01 — Dr. Chinta doing
# a ridge-preservation graft in-house is the entire premise of the
# design partner, not a credentialing exception. And it invented a rule
# with no catalogue row behind it, so the signal could cite nothing.
#
# Specialty gating needs a catalogue table (cdt_codes has no
# requires_specialty column today). Until one exists this persona reads
# the assembler's own conclusion via pred_states.provider_specialty and
# raises nothing of its own. Tracked in dental-simulator
# scripts/refresh_payer_rules.py.


class ProviderCredentialing(DentalPersona):
    decision_id = "provider_credentialing"
    persona_name = "Provider Credentialing"
    wave = 1
    mode = "human_approval"
    risk_level = "high"
    owner_team = "billing"

    def _compute_offline(self, context: Any) -> list[dict]:
        signals: list[dict] = []
        npi = getattr(context, "provider_npi", None)
        name = getattr(context, "provider_name", None) or "unknown provider"
        excluded = getattr(context, "provider_oig_excluded", None)
        npi_valid = getattr(context, "provider_npi_valid", None)
        network = getattr(context, "provider_network_status", None)
        specialty = getattr(context, "provider_specialty", None)

        # ── OIG exclusion — absolute ─────────────────────────────────
        if excluded is True:
            return [self.signal_from_catalogue(
                context, "PROVIDER_OIG_EXCLUDED",
                f"NPI {npi} ({name}) appears on the OIG List of Excluded "
                f"Individuals/Entities. No federal healthcare programme may "
                f"pay this provider. DO NOT SUBMIT under this NPI.",
                mode="human_approval",
                data={"provider_npi": npi, "provider_name": name,
                      "oig_excluded": True},
                citation="42 CFR 1001.1901(b)",
                recommended_action="do_not_submit_under_this_npi",
            )]

        # ── NPI not verified ─────────────────────────────────────────
        if npi_valid is False:
            signals.append(self.signal_from_catalogue(
                context, "PROVIDER_NPI_INVALID",
                f"NPI {npi} could not be verified against NPPES. A claim "
                f"submitted under an unverified NPI will reject.",
                mode="human_approval",
                data={"provider_npi": npi, "nppes_verified": False},
                recommended_action="verify_npi_against_nppes",
            ))
        elif npi_valid is None:
            signals.append(self.make_signal(
                "PROVIDER_NPI_UNVERIFIED",
                f"No NPPES verification result is on file for NPI {npi}. "
                f"The check did not run — this is not confirmation.",
                mode="recommend",
                data={"provider_npi": npi},
                recommended_action="run_nppes_verification",
            ))

        # ── Network status ───────────────────────────────────────────
        if network == "out_of_network":
            signals.append(self.signal_from_catalogue(
                context, "PROVIDER_OUT_OF_NETWORK",
                f"{name} is out-of-network for {context.payer_id}. "
                f"Higher cost-sharing applies and the patient should be told "
                f"before treatment.",
                mode="recommend",
                data={"provider_name": name, "provider_npi": npi,
                      "payer_id": context.payer_id,
                      "network_status": network},
            ))

        # ── Specialty match ──────────────────────────────────────────
        # Only when the assembler recorded a mismatch. See the note at
        # the top of this module for why there is no local rule here.
        if self.has_open_condition(context, "PROVIDER_SPECIALTY_MISMATCH"):
            signals.append(self.signal_from_catalogue(
                context, "PROVIDER_SPECIALTY_MISMATCH",
                f"{name} is recorded as {specialty}, which the payer may not "
                f"accept for {', '.join(context.cdt_codes)}.",
                mode="recommend",
                data={"specialty": specialty, "billed_codes": context.cdt_codes},
            ))

        # ── Clean ────────────────────────────────────────────────────
        if not signals:
            signals.append(self.make_signal(
                "PROVIDER_VERIFIED",
                f"{name} (NPI {npi}) verified against NPPES, not on the OIG "
                f"exclusion list, and in-network for {context.payer_id}.",
                mode="recommend",
                data={"provider_npi": npi, "provider_name": name,
                      "specialty": specialty, "network_status": network,
                      "nppes_verified": getattr(context, "provider_nppes_verified", None),
                      "oig_excluded": False},
            ))
        return signals
