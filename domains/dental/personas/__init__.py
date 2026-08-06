"""
The 9 dental personas, keyed by decisions.yaml decision_id.

Wave order is declarative here so a runner can execute
WAVES[1], then WAVES[2], … without re-deriving the DAG.
"""
from domains.dental.personas.appeal_specialist import AppealSpecialist
from domains.dental.personas.base import VALID_MODES, DentalPersona
from domains.dental.personas.clinical_reviewer import ClinicalReviewer
from domains.dental.personas.coverage_analyst import CoverageAnalyst
from domains.dental.personas.documentation_reviewer import DocumentationReviewer
from domains.dental.personas.dso_portfolio_manager import DSOPortfolioManager
from domains.dental.personas.eligibility_analyst import EligibilityAnalyst
from domains.dental.personas.fraud_integrity import FraudIntegrity
from domains.dental.personas.pre_d_assessment import PreDAssessment
from domains.dental.personas.provider_credentialing import ProviderCredentialing

# pre_d_assessment (wave 4) synthesises the other eight rather than
# producing findings of its own. Built in Phase 5 alongside the runner.
PERSONA_CLASSES = (
    EligibilityAnalyst,
    ProviderCredentialing,
    FraudIntegrity,
    CoverageAnalyst,
    ClinicalReviewer,
    DocumentationReviewer,
    PreDAssessment,
    AppealSpecialist,
    DSOPortfolioManager,
)

ALL_PERSONAS = {cls.decision_id: cls for cls in PERSONA_CLASSES}

WAVES: dict[int, list[str]] = {}
for _cls in PERSONA_CLASSES:
    WAVES.setdefault(_cls.wave, []).append(_cls.decision_id)

__all__ = [
    "ALL_PERSONAS",
    "AppealSpecialist",
    "ClinicalReviewer",
    "CoverageAnalyst",
    "DSOPortfolioManager",
    "DentalPersona",
    "DocumentationReviewer",
    "EligibilityAnalyst",
    "FraudIntegrity",
    "PERSONA_CLASSES",
    "PreDAssessment",
    "ProviderCredentialing",
    "VALID_MODES",
    "WAVES",
]
