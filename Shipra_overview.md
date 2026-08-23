# P3 — Safety Intelligence + Safe-Haven

## Status: Day 1 Complete ✅

Day 1 goal was a deterministic risk engine: `Risk = Crime Hotspot + Time + Isolation + Route Deviation + User Signal`, outputting `LOW / MEDIUM / HIGH / CRITICAL`.

## What was built

### 1. `lib/services/models.dart`
Added the `RiskAssessment` model (was missing from the shared models file):
```dart
class RiskAssessment {
  final RiskLevel risk;   // LOW / MEDIUM / HIGH / CRITICAL
  final int score;        // 0–100
  final List<String> reasons;
}
```
Matches the team's data contract: `{ "risk": "HIGH", "score": 78, "reasons": [...] }`

### 2. `lib/services/risk_engine.dart` (new file)
Deterministic scoring engine — `RiskEngine.assess(...)` — with explainable, weighted factors:

| Factor | Max points | Notes |
|---|---|---|
| Crime hotspot | 45 | Scaled by hotspot's `RiskLevel`, +10% boost if ≥3 recent incidents (recency weighting) |
| Time of day | 15 | Flat bonus for 10 PM–5 AM |
| Isolation | 15 | Flat bonus if `isIsolated == true` |
| Route deviation | 10 | **Only counts if paired with another active risk factor** — deviation alone never raises risk |
| User signal | 40 | Large jump when "I Feel Unsafe" is triggered |

Score bands: 0–24 LOW · 25–49 MEDIUM · 50–74 HIGH · 75–100 CRITICAL.

### 3. `lib/services/app_state.dart`
- Replaced the hardcoded `RiskLevel _currentRisk` with a real `RiskAssessment _riskAssessment`, computed via `RiskEngine.assess(...)`.
- `activateSafetyAssist()` now calls the real engine (`userReportedUnsafe: true`) instead of hardcoding `RiskLevel.high`.
- Kept `currentRisk` getter for backward compatibility with existing screens; added `riskAssessment` getter for full detail (score + reasons).

### 4. `lib/screens/safety_screen.dart`
- Risk circle now shows the real level (all 4 states, not just LOW/"ELEVATED") plus the numeric score.
- "Why this assessment?" section now renders dynamically from `riskAssessment.reasons` instead of 4 hardcoded fake rows.

## Data sources — what's real vs. placeholder right now

| Input | Source right now | Status |
|---|---|---|
| `currentTime` | `DateTime.now()` | ✅ Real, no dependency |
| `userReportedUnsafe` | Wired to the "I Feel Unsafe" button via `AppState` | ✅ Real |
| `nearbyHotspot` | `MockData.mockHotspot` (hardcoded) | ⏳ Placeholder — swap for P2's live hotspot lookup once available |
| `isIsolated` | Fixed `false` | ⏳ Placeholder — no isolation signal exists yet anywhere in the app |
| `routeDeviationMeters` | Fixed `null` | ⏳ Placeholder — depends on P1's PDR/route tracking, not yet built |

The engine is a pure function — swapping any placeholder for real data later is a one-line change in `app_state.dart`, no structural changes needed.

## Next up: Day 2 — Safe-Haven Recommendation
```
Safe Arrival Score = Distance + Risk + Accessibility + Opening Status + Location Confidence
```
Rank `SafeLocation`s so the safest option isn't always the nearest one, and wire that ranking into the Safety Assist screen (currently shows unranked `MockData.safeLocations`).