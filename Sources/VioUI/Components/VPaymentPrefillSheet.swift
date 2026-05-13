import SwiftUI
import VioCore
import VioDesignSystem

// MARK: - Payment prefill sheet (Fase Pago-2b)
//
// Tiny SwiftUI sheet that collects the minimal data Klarna + Stripe
// need so we can short-circuit the legacy address step entirely.
//
// **Why this exists** — Commerce backend's resolvers
// `CreatePaymentIntentStripe` and `CreatePaymentKlarnaNative` both reject
// a checkout without `email + shipping_address + billing_address`
// (verified empirically 2026-05-13 via direct GraphQL probes; see
// `DIRECT-PAYMENT-LAUNCH-PLAN.md` Fase Pago-2 findings). The previous
// "direct-launch" pre-flight in `triggerSponsorStripe` /
// `triggerSponsorKlarna` worked around this with hardcoded "John Doe"
// test data — fine for demo, not production.
//
// This sheet replaces the hardcode with real, minimal user input.
// Per [Klarna iOS docs](https://docs.klarna.com/payments/mobile-payments/
// integrate-with-mobile-sdk/ios/klarna-payments/), `email + postal_code
// + country` is the sweet spot for pre-qualification: Klarna can decide
// which payment methods to offer (different country/region rules) AND
// pre-fill the buyer's form inside the webview.
//
// Country comes from `selectedMarket` (already known). User only
// supplies `email + postal_code` — 2 inputs, ~10 seconds.
//
// **Why a separate sheet vs inline** — keeps the cart overlay
// untouched (no legacy step flow re-entry, no scope mutation). Sheet
// dismisses on submit/cancel and the trigger function continues with
// the captured data. Reused identically across Stripe and Klarna (and
// future direct-launch methods like Vipps).
//
// **Cache** — the parent stores the last-submitted values in
// `CartManager.cachedPrefillData` (Fase Pago-2b/A5, follow-up). On
// repeat purchase within the session the sheet auto-fills; user can
// edit if they want or hit Continue right away.

/// Payload returned by the sheet on submit. Country comes from the
/// active `selectedMarket` so the sheet doesn't ask for it.
public struct VPaymentPrefillData: Equatable {
    public let email: String
    public let postalCode: String
    public let country: String  // ISO 2-letter code, e.g. "NO"

    public init(email: String, postalCode: String, country: String) {
        self.email = email
        self.postalCode = postalCode
        self.country = country
    }
}

@MainActor
public struct VPaymentPrefillSheet: View {

    /// Display name of the payment method that triggered this sheet,
    /// used in the title copy ("Pay with Apple Pay" etc). Optional.
    public let methodLabel: String?

    /// ISO 2-letter country code from the active market. Locked,
    /// shown read-only as context (so the user knows what jurisdiction
    /// they're being asked to fill in for).
    public let countryCode: String

    /// Optional pre-filled values (from CartManager cache after the
    /// first successful purchase in this session).
    public let initialEmail: String
    public let initialPostalCode: String

    /// Called when the user taps the primary CTA with a valid form.
    public let onSubmit: (VPaymentPrefillData) -> Void

    /// Called when the user cancels / dismisses without submitting.
    public let onCancel: () -> Void

    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    @State private var email: String
    @State private var postalCode: String
    @FocusState private var focusedField: FocusableField?

    private enum FocusableField: Hashable {
        case email
        case postalCode
    }

    public init(
        methodLabel: String? = nil,
        countryCode: String,
        initialEmail: String = "",
        initialPostalCode: String = "",
        onSubmit: @escaping (VPaymentPrefillData) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.methodLabel = methodLabel
        self.countryCode = countryCode
        self.initialEmail = initialEmail
        self.initialPostalCode = initialPostalCode
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        self._email = State(initialValue: initialEmail)
        self._postalCode = State(initialValue: initialPostalCode)
    }

    public var body: some View {
        let colors = VioColors.adaptive(for: colorScheme)
        VStack(alignment: .leading, spacing: VioSpacing.lg) {
            header(colors: colors)
            fieldsBlock(colors: colors)
            Spacer(minLength: VioSpacing.md)
            submitButton(colors: colors)
        }
        .padding(VioSpacing.lg)
        .background(colors.background.ignoresSafeArea())
        .onAppear {
            // Auto-focus the first empty field for fast entry.
            if email.isEmpty {
                focusedField = .email
            } else if postalCode.isEmpty {
                focusedField = .postalCode
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func header(colors: AdaptiveColors) -> some View {
        VStack(alignment: .leading, spacing: VioSpacing.xs) {
            HStack {
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(VioTypography.title3)
                        .foregroundColor(colors.textSecondary)
                }
                .accessibilityLabel("Cancel")
            }

            Text(headerTitle)
                .font(VioTypography.title2)
                .foregroundColor(colors.textPrimary)

            Text(headerSubtitle)
                .font(VioTypography.body)
                .foregroundColor(colors.textSecondary)
        }
    }

    @ViewBuilder
    private func fieldsBlock(colors: AdaptiveColors) -> some View {
        VStack(alignment: .leading, spacing: VioSpacing.md) {
            // Email
            VStack(alignment: .leading, spacing: VioSpacing.xs) {
                Text("Email")
                    .font(VioTypography.caption1.weight(.semibold))
                    .foregroundColor(colors.textSecondary)
                TextField("you@example.com", text: $email)
                    .focused($focusedField, equals: .email)
                    .font(VioTypography.body)
                    .foregroundColor(colors.textPrimary)
                    .padding(VioSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                            .fill(colors.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                            .stroke(colors.border, lineWidth: 1)
                    )
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
                    .submitLabel(.next)
                    .onSubmit { focusedField = .postalCode }
            }

            // Postal code + country (read-only) on same row
            HStack(spacing: VioSpacing.md) {
                VStack(alignment: .leading, spacing: VioSpacing.xs) {
                    Text("Postal code")
                        .font(VioTypography.caption1.weight(.semibold))
                        .foregroundColor(colors.textSecondary)
                    TextField("0150", text: $postalCode)
                        .focused($focusedField, equals: .postalCode)
                        .font(VioTypography.body)
                        .foregroundColor(colors.textPrimary)
                        .padding(VioSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                                .fill(colors.surfaceSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                                .stroke(colors.border, lineWidth: 1)
                        )
                        #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                        .textContentType(.postalCode)
                        #endif
                        .submitLabel(.done)
                        .onSubmit(submitIfValid)
                }

                VStack(alignment: .leading, spacing: VioSpacing.xs) {
                    Text("Country")
                        .font(VioTypography.caption1.weight(.semibold))
                        .foregroundColor(colors.textSecondary)
                    Text(countryCode.uppercased())
                        .font(VioTypography.body)
                        .foregroundColor(colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(VioSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                                .fill(colors.surfaceSecondary.opacity(0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                                .stroke(colors.border, lineWidth: 1)
                        )
                }
                .frame(width: 80)
            }
        }
    }

    @ViewBuilder
    private func submitButton(colors: AdaptiveColors) -> some View {
        Button(action: submitIfValid) {
            HStack(spacing: VioSpacing.sm) {
                Text(submitLabel)
                    .font(VioTypography.bodyBold)
                Image(systemName: "arrow.right")
                    .font(VioTypography.footnote.weight(.semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, VioSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                    .fill(isValid ? VioColors.primary : VioColors.primary.opacity(0.4))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isValid)
    }

    // MARK: - Validation + submit

    private var isValid: Bool {
        validatedData() != nil
    }

    private func submitIfValid() {
        if let data = validatedData() {
            onSubmit(data)
        }
    }

    /// Light validation: email looks email-shaped, postal code non-empty.
    /// Backend will reject anything truly garbage — this is just to keep
    /// the submit button honest.
    private func validatedData() -> VPaymentPrefillData? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedZip = postalCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            return nil
        }
        guard !trimmedZip.isEmpty else { return nil }
        return VPaymentPrefillData(
            email: trimmedEmail,
            postalCode: trimmedZip,
            country: countryCode.uppercased()
        )
    }

    // MARK: - Copy

    private var headerTitle: String {
        if let label = methodLabel, !label.isEmpty {
            return "Pay with \(label)"
        }
        return "Almost there"
    }

    private var headerSubtitle: String {
        // Mention that the provider will collect the rest — sets
        // expectation that this is the SMALL prompt, not the form.
        if let label = methodLabel, !label.isEmpty {
            return "We just need your email and postal code. \(label) will ask for the rest."
        }
        return "We just need your email and postal code to continue."
    }

    private var submitLabel: String {
        if let label = methodLabel, !label.isEmpty {
            return "Continue to \(label)"
        }
        return "Continue"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Empty") {
    VPaymentPrefillSheet(
        methodLabel: "Klarna",
        countryCode: "NO",
        onSubmit: { _ in },
        onCancel: { }
    )
}

#Preview("Pre-filled") {
    VPaymentPrefillSheet(
        methodLabel: "Card",
        countryCode: "NO",
        initialEmail: "angelo@reachu.io",
        initialPostalCode: "0150",
        onSubmit: { _ in },
        onCancel: { }
    )
}
#endif
