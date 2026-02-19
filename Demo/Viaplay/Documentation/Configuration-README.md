# Viaplay Demo Configuration

This directory contains the Reachu SDK configuration for the Viaplay demo app.

## Files

- `reachu-config.json` - Main configuration file for Reachu SDK

## Configuration Details

The `reachu-config.json` file configures:

1. **Theme & Branding**
   - Viaplay pink primary color (#F5142A)
   - Dark mode optimized
   - Custom typography and spacing

2. **API Configuration**
   - Environment: development
   - API Key: Shared with TV2 demo (for testing)
   - GraphQL endpoint for product catalog

3. **Features**
   - Live streaming: Enabled
   - Product catalog: Enabled
   - Checkout & Cart: Enabled
   - Wishlist: Disabled

4. **Campaign Integration**
   - Campaign ID: 3 (shared with TV2 for demo)
   - Tipio WebSocket for real-time components
   - Automatic component rendering via `DynamicComponentRenderer`

## How It Works

1. **App Initialization** (`ViaplayApp.swift`):
   ```swift
   ConfigurationLoader.loadConfiguration()
   ```
   - Loads `reachu-config.json` from the app bundle
   - Initializes SDK with Viaplay theme colors
   - Configures campaign ID and Tipio connection

2. **Video Player** (`ViaplayVideoPlayer.swift`):
   ```swift
   DynamicComponentRenderer()
   ```
   - Automatically renders campaign components
   - Connects to Campaign ID 3 via CampaignManager
   - Displays banners, products, polls, and contests in real-time

3. **Components**:
   - Custom overlays (ViaplayPollOverlay, ViaplayProductOverlay, etc.)
   - Reachu SDK components (DynamicComponentRenderer)
   - Both work together for a complete experience

## Differences from TV2 Demo

| Feature | Viaplay | TV2 |
|---------|---------|-----|
| Primary Color | #F5142A (Pink) | #7B5FFF (Purple) |
| Theme Name | Viaplay Dark Theme | TV2 Dark Theme |
| Background | #1B1B25 | #16001A |
| API Key | Same | Same |
| Campaign ID | 3 | 3 |

## Testing

To verify the configuration is loaded correctly:

1. Run the app
2. Check console logs for:
   ```
   🚀 [Viaplay] Loading Reachu SDK configuration...
   ✅ [Viaplay] Reachu SDK configured successfully
   🎨 [Viaplay] Theme: Viaplay Dark Theme
   🎯 [Reachu][Campaign] campaignId=3
   ```

3. Open a video and verify:
   ```
   🎯 [Viaplay] Connecting to Campaign ID: 3
   ```

## Troubleshooting

If configuration doesn't load:

1. Ensure `reachu-config.json` is in the Xcode project
2. Check it's included in "Copy Bundle Resources" (Build Phases)
3. Verify JSON syntax is valid
4. Check console logs for error messages

## Manual Xcode Setup (if needed)

If the file doesn't appear in Xcode:

1. Open Viaplay.xcodeproj in Xcode
2. Right-click on Viaplay folder in Project Navigator
3. Select "Add Files to Viaplay..."
4. Navigate to `Demo/Viaplay/Viaplay/Configuration/`
5. Select `reachu-config.json`
6. Ensure "Copy items if needed" is checked
7. Ensure "Viaplay" target is checked
8. Click "Add"

The new Xcode File System Synchronized Root Group should detect this automatically, but manual addition may be needed in older Xcode versions.

