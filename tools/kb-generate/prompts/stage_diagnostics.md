Describe labs, ECG, imaging and the workup.
- labs: only tests that are abnormal or decisive. Use test ids from the reference table below, ranges in its units, per severity. Omit severities where the test is normal. Never list derived tests (marked derived); code computes them. For qualitative tests use the "qualitative" map with values from that test's abnormal list.
- ecg: include only when relevant to this condition or its must-not-miss alternatives; otherwise omit the key's findings (empty list).
- imaging: written report findings; mark role.
- workup.initial/confirmatory/supporting/not_indicated: "test" is a panel id or test id from the table, or an imaging study name.
- workup.scores: ids of standard clinical scores that apply (snake_case, e.g. "wells_pe", "curb_65", "alvarado"). Do not give point values.
