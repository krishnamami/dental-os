from tests.personas.test_all_personas import ctx_with_rules, proc, ev, rules  # noqa


def test_integrity_finding_still_blocks_submission(rules):
    """The rename must not move integrity codes out of the block set.

    ⚠ THIS IS THE TEST THE RENAME NEEDED. Every other test asserts on a
    code by name, so renaming the constant and the assertion together
    keeps them green while the behaviour silently changes: the block in
    pre_d_assessment is a PREFIX match, and a prefix nobody updated
    turns "blocked for review" into "ready to submit".
    """
    from domains.dental.personas.fraud_integrity import FraudIntegrity
    from domains.dental.personas.pre_d_assessment import PreDAssessment

    c = ctx_with_rules(
        rules, decision="pended", scenario_id="DA-F02",
        procedures=[proc("D4260", tooth=None, fee=1850.0, allowed=1004.5)],
        clinical_evidence=[ev("CLINICAL_NOTE", {"cdt_codes_noted": ["D0150"],
                                                "narrative_present": True})])

    fi = FraudIntegrity().run(c)
    integrity = [s for s in fi if s["signal_code"].startswith("INTEGRITY_")]
    assert integrity, [s["signal_code"] for s in fi]

    c.upstream_outputs = dict(getattr(c, "upstream_outputs", {}) or {})
    c.upstream_outputs["fraud_integrity"] = {"signals": fi}

    out = PreDAssessment().run(c)
    codes = [s["signal_code"] for s in out]
    assert "PRED_BLOCKED_INTEGRITY" in codes, codes
    assert "PRED_READY_TO_SUBMIT" not in codes, codes


def test_no_signal_code_starts_with_fraud(rules):
    """Nothing the engine can emit is named after an accusation."""
    from domains.dental.personas.fraud_integrity import FraudIntegrity
    c = ctx_with_rules(
        rules, decision="pended", scenario_id="DA-F02",
        procedures=[proc("D4260", tooth=None, fee=1850.0, allowed=1004.5)],
        clinical_evidence=[ev("CLINICAL_NOTE", {"cdt_codes_noted": ["D0150"],
                                                "narrative_present": True})])
    for s in FraudIntegrity().run(c):
        assert not s["signal_code"].startswith("FRAUD_"), s["signal_code"]
