import SwiftUI

/// Static "About Tincta" screen: app icon-mark, version, short description,
/// and credits. Reachable from Settings.
public struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Wordmark
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.tinctaInk)
                            .frame(width: 96, height: 96)
                        Text("T")
                            .font(.system(size: 56, weight: .bold, design: .serif))
                            .italic()
                            .foregroundStyle(Color.tinctaParchment)
                    }
                    .shadow(color: Color.tinctaShadow, radius: 18, x: 0, y: 8)

                    Text("Tincta")
                        .font(.tinctaDisplay())
                    Text("Version \(appVersion)")
                        .font(.tinctaUILabel())
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 16)

                // Blurb
                VStack(alignment: .leading, spacing: 14) {
                    Text("A pocket book of cocktails.")
                        .font(.tinctaBody())
                        .italic()
                    Text("""
                    Tincta is a small, opinionated recipe keeper for people who \
                    care about how a drink looks on the page as much as in the \
                    glass. Save what you love. Style it the way you'd plate it.
                    """)
                        .font(.tinctaBody())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                // Links
                VStack(spacing: 0) {
                    aboutRow(icon: "globe", title: "Website", subtitle: "tincta.app")
                    Divider().padding(.leading, 52)
                    aboutRow(icon: "envelope", title: "Contact", subtitle: "hello@tincta.app")
                    Divider().padding(.leading, 52)
                    aboutRow(icon: "hand.raised", title: "Privacy", subtitle: "Your recipes stay on-device.")
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding(.horizontal, 20)

                // Type credit — required by the SIL Open Font License v1.1
                // that the bundled EB Garamond TTFs ship under. Full license
                // text is at Tincta/Resources/Fonts/OFL.txt.
                VStack(spacing: 0) {
                    aboutRow(icon: "textformat",
                             title: "Type",
                             subtitle: "EB Garamond by Georg Duffner & Octavio Pardo, SIL Open Font License v1.1.")
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding(.horizontal, 20)

                Text("Crafted with care.")
                    .font(.tinctaUILabel())
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func aboutRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.tinctaInk)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.tinctaUILabel())
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

#Preview("About") {
    NavigationStack {
        AboutView()
    }
}
