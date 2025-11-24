<<<<<<< HEAD
# Patotrack
=======
# PatoTrack - Business Expense Tracking App
>>>>>>> 29ce131 (Update README and .gitignore; remove deprecated Firestore service and modernize home and category management screens)

A modern, beautiful expense tracking application built with Flutter, designed specifically for business financial management. Track your income, expenses, bills, and generate professional reports for loan applications and investor pitches.

## Features

- 🔐 **Secure Authentication**: Email/password and Google Sign-In support
- 📊 **Business Expense Tracking**: Track all your business transactions with categories
- 💰 **Income & Expense Management**: Monitor cash flow with detailed summaries
- 📅 **Bill Reminders**: Never miss a payment with recurring bill reminders
- 📈 **Financial Reports**: Generate professional PDF reports for loan/investor applications
- 🎨 **Modern Material Design 3**: Beautiful, modern UI with dark mode support
- 🔒 **Passcode Protection**: Secure your app with a 4-digit passcode
- 📱 **M-Pesa Integration**: Automatic transaction detection from SMS
- ☁️ **Cloud Sync**: Data synced across devices via Firebase
- 📸 **Profile Management**: Customize your profile with photo uploads

## Tech Stack

- **Framework**: Flutter 3.2.3+
- **Backend**: Firebase (Authentication, Firestore)
- **Database**: SQLite (Local) + Cloud Firestore (Sync)
- **Design**: Material Design 3
- **State Management**: Provider
- **Authentication**: Firebase Auth + Google Sign-In

## Getting Started

### Prerequisites

- Flutter SDK (>=3.2.3)
- Dart SDK
- Firebase project set up
- Android Studio / Xcode (for mobile development)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd PatoTrack-app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Set up Firebase:
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place them in `android/app/` and `ios/Runner/` respectively
   - **Note**: These files are gitignored for security

4. Configure Google Sign-In:
   - Enable Google Sign-In in Firebase Authentication
   - Add SHA-1 fingerprint for Android
   - Configure OAuth client IDs for iOS

5. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── auth_gate.dart              # Authentication routing
├── main.dart                   # App entry point & theme
├── theme_provider.dart         # Theme management
├── firebase_options.dart       # Firebase configuration
├── helpers/
│   ├── database_helper.dart    # SQLite & Firestore operations
│   ├── pdf_helper.dart         # PDF report generation
│   ├── sms_service.dart        # M-Pesa SMS parsing
│   ├── notification_service.dart
│   └── config.dart            # App configuration
├── models/
│   ├── transaction.dart
│   ├── bill.dart
│   ├── category.dart
│   ├── frequency.dart
│   └── help_article.dart
├── screens/
│   ├── welcome_screen.dart
│   ├── login_screen.dart
│   ├── signup_screen.dart
│   ├── home_screen.dart
│   ├── add_transaction_screen.dart
│   ├── transaction_detail_screen.dart
│   ├── all_transactions_screen.dart
│   ├── reports_screen.dart
│   ├── add_bill_screen.dart
│   ├── manage_categories_screen.dart
│   ├── manage_frequencies_screen.dart
│   ├── profile_screen.dart
│   ├── passcode_screen.dart
│   ├── help_screen.dart
│   ├── faq_screen.dart
│   └── help_article_detail_screen.dart
├── services/
│   └── google_sign_in_service.dart
└── widgets/
    ├── input_fields.dart       # Standardized form inputs
    ├── loading_widgets.dart    # Loading indicators & skeletons
    ├── dialog_helpers.dart     # Reusable dialogs
    └── modern_date_picker.dart # Date selection
```

## Key Features Details

### Business-Only Tracking
The app is designed exclusively for business expense tracking. All transactions are tagged as "business" and reports are generated specifically for business financial documentation.

### M-Pesa Integration
Automatically detects and imports M-Pesa transactions from SMS messages, categorizing them as income or expenses.

### Professional Reports
Generate PDF reports that include:
- Income and expense summaries
- Category breakdowns
- Professional formatting suitable for loan applications and investor pitches
- Clean transaction lists without sensitive M-Pesa transaction IDs

### Bill Management
- Add recurring bills with custom frequencies
- Manage frequency templates (weekly, monthly, custom)
- Automatic due date calculations
- Visual bill reminders

## Security

- Firebase Authentication for secure user management
- Passcode protection for app access
- Local SQLite database with Firestore cloud sync
- Sensitive files (Firebase configs) are gitignored

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## License

This project is private and proprietary.

## Support

For support, contact via WhatsApp: +254717880017

## Version

Current version: 1.0.0+1
