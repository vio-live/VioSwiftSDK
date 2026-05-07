//
//  MaxboArticleView.swift
//  Vg
//
//  Full advertorial article ("Alt du trenger til verktøykassen") sheet.
//  Layout follows the real VG advertorial pattern:
//    - sticky top bar (Ferdig / ANNONSØRINNHOLD / brand badge)
//    - full-width hero with overlaid headline
//    - body sections + images + quotes + CTA buttons
//    - product blocks rendered via VProductCarousel (real Vio SDK,
//      backed by campaign 38 → component "product-carousel-template")
//    - footer disclaimer (Schibsted Partnerstudio)
//

import SwiftUI
import VioCore
import VioUI

// MARK: - Article view

struct MaxboArticleView: View {
    /// Called when the user taps "Ferdig". The host owns the presentation
    /// state (VGHomeView) so the article can animate out with a push.
    var onClose: () -> Void = {}

    /// Observe Vio config so the topbar's sponsor logo updates live the
    /// moment the SDK bootstrap finishes (or sponsor changes).
    @ObservedObject private var vioConfig = VioConfiguration.shared

    /// Resolve the sponsor logo URL for the topbar badge — prefer the
    /// wide `logoUrl` (wordmark) over `avatarUrl` (square mark).
    private var sponsorLogoURL: URL? {
        let sponsor = vioConfig.primarySponsor
        let candidate = sponsor?.logoUrl ?? sponsor?.avatarUrl
        return candidate.flatMap { URL(string: $0) }
    }

    private var sponsorName: String {
        vioConfig.primarySponsor?.name ?? "Annonse"
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white
                .ignoresSafeArea()
                .contentShape(Rectangle())

            ScrollView {
                // LazyVStack so the 3 VProductCarousel instances only spin
                // up when scrolled into view — eager construction of all 3
                // at once was freezing the main thread (each one fetches
                // products + images via the SDK on appear).
                LazyVStack(spacing: 0) {
                    hero
                    introBlock
                    discountBanner
                    section(
                        title: "Den allsidige stikksagen",
                        bodyParagraphs: [
                            "Når det gjelder valg av verktøy, er stikksagen en av Runes favoritter. Den er perfekt for både rette snitt og komplekse former – som runde bordplater."
                        ]
                    )
                    captionedImage(
                        url: URL(string: "https://cdn.vev.design/cdn-cgi/image/f=auto,q=82,w=1920/private/1pf9ZywbSqclWs0r8IjCFrrptpU2/image/7hTbmXHNLa.jpg"),
                        caption: "Visste du at stikksagen kan vinkles?"
                    )
                    pullQuote(
                        "– Det er kanskje den mest allsidige sagen som finnes. Med den kan du skjære vinkler, rette snitt og kurver. Perfekt for sirkler! sier Rune entusiastisk."
                    )

                    sdkProductCarousel(title: "Stanley Fatmax-verktøy")

                    section(
                        title: "Pene kutt og gode triks",
                        bodyParagraphs: [
                            "Han og livesending-makkeren hans fra Stanley og Dewalt gir også noen konkrete tips for å få et så pent kutt som mulig:",
                            "– Når du har pendelfunksjonen på maks, blir det litt mer aggressivt og raskere, men ikke så pent. Sett den i null for renere kutt, og jo flere tenner sagbladet har, jo penere blir kuttet.",
                            "Husk også at sagbladet drar oppover, slik at treverket fliser seg opp mot sagen. Tenk over hvilken side av treverket som skal være penest, sag opp ned – så slipper du mye av pussejobben."
                        ]
                    )

                    section(
                        title: "Apropos pussing …",
                        bodyParagraphs: [
                            "Rune er spesielt opptatt av detaljene som kan heve et møbel til et nytt nivå, og han anbefaler den håndholdte overfresen fra Stanley Fatmax som et fantastisk verktøy for dette formålet.",
                            "– Overfresen gjør at møblene ser mer profesjonelle ut. Den lager raskt den fineste kanten, sier Rune."
                        ]
                    )
                    captionedImage(
                        url: URL(string: "https://cdn.vev.design/cdn-cgi/image/f=auto,q=82,w=1920/private/1pf9ZywbSqclWs0r8IjCFrrptpU2/image/jfNivGFcZa.jpg"),
                        caption: nil
                    )

                    section(
                        title: "Tålmodighet gir resultat",
                        bodyParagraphs: [
                            "Pussing er et viktig steg for å oppnå en glatt og fin overflate, men Rune påpeker at det krever litt tålmodighet, selv med eksentersliper:"
                        ]
                    )
                    pullQuote(
                        "– Ikke push maskinen, la den gjøre jobben. Bare la den jobbe over bordplaten din, så blir det en veldig fin overflate. Det er lurt å jobbe systematisk fra grovt til fint sandpapir."
                    )
                    section(
                        title: nil,
                        bodyParagraphs: [
                            "Unngå også å pusse på tvers av treverkets vekstretning.",
                            "– Hvis du gjør det kan det oppstå stygge riper som eventuell etterbehandling med farget voks og olje vil fremheve, sier Rune."
                        ]
                    )
                    captionedImage(
                        url: URL(string: "https://cdn.vev.design/cdn-cgi/image/f=auto,q=82,w=1920/private/1pf9ZywbSqclWs0r8IjCFrrptpU2/image/dV8AEIOdQl.jpg"),
                        caption: nil
                    )

                    sdkProductCarousel(title: "Tilbehør til Stanley Fatmax")

                    primaryCTAButton(title: "Se liveshoppingen her")

                    section(
                        title: "Siste finish",
                        bodyParagraphs: [
                            "Rune er opptatt av å bevare den naturlige fargen på treverket når man oljer det. Han trekker spesielt frem Osmo dekorvoks som et godt valg for å oppnå dette, uten at treverket får en uønsket gul tone.",
                            "– Osmo har et veldig fint produkt som heter Naturell. Det har bittelitt hvitpigment i seg, og det gjør at den naturlige gløden i eiken bevares uten at den blir gul, forklarer Rune, og legger til at dette er et godt valg for de som ønsker å beholde det lyse, naturlige utseendet på eik."
                        ]
                    )

                    sdkProductCarousel(title: "Osmo-produkter")

                    section(
                        title: "Ikke gi deg!",
                        bodyParagraphs: [
                            "Rune avslutter med et viktig råd til alle som gir seg i kast med gjør-det-selv-prosjekter:",
                            "– Det viktigste er at du tør å begynne på det. Hvis du gjør feil: Fortsett, så har du lært til neste gang.",
                            "Med disse tipsene er du godt rustet til å starte ditt eget møbelprosjekt – og med riktig verktøy kan du forvandle ideer til virkelighet raskere og enklere enn du kanskje hadde trodd."
                        ]
                    )

                    fullImage(
                        url: URL(string: "https://cdn.vev.design/cdn-cgi/image/f=auto,q=82,w=1920/private/1pf9ZywbSqclWs0r8IjCFrrptpU2/image/_8mnghP8GX.jpg")
                    )
                    fullImage(
                        url: URL(string: "https://cdn.vev.design/cdn-cgi/image/f=auto,q=82,w=1920/private/1pf9ZywbSqclWs0r8IjCFrrptpU2/image/1xBt38RihF.jpg")
                    )

                    footer

                    Spacer().frame(height: 60)
                }
            }
            // Push the hero down so its full image is visible below the
            // floating top bar (instead of being partially clipped by it).
            .safeAreaInset(edge: .top, spacing: 0) {
                // Match the top-bar height so the article content always
                // starts where the bar ends. The bar itself paints the
                // background, so this inset is just a spacer.
                Color.clear.frame(height: topBarHeight)
            }

            topBar
        }
    }

    // MARK: - Top bar

    private let topBarHeight: CGFloat = 56

    private var topBar: some View {
        HStack(alignment: .center) {
            Button {
                onClose()
            } label: {
                Text("Ferdig")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color(white: 0.92))
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 6) {
                Rectangle()
                    .fill(VGTheme.Colors.brandRed)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Text("VG")
                            .font(.system(size: 10, weight: .black))
                            .italic()
                            .foregroundColor(.white)
                    )

                Text("ANNONSØRINNHOLD")
                    .font(.system(size: 12, weight: .bold))
                    .kerning(0.6)
                    .foregroundColor(.black)
            }

            Spacer()

            sponsorBadge
        }
        .padding(.horizontal, 12)
        .frame(height: topBarHeight)
        .background(Color.white.opacity(0.97))
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    /// Sponsor wordmark on the right of the topbar. Reads
    /// `VioConfiguration.shared.primarySponsor` so it auto-updates when
    /// the dashboard changes the sponsor (after SDK re-bootstrap on next
    /// launch). Falls back to the sponsor name (or "Annonse") if the
    /// logo URL is missing or fails to decode.
    @ViewBuilder
    private var sponsorBadge: some View {
        Group {
            if let url = sponsorLogoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 22)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                    default:
                        sponsorTextFallback
                    }
                }
            } else {
                sponsorTextFallback
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var sponsorTextFallback: some View {
        Text(sponsorName)
            .font(.system(size: 14, weight: .black))
            .foregroundColor(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            VGNewsRemoteImage(
                url: URL(string: "https://cdn.vev.design/cdn-cgi/image/f=auto,q=82,h=1920/private/1pf9ZywbSqclWs0r8IjCFrrptpU2/image/2vDTdnW-OF.jpg"),
                aspect: .fill
            )
            .frame(height: 460)
            .frame(maxWidth: .infinity)
            .clipped()

            // Gradient for legibility under headline
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 240)
            .frame(maxWidth: .infinity, alignment: .bottom)

            VStack(alignment: .leading, spacing: 6) {
                Text("Fra idé til ferdig møbel:")
                    .font(.custom("Georgia", size: 16))
                    .foregroundColor(.white.opacity(0.85))

                Text("Alt du trenger til verktøykassen")
                    .font(.custom("Georgia-Bold", size: 36))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Intro block

    private var introBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Å bygge egne møbler er enklere enn du tror, ifølge Eventyrlig oppussing-snekker Rune Strandenes. Han fremhever at riktig verktøy og en liten plan er alt du trenger for å komme i gang.")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.black)
                .lineSpacing(2)

            Text("Mandag 21. oktober var det liveshopping på VG med Maxbo og snekker Rune. Her delte håndverkeren sine beste tips og triks til hobbysnekkeren – både når det kommer til verktøy og møbelsnekring.")
                .font(.system(size: 16))
                .foregroundColor(.black.opacity(0.85))
                .lineSpacing(3)

            Text("– Du trenger bare vanlige hobbyplater i eik eller furu fra Maxbo for å lage flotte møbler, sier Rune.")
                .font(.system(size: 16))
                .foregroundColor(.black.opacity(0.85))
                .lineSpacing(3)

            primaryCTAButton(title: "Se liveshoppingen her", inset: false)
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Discount banner

    private var discountBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rabattkode: Maxbo25")
                .font(.custom("Georgia-Bold", size: 22))
                .foregroundColor(.black)

            Text("Bruker du rabattkoden ")
                .font(.system(size: 15))
                .foregroundColor(.black.opacity(0.85))
            +
            Text("Maxbo25")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.black)
            +
            Text(", får du 25 % rabatt på alle varene snekker Rune viser i livesendingen frem til 27.10.2024.")
                .font(.system(size: 15))
                .foregroundColor(.black.opacity(0.85))

            Button {
                // CTA — wire to commerce in last step
            } label: {
                Text("Sjekk tilbudene hos Maxbo!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(VGTheme.Colors.brandRed)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 1.0, green: 0.97, blue: 0.86))
        )
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    // MARK: - Section helpers

    private func section(title: String?, bodyParagraphs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title)
                    .font(.custom("Georgia-Bold", size: 24))
                    .foregroundColor(.black)
                    .padding(.top, 12)
            }
            ForEach(bodyParagraphs, id: \.self) { p in
                Text(p)
                    .font(.system(size: 16))
                    .foregroundColor(.black.opacity(0.85))
                    .lineSpacing(4)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func captionedImage(url: URL?, caption: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VGNewsRemoteImage(url: url, aspect: .fill)
                .frame(height: 240)
                .frame(maxWidth: .infinity)
                .clipped()
            if let caption = caption {
                Text(caption)
                    .font(.system(size: 13, weight: .regular))
                    .italic()
                    .foregroundColor(.black.opacity(0.55))
                    .padding(.horizontal, 18)
            }
        }
        .padding(.vertical, 14)
    }

    private func fullImage(url: URL?) -> some View {
        VGNewsRemoteImage(url: url, aspect: .fill)
            .frame(height: 240)
            .frame(maxWidth: .infinity)
            .clipped()
            .padding(.vertical, 8)
    }

    private func pullQuote(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Rectangle()
                .fill(VGTheme.Colors.brandRed)
                .frame(width: 3)

            Text(text)
                .font(.custom("Georgia", size: 18))
                .italic()
                .foregroundColor(.black)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func primaryCTAButton(title: String, inset: Bool = true) -> some View {
        Button {
            // wire to live-shopping later
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(VGTheme.Colors.brandRed)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, inset ? 18 : 0)
        .padding(.vertical, 8)
    }

    // MARK: - Product carousel (real, SDK-driven)

    /// Renders the campaign 38 → "product-carousel-template" placement
    /// (4 Weber products from the Reachu commerce channel). Repeated 3x
    /// in the article — same products, different copy headers.
    /// To diversify per section, create extra campaign_components in the
    /// dashboard and use a different `componentId`.
    private func sdkProductCarousel(title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("Georgia-Bold", size: 22))
                .foregroundColor(.black)
                .padding(.horizontal, 18)
                .padding(.top, 8)

            VProductCarousel(componentId: "product-carousel-template", layout: "compact")
        }
        .padding(.vertical, 8)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)

            Text("Annonsørinnhold for ").font(.system(size: 13))
            +
            Text("MAXBO").font(.system(size: 13, weight: .bold))

            Text("Produsert av Schibsted Partnerstudio for MAXBO")
                .font(.system(size: 12))
                .foregroundColor(.black.opacity(0.55))
                .multilineTextAlignment(.center)

            Text("Journalistene og redaksjonene i Schibsteds medier har ingen rolle i produksjonen og publiseringen av dette annonsørinnholdet.")
                .font(.system(size: 11))
                .foregroundColor(.black.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
        }
        .padding(.vertical, 18)
    }

}

#Preview {
    MaxboArticleView()
}
