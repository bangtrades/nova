# NovaKids Custom Fonts

This directory holds the comic-book display typeface used on Tier 1 screens
(card titles, hero headlines, action words, Dashy speech-bubble header).

## Expected file

| File                 | Source                                                    | License     |
|----------------------|-----------------------------------------------------------|-------------|
| `Bangers-Regular.ttf`| https://fonts.google.com/specimen/Bangers (by Vernon Adams)| SIL OFL 1.1 |

Download the family zip, extract, and drop **only** `Bangers-Regular.ttf`
into this directory. Other weights are not currently used.

## Xcode registration — two steps

1. **Add the file to the NovaKids target.** In Xcode: File → Add Files to
   "NovaKids"… → select `Bangers-Regular.ttf` → ensure "Copy items if
   needed" is checked and the NovaKids target's membership box is ticked.

2. **Register in Info.plist.** Add a `UIAppFonts` array entry pointing at
   the file (relative path from the app bundle):

   ```xml
   <key>UIAppFonts</key>
   <array>
       <string>Bangers-Regular.ttf</string>
   </array>
   ```

   If `UIAppFonts` already exists, just append the string to the existing
   array.

## Verification

After the next build, print the registered families to confirm:

```swift
// Run once from AppDelegate or a debug-only view
for family in UIFont.familyNames.sorted() {
    print(family, UIFont.fontNames(forFamilyName: family))
}
```

You should see `Bangers ["Bangers-Regular"]` in the output.

## Fallback behavior

`NovaPalette.displayFont(size:)` already guards against the font being
absent — if Bangers isn't registered at runtime (because this README was
skipped, or the .ttf was dropped but not added to the target), it returns
SF Rounded Heavy at the same size so the app never crashes or renders as
system default.

This means the app is safe to build and run even without the `.ttf` in
place; the display font just looks like heavy rounded sans until the asset
lands.
