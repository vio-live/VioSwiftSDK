import SwiftUI

struct CategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category.name)
                .font(TV2Theme.Typography.body)
                .foregroundColor(isSelected ? TV2Theme.Colors.textPrimary : TV2Theme.Colors.textSecondary)
                .padding(.horizontal, TV2Theme.Spacing.lg)
                .padding(.vertical, TV2Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: TV2Theme.CornerRadius.medium)
                        .fill(isSelected ? TV2Theme.Colors.surface : TV2Theme.Colors.surface.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: TV2Theme.CornerRadius.medium)
                        .stroke(
                            isSelected ? TV2Theme.Colors.primary.opacity(0.5) : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}


