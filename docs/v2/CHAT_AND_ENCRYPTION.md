# Pokatuha V2 — Chat Encryption

Status: APPROVED
Depends on: ARCHITECTURE_V2.md, CHAT_P2P_QUEUE.md

---

## 1. Threat model

- Server must NOT read message content
- Relay must NOT read message content
- Offline peer must store encrypted payload only
- Group key must be revocable when member leaves

---

## 2. Algorithms

| Layer | Algorithm | Library hint |
|-------|-----------|--------------|
| Key exchange | X25519 | `cryptography` or `libsodium` |
| Ratchet | Double Ratchet (Signal protocol) | Custom or `libsignal` |
| Symmetric | AES-256-GCM | Dart `encrypt` + `pointycastle` |
| Hash | SHA-256 | Dart `crypto` |
| Random | `SecureRandom` | `pointycastle` |

---

## 3. Key hierarchy

### Identity key
- Generated once on registration
- X25519 key pair
- Stored in encrypted local storage (Android Keystore / iOS Keychain)

### Group key
- Generated when activity/chat created
- Distributed to participants via X25519 ECDH
- Rotated when member leaves

### Message key
- Derived from Double Ratchet chain
- One-time per message
- Never reused

---

## 4. Group key distribution flow

1. Creator generates group key `GK`
2. For each participant: encrypt `GK` with participant's public identity key
3. Send encrypted key via P2P (not via FCM)
4. Participant decrypts with private identity key
5. All subsequent messages encrypted with `GK` via Double Ratchet

---

## 5. Message encryption flow

1. Derive message key from ratchet chain
2. Encrypt payload: `AES-256-GCM(plaintext, message_key, nonce)`
3. Attach header: `group_id`, `sender_id`, `chain_index`
4. Send encrypted blob via P2P

---

## 6. Storage rules

| Data | Storage | Encrypted |
|------|---------|-----------|
| Identity private key | Android Keystore / iOS Keychain | Yes (by OS) |
| Group key | Sembast (local DB) | Yes (AES-256, device key) |
| Messages | Sembast | Yes (group key) |
| Outbox | Sembast | Yes (group key) |
| Attachments | Filesystem | Optional (group key) |

---

## 7. Dart implementation hints

### Key generation
```dart
import 'package:cryptography/cryptography.dart';

final algorithm = X25519();
final keyPair = await algorithm.newKeyPair();
final publicKey = await keyPair.extractPublicKey();
final privateKey = await keyPair.extractPrivateKey();
```

### ECDH shared secret
```dart
final sharedSecret = await algorithm.sharedSecret(
  keyPair: myKeyPair,
  remotePublicKey: peerPublicKey,
);
```

### AES-GCM encryption
```dart
import 'package:encrypt/encrypt.dart' as encrypt;

final key = encrypt.Key.fromBase64(base64Key);
final iv = encrypt.IV.fromSecureRandom(12);
final encrypter = encrypt.Encrypter(
  encrypt.AES(key, mode: encrypt.AESMode.gcm),
);
final encrypted = encrypter.encrypt(plaintext, iv: iv);
```

### Secure storage
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const storage = FlutterSecureStorage();
await storage.write(key: 'identity_private', value: base64Private);
```

---

## 8. Constraints for AI

- Do NOT use Firebase to store keys
- Do NOT send private keys over network
- Do NOT reuse nonces
- Rotate group key on member join/leave
- Use `SecureRandom`, never `Random()`
