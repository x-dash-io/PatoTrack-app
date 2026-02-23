
Upgrade Suggestions for PatoTrack App
Observed Issues and Design Patterns

During a review of the Flutter code in PatoTrack-app, several UI patterns contributed to a “blurred” or unpolished feel:

Heavy drop‑shadows and blur radii. Numerous screens use BoxShadow with large blurRadius values (e.g., 20 or more). Examples include the login screen’s gradient logo container, the home screen’s floating action button and card decorations with blur radii of 12–20, the FAQ search bar with blurRadius: 10, the sign‑up screen’s logo container with a 20‑pixel blur, and the profile screen’s header cards with two drop shadows (blur 20 & 10). These large shadows create a hazy, “blurred” appearance and make the UI feel heavy.

Multiple gradients and dark overlays. Many screens apply multi‑stop gradients over large containers; sometimes a semi‑transparent black overlay (Colors.black54) is used in loading overlays, which darkens content and exacerbates blur. While gradients can look attractive, overuse across several screens reduces contrast and can feel dated.

Inconsistent spacing and typography. The project uses a custom ResponsiveHelper to scale sizes, but spacing and font sizes differ across screens. For example, the login screen uses large padding and big titles, while the FAQ screen has compact spacing; font weights and sizes vary widely.

Long, monolithic widget files. Screens like home_screen.dart contain hundreds of lines of UI and business logic in a single file. This makes it difficult to maintain and adjust layout elements consistently. Shadows and decorations are defined inline rather than centralized.

Recommendations to Achieve a Premium Look and Clean Code
1. Reduce and Standardize Shadows

Use subtle elevations. A modern, premium UI favors light shadows and crisp edges. Replace large blurRadius values (20) with smaller values (4–6) and reduce opacity. For example, the profile header’s double shadow can be simplified to a single shadow such as:

BoxShadow(
  color: colorScheme.primary.withOpacity(0.12),
  blurRadius: 6,
  offset: Offset(0, 4),
)


Centralize shadow definitions. Create a constants.dart file with reusable shadow styles (e.g., kCardShadow, kElevatedShadow). Apply these constants consistently so the UI feels cohesive.

Avoid stacking multiple BoxShadows unless necessary for a specific effect. In most cases, a single subtle shadow is sufficient.

2. Simplify Gradients and Backgrounds

Limit multi‑stop gradients. Use solid or lightly shaded backgrounds for primary containers. Reserve gradients for accent elements (e.g., app logo or hero section) to avoid visual fatigue.

Introduce a neutral surface color. Many screens use the theme’s surface color for backgrounds; choose a light or dark neutral tone based on the current theme mode. For dark mode, consider a deep grey; for light mode, off‑white works well.

Eliminate unnecessary overlays. The loading overlay uses a semi‑transparent black layer that makes content appear blurry. Replace it with a dimming layer of low opacity (e.g., Colors.black.withOpacity(0.05)) or a blurred loader with minimal opacity to maintain clarity while signalling a loading state.

3. Unify Typography and Spacing

Adopt a consistent typography scale. Define a typographic scale in ThemeData (e.g., headline1/2/3, body1/2). Use these consistently rather than specifying font sizes manually. This ensures balanced hierarchy across screens.

Use a global spacing system. Replace ad‑hoc EdgeInsets with spacing constants (e.g., kPaddingSmall, kPaddingMedium, kPaddingLarge). The existing ResponsiveHelper can be simplified into spacing constants that adapt to screen size.

Standardize form and button styles. The sign‑up and login screens already use modern cards and filled buttons. Extract these into reusable widgets (AppButton, AppCard) with consistent border radius, padding and color states.

4. Modularize and Clean Up the Codebase

Break large screens into smaller widgets. home_screen.dart should be decomposed into separate widgets for “Summary Card”, “Recent Transactions”, “Bills List”, etc. Each widget can reside in its own file under a widgets/ directory. This not only improves readability but also enables reusability across screens.

Move business logic out of UI files. Use providers, blocs or controllers to manage state (the project currently uses Provider for theming). For example, extract transaction fetching, bill payment and user interactions into services or view models. This separation helps maintain premium UI while keeping logic testable.

Create a central theme file. Use ThemeData and ColorScheme to define colors, shapes and component themes (buttons, cards, inputs). This reduces duplication of gradient and shadow code across files and ensures a unified look.

Remove unused imports and debug prints. Several files include unused packages (e.g., url_launcher appears in many screens). Removing unused imports and debug statements cleans up the codebase.

Document components. Add comments explaining the purpose of widgets and any complex logic. This aids onboarding of new developers and clarifies design decisions.

5. Polishing the User Experience

Smooth transitions. Use Hero animations or PageRoute transitions for navigation to provide a premium feel. For instance, animate the profile picture or card expansions in the home screen.

Interactive feedback. Provide subtle feedback on tap (ink ripples or scale animations) rather than heavy color changes. Remove “blurry” overlays and instead show crisp progress indicators within buttons (as done in the sign‑up screen’s Google button).

Accessibility. Ensure sufficient color contrast between text and background. Avoid semi‑transparent overlays that reduce readability, and support dynamic font sizes for users who increase system font size.

Light/dark mode optimisation. The app already supports dark mode toggling. Verify that all screens adhere to the same color scheme (no hard‑coded light colors in dark mode). Test the gradient backgrounds and shadows in both modes; subtle shadows are especially important in dark mode to avoid muddy surfaces.

6. Roadmap for Implementation

Design Audit: create a style guide summarizing colors, typography, spacing and components. Decide on a primary palette and accent colors.

Theme Refactoring: implement a new AppTheme class that wraps ThemeData and defines colors, shapes, typography and shadow constants. Update main.dart to use this theme.

Component Extraction: extract reusable UI elements (cards, list tiles, form fields, loaders) into separate widgets under lib/widgets. Replace inline code across screens with these components.

Shadow & Gradient Reduction: systematically reduce blurRadius values and remove redundant BoxShadows, referencing the new shadow constants. Simplify gradients by limiting stops and using subtle shading.

Page Refactor: refactor complex screens (especially home and profile) into smaller sub‑widgets and move logic to controllers/services. Ensure each file remains under ~300 lines for maintainability.

Testing & Polishing: test the new UI on multiple device sizes using the ResponsiveHelper or a refined layout system. Fine‑tune spacing, contrast and interactions. Get feedback from users or designers to ensure the app feels premium.

Conclusion

The PatoTrack app already has many modern UI elements like gradient accents and custom fonts, but the overall experience feels blurred because of heavy shadows, overlapping gradients and inconsistent spacing. By reducing blur radii, simplifying backgrounds, unifying typography and modularizing the codebase, the app can achieve a premium, polished look while remaining maintainable. A cohesive theme and reusable widgets will streamline future development and ensure design consistency across all screens.