# PatoTrack AI Features Guide (Tiers 1–6)

This document provides a comprehensive overview of the advanced AI and analytics features implemented in PatoTrack. All computations are performed **100% on-device (Edge AI)** using pure Dart algorithms. This ensures user privacy (no financial data leaves the device) and zero cloud operational costs.

---

## Tier 1: Document Scanning / Receipt OCR
**What it is:** Auto-fills transaction details by extracting text from receipt images using Google ML Kit.
**How it works:** 
- The user takes a photo or picks an image from the gallery.
- `OcrService` uses local machine learning to recognize text in the image.
- Regex rules scan the text for common patterns to extract:
  - **Amount:** Looks for currency symbols (KES, Ksh, $) or keywords (Total, Amount) followed by numbers.
  - **Date:** Identifies common date formats (DD/MM/YYYY, MM-DD-YY).
  - **Tax/VAT:** Specifically looks for Kenyan tax identifiers like PIN numbers, VAT, or 16% markers.
**How to test:** 
1. Go to "Add Transaction".
2. Tap the camera/gallery icon.
3. Select a receipt image. Watch as the Amount and Date fields auto-populate.

---

## Tier 2: AI Auto-Categorization
**What it is:** Predicts the best category for a transaction based on the description entered by the user.
**How it works:** 
- `CategorizationService` maintains a robust dictionary mapping keywords to specific categories.
- As the user types (e.g., "KPLC token", "Uber ride", "Safaricom data"), the app searches for a match.
- If a match is found (e.g., "KPLC" matches "Electricity"), it automatically selects that category.
**How to test:**
1. Go to "Add Transaction".
2. Type "uber" or "kplc" in the description field.
3. A "Smart Match" chip will appear and the category will instantly update.

---

## Tier 3: Business Trust Score
**What it is:** A 0-100 credibility score designed to act as a "lite KYC" or proof of business health for lenders/investors.
**How it works:** 
- `TrustScoreService` calculates a weighted score across 4 pillars using a 90-day transaction history:
  1. **Activity (30%):** Frequency of transactions (are you actively doing business?).
  2. **Consistency (30%):** How steady your income vs. expense ratio is.
  3. **Documentation (25%):** What percentage of expenses have attached receipt images.
  4. **Health (15%):** Current cash flow velocity and burn rate.
**How to test:**
1. Navigate to the new **Analytics Tab** on the bottom nav bar.
2. Look for the "Business Trust Score" card. The gauge gives a 0-100 score and a status (e.g., Excellent, Needs Work).

---

## Tier 4: Advanced AI Analytics
**What it is:** A full institutional-grade dashboard providing forecasts, anomaly detection, profitability ratios, and sensitivity analysis.
**How it works:**
- **Forecasting:** Uses *Holt's Double Exponential Smoothing* to predict the next 3 months of income and expenses. It factors in baseline trends and velocity, generating a 90% confidence interval via RMSE (Root Mean Square Error).
- **Anomaly Detection:** Uses a hybrid *Z-Score & Interquartile Range (IQR)* model to flag highly unusual spikes, massive multi-day drops, or duplicated transactions.
- **Profitability Ratios:** Computes Gross Margin, Operating Margin, Net Margin, Daily Burn Rate, and Runway based on your categorized transactions limit.
- **Scenario Sensitivity:** Computes Base vs. Best (+15% revenue / -15% costs) vs. Worst Case (-30% revenue) and shows how net profit changes at ±5%, ±10%, and ±20% revenue swings.
**How to test:** 
1. Go to the **Analytics Tab**.
2. Change the Period Selector (e.g., 3M, 6M, 12M). All charts and KPIs will re-calculate instantly.
3. Scroll down to see the Anomaly flags ("Unusual expense spike") and the Scenario Impact Bars.

---

## Tier 5: Basic Compliance Checklist
**What it is:** A quick self-audit tool to ensure bookkeeping is ready for tax season or loan applications.
**How it works:**
- `ComplianceService` checks a 90-day window against 5 strict rules:
  1. Complete income tracking (25% weight)
  2. Receipt coverage for expenses ≥ 80% (25% weight)
  3. No unexplained transactions (descriptions required) (20% weight)
  4. 100% proper categorization (no "Uncategorized") (15% weight)
  5. Accounting consistency (no missing weeks of data) (15% weight)
**How to test:**
1. In the **Analytics Tab**, view the "Compliance Check" mini-donut card.
2. Tap it to enter the Full Compliance Screen to view which specific checks passed (Green), need warnings (Orange), or failed (Red).

---

## Tier 6: Advanced Financial Advice & What-If Modeler
**What it is:** An interactive financial sandbox and automated CFO advisor.
**How it works:** 
- **AdviceService:** Uses an Insight Engine to generate narrative advice across 4 categories (Performance, Risk, Opportunity, Compliance-lite). Insights are scored dynamically using the formula `Impact × Probability × Urgency / Complexity`. Currently ranks the top 6 most critical insights.
- **What-If Modeler:** Pure algorithmic sandbox providing 4 key levers to test your 3-month runway:
  1. *Hire Staff:* Adds a monthly salary burden, extending expenses over 3 months, and outputs a "Break-even" calculation based on a 20% assumed margin.
  2. *Price Change:* Adjusts your revenue baseline by ±% assuming volume is neutral, flagging break-even volume offsets.
  3. *Take a Loan:* Simulates an upfront cash injection minus a 12-month 15% flat repayment schedule affecting subsequent burn rate.
  4. *Major Client:* Adds an influx of monthly recurring revenue, calculating concentration risk (e.g., "This client equals 40% of total revenue").
**How to test:**
1. In the **Analytics Tab**, tap the "Financial Advice" card at the bottom.
2. In the Advice Screen, read the ranked recommendations.
3. Below the recommendations, tap on the scenario chips ("Hire Staff", "Price Change", etc.).
4. Drag the slider. You will see the "Net Change" and "Runway +Days" impact tiles recompute live alongside a dynamic summary text.
