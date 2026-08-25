# rn-security — Reference

Deep-dive material for `SKILL.md`. **Vulnerable (❌) vs safe (✅)** code samples per
failure mode. TypeScript + React Native, with app-config/manifest notes.
Decision criteria live in `SKILL.md`.

## Why this guard is needed (evidence)

- A large share of AI-generated code contains security flaws (multiple empirical studies).
- AI-assisted commits leak secrets more often than human-only commits.
- Developers **overtrust** AI code, believing it safer than it is.
- Mobile twist: the JS bundle + app package ship to the device — **anything
  embedded is extractable** (keys, endpoints, logic). The price of AI speed is a review gate.

## 1. Hardcoded secrets in the bundle

```ts
// ❌ Bundled into the app → extractable from the JS bundle / IPA / APK
const STRIPE_SECRET = 'sk_live_abcd1234';
await fetch('https://api.stripe.com/...', { headers: auth(STRIPE_SECRET) });

// ✅ Privileged calls go through YOUR backend; the app holds no third-party secret
await api.post('/charge', { orderId }); // server holds the secret
// Non-secret config via env at build (still shipped — non-secrets only)
const API_BASE = process.env.EXPO_PUBLIC_API_BASE_URL;
```

- `.env` in `.gitignore`; a committed secret is leaked → rotate.

## 2. Tokens/PII in secure storage

```ts
// ❌ AsyncStorage/MMKV are cleartext — not for tokens
await AsyncStorage.setItem('token', jwt);

// ✅ Keychain/Keystore via a secure-storage module
import * as SecureStore from 'expo-secure-store';
await SecureStore.setItemAsync('token', jwt);
// react-native-keychain: await Keychain.setGenericPassword('auth', jwt);
```

Detail → [rn-state-data].

## 3. Insecure networking / TLS bypass

```ts
// ❌ cleartext endpoint / disabling ATS to allow http
const API = 'http://api.example.com';         // plaintext, interceptable
// ❌ a native trust-all TLS override "to fix an SSL error"

// ✅ HTTPS + platform trust store; pin only if you maintain the pins
const API = 'https://api.example.com';
```

## 4. Unvalidated deep-link input

```ts
// ❌ link param mapped straight to a screen / redirect
config: { screens: { Order: 'order/:id' } };
navigation.navigate('Order', { id: route.params.id }); // unchecked

// ✅ validate; bad input → defined fallback; allowlist redirect targets
const id = /^[0-9]+$/.test(raw ?? '') ? raw : null;
if (!id) navigation.replace('NotFound');
```

Detail → [rn-navigation-lifecycle].

## 5. WebView misconfiguration

```tsx
// ❌ JS enabled on an arbitrary URL + a native bridge to a remote page
<WebView source={{ uri: userUrl }} javaScriptEnabled injectedJavaScript={bridge} />

// ✅ trusted content only; restrict navigation; no native bridge to untrusted pages
<WebView
  source={{ uri: 'https://app.example.com/help' }}
  originWhitelist={['https://app.example.com']}
  onShouldStartLoadWithRequest={(r) => r.url.startsWith('https://app.example.com')}
/>
```

## 6. Sensitive data in logs

```ts
// ❌ console.log('token', jwt);  console.log(userWithPii);
// ✅ redact; strip verbose logging from release
if (__DEV__) console.log('login ok', user.id); // id only, dev only
```

## 7. Weak crypto / randomness

```ts
// ❌ Math.random() is NOT cryptographic; md5/sha1 for security; home-rolled XOR
const token = Math.random().toString(36).slice(2);

// ✅ CSPRNG
import 'react-native-get-random-values';
const bytes = new Uint8Array(32);
crypto.getRandomValues(bytes);
const token = Buffer.from(bytes).toString('base64url');
// hashing/encryption: a vetted native crypto module (AES-GCM), not hand-rolled
```

## 8. Insecure platform config

```xml
<!-- ❌ AndroidManifest.xml -->
<application android:allowBackup="true" android:usesCleartextTraffic="true"> ...
<!-- ✅ no cleartext; allowBackup false (or exclude secure storage) -->
<application android:allowBackup="false"> ...
```

```xml
<!-- ❌ ios/Info.plist — ATS disabled -->
<key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict>
<!-- ✅ keep ATS on; narrow, justified per-domain exceptions only -->
```

- In Expo, these come from `app.json`/`app.config` + config plugins — the same
  rules apply to the generated native config.

## 9. Vulnerable / hallucinated dependencies (slopsquatting)

```
- Verify an AI-suggested npm/native package actually exists and is legitimate
  (publisher, weekly downloads, repo, recent releases). Typo-similar · brand-new ·
  negligible downloads → suspect slopsquatting, do not install.
- Pin versions + commit the lockfile. Review native permissions + postinstall scripts.
- Gate on npm audit / Dependabot / Snyk; fix or remove advisories.
```

## Full vibe-guard review checklist

- [ ] No secrets bundled into JS / committed `.env`; privileged calls proxied.
- [ ] Tokens/PII in Keychain/Keystore, not AsyncStorage/MMKV plaintext.
- [ ] HTTPS only; no trust-all TLS; no cleartext `http://`.
- [ ] Deep-link/linking input validated; redirects allowlisted.
- [ ] WebView: no JS on untrusted URLs; no native bridge to remote pages.
- [ ] No tokens/passwords/PII in `console.log`; logging stripped from release.
- [ ] CSPRNG for security values; no `Math.random`/MD5/SHA1/home-rolled crypto.
- [ ] No cleartext traffic / ATS arbitrary loads / unsafe `allowBackup`.
- [ ] Deps real · legitimate · maintained · pinned · advisory-free; scripts reviewed.

## Official references

- React Native security: https://reactnative.dev/docs/security
- OWASP Mobile Top 10: https://owasp.org/www-project-mobile-top-10/
- OWASP MASVS: https://mas.owasp.org/MASVS/
- OWASP Top 10 for LLM Applications 2025: https://genai.owasp.org/llm-top-10/
- CWE Top 25: https://cwe.mitre.org/top25/
- Expo SecureStore: https://docs.expo.dev/versions/latest/sdk/securestore/
- Team baseline: [../../guidance.md](../../guidance.md)
