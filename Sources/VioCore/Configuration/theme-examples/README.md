# 🎨 Reachu Theme Examples

This directory contains pre-configured theme examples that you can use as starting points for your own custom themes.

## 📁 Available Themes

### 🔄 `automatic-theme.json`
**Best for:** Most applications
- Follows iOS system dark/light mode automatically
- Uses standard iOS colors
- Professional appearance that matches system apps

### 💼 `professional-blue-theme.json`
**Best for:** Business and productivity apps
- Clean, professional blue color scheme
- High contrast for readability
- Corporate-friendly appearance

### 🛍️ `green-ecommerce-theme.json`
**Best for:** Shopping and e-commerce apps
- Green primary color suggesting growth and money
- Orange secondary for call-to-actions
- Optimized for conversion

### ⚪ `minimal-theme.json`
**Best for:** Clean, minimalist apps
- Monochrome color scheme
- Reduced animations and visual noise
- Focus on content over decoration

### 🌙 `dark-only-theme.json`
**Best for:** Gaming, developer tools, or specialized apps
- Forces dark mode regardless of system setting
- Gaming-inspired color palette
- High contrast for low-light usage

## 🚀 How to Use

1. **Copy** the theme file you want to use
2. **Rename** it to `reachu-config.json`
3. **Add** your API key
4. **Customize** colors as needed
5. **Place** in your app bundle

```swift
// Load the configuration
ConfigurationLoader.loadFromJSON("reachu-config")
```

## 🎨 Customization Tips

### Colors
- Adjust `primary` and `secondary` to match your brand
- Keep high contrast between `textPrimary` and `background`
- Test both light and dark modes thoroughly

### Cart Configuration
- `bottomRight` position works for most apps
- Use `iconOnly` for minimal interfaces
- `showCartNotifications` enhances user feedback

### UI Settings
- Enable `enableAnimations` for modern feel
- `showProductBrands` depends on your use case
- `enableHapticFeedback` improves user experience

## 📱 Testing Your Theme

1. **iOS Simulator:** Settings → Developer → Dark Appearance
2. **Device:** Settings → Display & Brightness → Appearance
3. **Xcode Previews:** Use `.preferredColorScheme(.dark)` and `.preferredColorScheme(.light)`

## 🎯 Need Help?

- 📖 [Complete Dark/Light Mode Guide](../../../DARK_LIGHT_MODE_GUIDE.md)
- 📋 [Configuration Guide](../../../CONFIGURATION_GUIDE.md)
- 👨‍💻 [Developer Documentation](../../../DEVELOPER_CONFIGURATION_GUIDE.md)

Happy theming! 🌟
