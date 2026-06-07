# MonoSync Development Plan

## Product Direction

MonoSync is an iPhone-first SwiftUI app where Apple Music subscribers can create small personal music spaces, share what they are listening to inside the app, follow friends, leave comments, share playlists, and host mini radio rooms.

The app does not monitor the Apple Music app globally. It only shares playback that happens through this app and only according to the user's visibility setting.

## Apple Music Rules

- Use MusicKit for permission, subscription checks, catalog search, and playback.
- Store only music metadata and Apple Music identifiers, never audio files.
- Followers listen through their own Apple Music subscription.
- Sync listening by sharing `trackId`, `playbackStartedAt`, `positionAtStart`, and playback state.
- Handle unavailable tracks because catalog availability can differ by storefront.
- Apple Music branding should be secondary. The app brand is MonoSync.

## Cost-Safe Realtime Design

- Never write playback position every second.
- Write only playback events: track changed, play, pause, seek, skip, visibility changed.
- Let each client calculate elapsed playback time locally.
- Keep realtime listeners narrow: friend spaces, active room, active comment thread.
- Use pagination for comments and public discovery.
- Treat large public radio rooms as a later scaling milestone.
- Enable Firebase App Check, budget alerts, and strict security rules before beta.

## MVP Milestones

1. SwiftUI shell, bilingual copy, design system, fake data.
2. MusicKit authorization, subscription state, catalog search, and local playback.
3. Space publishing through a realtime store abstraction.
4. Friend/follow visibility, comments, and join listening.
5. Playlist sharing metadata and explicit Apple Music playlist export.
6. Mini radio room with host-controlled queue and listener-side sync.
7. Firebase implementation, rules, App Check, TestFlight beta.

## Testing Reality

- One Apple Music account is enough for most development.
- Use fake users and fake playback states for UI, rules, and sync math.
- A second Apple Music subscriber is useful later for true two-person TestFlight testing.
