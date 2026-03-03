Tier 1: Intelligent Transaction Capture

Goal: Create transactions from receipts + M-Pesa SMS with confidence + review.

Receipt scanning (Google ML Kit OCR)

Flow: Photo → OCR → extract amount / date / merchant → show confirmation → save

Real-time OCR + confidence scoring

Receipt image upload + storage (Cloudinary)

Rules:

confidence ≥ 70%: auto-save transaction

confidence < 70%: send to review queue

M-Pesa SMS auto-capture

Flow: SMS → parse M-Pesa patterns → classify debit/credit → extract amount + merchant → create transaction

Features:

Debit/credit pattern recognition

Balance validation (when present in SMS)

Duplicate detection (24h window)

Auto-sync to Firestore

Auto-transaction creation

Source tagging: manual | receipt | sms | api

Confidence scoring on every created transaction

Review queue (approve/edit/reject)

Undo/rollback for recent imports/auto-created items

Tier 2: Automated Categorization Engine

Goal: Suggest categories quickly, then learn user preferences.

Keyword-based classification
Algorithm:

Tokenize transaction description (merchant + notes)

Match tokens against keyword Trie

Score by frequency + weights

Return top 3 categories + confidence

If confidence < 70%, flag for review

Apply user overrides (history)

Categories

Income (Sales, Salary, Loans, Grants)

Operating Expenses (Salaries, Rent, Supplies, Marketing, Travel)

COGS (Raw Materials, Inventory)

Compliance-lite (Taxes, Insurance, Licenses)
(This stays as a category label only. No tax logic.)

Learning system

Store all user corrections

Learn user-specific category preferences

Re-rank suggestions based on feedback history

Detect patterns (merchant-based, time-based, recurring)

Override logic

Merchant rules (e.g., “Safaricom” → Communications)

Time patterns (e.g., 15th → Salary)

Amount rules (e.g., < 100 → Supplies)

Recurring transaction detection

Tier 3: Business Trust Score (0–100)

Goal: Summarize bookkeeping quality and business stability using transaction data.

Formula:
Trust Score = (40×Health + 30×Integrity + 20×Compliance + 10×Behavior) / 100

Financial Health (40%)

Cash flow ratio (0–30)

Expense stability (0–7)

Growth trend (0–3)

Transaction Integrity (30%)

Data accuracy (0–15)

Source diversity (0–10)

Consistency (0–5)

Compliance Readiness (20%) (still “lite” and bookkeeping-only)

Documentation coverage (0–10)

Record completeness (0–5)

Categorization completeness (0–5)

Financial Behavior (10%)

Payment timeliness signals (0–5)

Budget adherence (0–3)

Anomaly detection (0–2)

Risk bands:

80–100 LOW RISK

60–79 MODERATE

40–59 HIGH

< 40 CRITICAL

Tier 4: Advanced AI Analytics

Goal: Dashboards + insights + forecasting based on your transaction ledger.

Financial dashboard

Net income & cash flow

Income velocity & expense burn

Profitability ratios (gross/operating/net)

Efficiency metrics

3-month forecasts

Break-even analysis

AI insights + recommendations

Detect spikes/drops, recurring anomalies

Recommend cost optimization + revenue growth ideas

Cashflow advice (runway, reserve targets, invoicing speed)

Predictive alerts:

runway projection

revenue trend drift

unusual transactions

Advanced reporting

Executive summary

Detailed P&L

Cash flow analysis

Business performance report

Tier 5: Basic Compliance Checklist (simple only)

Goal: A lightweight bookkeeping checklist, no tax computation engine.

Compliance status (bookkeeping completeness)

Checklist (example items):

All income recorded

Receipts for 80%+ of expenses

No unexplained transactions

Documentation complete

Compliance score (0–100%)

(No VAT/corporate/personal tax estimation logic. No CRB score.)

Tier 6: Advanced Financial Advice

Goal: Structured insights + scenario modeling driven by metrics.

Insights

Performance (growth, margin changes)

Risk (cash depletion, concentration, seasonality)

Opportunity (high-margin products, savings)

Compliance-lite (documentation gaps, missing receipts)

Importance score:
Insight Score = (Impact × Probability × Urgency) / Complexity

Scenario modeling

Best/Base/Worst cases

What-if: hire staff, pricing change, major client, loan proceeds (purely financial modeling)

Sensitivity analysis

Revenue ±5/±10/±20

Cost variations (labor, materials, rent)

Break-even at multiple price points

Updated architecture (still valid)

Flutter UI → Services → Local+Cloud

Presentation (Flutter): receipt scanner, SMS capture, dashboards, reports, insights

Services: OCR, SMS parser, categorization, trust score, analytics, advisory, scenario modeler

Data: SQLite local + Firestore sync + Cloudinary images + external APIs (future)

Dependencies

google_mlkit_text_recognition

image

chart lib (your choice, but keep charts consistent)

decimal

flutter_background_service