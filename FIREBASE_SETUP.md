# Firebase 연동 — 내가 직접 해야 하는 설정

코드는 모두 준비됐고, `#if canImport(Firebase...)` 가드로 감싸 둬서
SDK를 붙이기 전에도 빌드는 정상입니다(지금은 InMemory + 샘플 데이터로 동작).
아래 4단계를 끝내면 Firebase 경로가 자동으로 켜집니다.

## 1. Firebase 프로젝트 만들기 + plist 받기
1. https://console.firebase.google.com 에서 새 프로젝트 생성
2. **iOS 앱 추가** → Bundle ID 입력 (Xcode > MonoSync 타깃 > General > Bundle Identifier 와 동일하게)
3. `GoogleService-Info.plist` 다운로드
4. 그 파일을 **Xcode의 MonoSync 폴더에 드래그**해서 추가
   - "Copy items if needed" 체크, Target = MonoSync 체크
   - (코드가 `Bundle.main.path(forResource: "GoogleService-Info")`로 자동 인식합니다)

## 2. Firebase SDK 추가 (Swift Package Manager)
Xcode에서:
1. **File > Add Package Dependencies…**
2. 주소 입력: `https://github.com/firebase/firebase-ios-sdk`
3. Dependency Rule: Up to Next Major (최신 버전)
4. 추가할 제품(라이브러리) 선택 — **반드시 아래 3개 체크**:
   - `FirebaseAuth`
   - `FirebaseFirestore`
   - `FirebaseCore` (보통 자동 포함)
5. Add Package → 해석(resolve)까지 기다리기

> 이걸 추가하면 `canImport(FirebaseAuth)` / `canImport(FirebaseFirestore)` 가
> 참이 되어, 이미 작성된 Firebase 코드가 컴파일·동작합니다.

## 3. Sign in with Apple 켜기
1. **Xcode** > MonoSync 타깃 > **Signing & Capabilities** > `+ Capability` > **Sign in with Apple** 추가
2. **Firebase 콘솔** > Authentication > Sign-in method > **Apple** 사용 설정(Enable) → 저장
3. (실기기 필요) Apple 로그인은 시뮬레이터에서도 되지만 Apple ID 로그인이 되어 있어야 합니다.

## 4. Firestore 만들기 + 보안 규칙
1. Firebase 콘솔 > **Firestore Database** > 데이터베이스 만들기 (프로덕션 모드)
2. **규칙(Rules)** 탭 → 이 저장소의 `firestore.rules` 내용을 붙여넣고 **게시(Publish)**

---

## 끝나면 동작하는 것
- 설정(Me) 화면에서 **Apple로 로그인** → uid 발급, 프로필 자동 생성
- **내 초대 링크 공유**(ShareLink) → 친구가 `monosync://add/<uid>` 링크를 탭하면 친구 추가
- 재생을 시작하면 내 상태가 `spaces/{uid}`에 기록되고,
  친구들 화면에 그들의 now-playing이 실시간으로 뜸 → 탭하면 같이 듣기

## 아직 안 만든 것 (다음 단계 후보)
- QR 코드로 친구 추가 (현재는 링크 공유/탭만)
- 친구 요청 수락(현재는 단방향 팔로우)
- 딥링크용 URL Scheme 등록: Xcode 타깃 > Info > URL Types 에 `monosync` 추가하면
  카톡 등 외부 앱에서 링크 탭 시 앱이 열립니다. (앱 내 공유→탭 흐름엔 없어도 됨)

## 참고: 설정 후 컴파일 에러가 나면
Firebase SDK 버전에 따라 일부 API 시그니처(예: `OAuthProvider.appleCredential`)가
다를 수 있습니다. 에러가 나면 메시지를 알려주세요. 바로 맞춰 드리겠습니다.
