import Foundation

// Cloudflare Access service token for the StoryCharts iOS app.
// This lets the app bypass the interactive email OTP wall so that
// App Store reviewers (and regular users) can reach the backend
// without receiving a PIN. Writes still require a CF_Authorization
// cookie from an interactive sign-in or the hardcoded demo token.
//
// This is a personal hobby project — the token is intentionally
// committed so the repo builds cleanly. Rotate the token in the
// Cloudflare Zero Trust dashboard if it ever leaks in a way that
// matters.
enum APIConfig {
    static let cfAccessClientID = "3f28d10d82ed8f2442f146c0b0c56aa0.access"
    static let cfAccessClientSecret = "5886c5dd4a6fcc779702caced4063a46f28a69c96c49bd6ee1f871785fc1749f"
}
