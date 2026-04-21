package com.jamesdai.storycharts.data

// Cloudflare Access service token. Bypasses the interactive email OTP wall
// so the app can reach the backend directly. Rotate in the Cloudflare Zero
// Trust dashboard if leaked.
object ApiConfig {
    const val CF_ACCESS_CLIENT_ID = "3f28d10d82ed8f2442f146c0b0c56aa0.access"
    const val CF_ACCESS_CLIENT_SECRET =
        "5886c5dd4a6fcc779702caced4063a46f28a69c96c49bd6ee1f871785fc1749f"

    const val BASE_URL = "https://storycharts.com/api"
}
