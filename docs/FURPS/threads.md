# Threads ([#21090](https://github.com/status-im/status-app/issues/21090))

## Overview

Threads are a first-class messaging feature that enables focused sub-conversations from any message across Communities, Group Chats, and Direct Messages. They maintain clear relationships to parent messages while keeping the main conversation readable and organized.


## Functionality

### Thread Creation & Management
- **Reply to any message in a thread**: Users can initiate a thread by replying to any message in the main conversation
- **Thread indicators**: Parent messages display a visual indicator (badge/counter) showing the number of replies
- **Multi-thread support**: A single parent message can have unlimited replies organized within a single thread
- **Thread scope**: Threads work consistently across:
  - Community channels
  - Group chats
  - Direct messages (1:1 and group DMs)

### Thread Participation
- **Reply composition**: Users can write and send replies within a thread without affecting the main conversation
- **View thread replies**: All thread responses are visible in a dedicated thread view panel
- **Parent message access**: Users can always see the parent message in the thread context
- **Thread persistence**: Threads persist across app sessions and device restarts
- **Thread history**: Full conversation history is maintained and accessible

### Thread Navigation
- **Open thread from parent**: Users can click/tap on a parent message to open the thread panel
- **Navigate back**: Clear navigation path to return to the main conversation
- **Thread identification**: Clear visual connection between thread view and parent message (quoted/referenced parent)
- **Seamless context switching**: Navigate between main chat and threads without losing position or state
- **Thread list/discovery**: Users can view a list of all active/past threads in a channel or conversation

### Notifications
- **Thread reply notifications**: Users receive notifications when someone replies to a thread they participate in
- **Smart notification defaults**: 
  - Notify when user is @mentioned in thread
  - Notify on direct replies to user's message
- **Notification control**: Users can mute/unmute thread notifications
- **Notification content**: Thread notifications show thread preview and reply preview

### Cross-Chat Integration
- **Consistent behavior**: Threading works identically across communities, group chats, and DMs
- **Permission inheritance**: Thread permissions inherit from parent chat permissions
- **Moderation support**: Moderators can delete/edit thread messages with same rules as main chat
- **Community admin controls**: Community admins can enable a setting to restrict thread creation to admins only (similar to pinning message restrictions)


## Usability

### User Interface
- **Clear visual hierarchy**: Thread replies are visually distinct from main conversation (indentation, panel layout)
- **Intuitive interaction**: Replying to a message naturally creates or adds to a thread (obvious affordance)
- **Read status**: Users can see which thread replies they have and haven't read

### Learning & Discoverability
- **Onboarding**: First-time thread users see helpful hints/tooltips on thread affordances
- **Consistency**: Thread UX mirrors established patterns from other platforms (Discord, Slack)
- **Clear terminology**: Consistent language (thread, reply, parent message) throughout UI

### Navigation & Orientation
- **Breadcrumb/context**: Thread panel clearly shows which message started the thread
- **Quick reply**: Easy access to reply box when viewing a thread
- **Back navigation**: Clear visual button/gesture to return to main chat
- **Position memory**: App remembers user's scroll position in main chat when returning from thread

## Reliability

- **Atomic operations**: Thread operations (post, edit, delete) are atomic (all-or-nothing)
- **Message delivery guarantee**: Replies are persisted before delivery confirmation
- **Sync indication**: UI clearly indicates which replies are pending delivery
- **Error recovery**: Failed deliveries can be retried with user awareness

## Performance

### Response Time
- **Thread open**: Thread panel opens and displays within <500ms for chats with <1000 messages
- **Reply send**: Reply submission completes (or queues) within <1s
- **Infinite scroll**: Loading previous thread replies has <200ms perceived latency
- **UI responsiveness**: Main chat remains responsive while thread is open in side panel

### Memory & Resource Usage
- **Lazy loading**: Thread replies load incrementally (not all at once)
- **Cache efficiency**: Thread data cached per conversation to avoid redundant fetches
- **Image/media optimization**: Thread media previews are optimized for size
- **Background sync**: Thread updates don't block UI rendering

### Scalability
- **Large threads**: App remains functional with threads containing 1000+ replies
- **Many threads**: Channels with hundreds of threads perform adequately

### Battery & Data
- **Battery efficiency**: Thread operations use reasonable power (no continuous polling)

## Supportability

### Code Maintainability
- **Layering**: Thread logic properly separated across QML UI, Nim middleware, and status-go backend
- **Module isolation**: Thread feature isolated from core messaging to minimize side effects
- **Clear interfaces**: Well-defined APIs between layers for thread operations

### Testing Coverage
- **Unit tests**: Thread logic (state machine, data validation) has unit test coverage
- **Integration tests**: Thread operations tested across QML-Nim-backend layers
- **E2E tests**: User workflows (create thread, reply, open, navigate) covered by E2E tests
- **Edge cases**: Offline, network errors, concurrent operations tested

### Debugging & Monitoring
- **Debug logs**: Thread operations logged with sufficient detail for troubleshooting
- **Error reporting**: Thread-related errors captured and reported with context
- **Crash reports**: Thread-related crashes include full stack traces

### Upgradability
- **Data migration**: Upgrade path for adding threads to existing databases
- **Backwards compatibility**: Older app versions can still read main chat if threads unavailable
- **Feature flags**: Thread feature can be toggled on/off for rollout control

### Documentation
- **Architecture docs**: Thread implementation overview in docs/architecture.md
- **API documentation**: Thread endpoints/signals documented for developers
- **User documentation**: Help docs explain thread creation, navigation, and notifications


## Success Criteria

- ✅ Users can create threads from any message in communities, group chats, and DMs
- ✅ Thread replies are clearly distinguished from main conversation
- ✅ Navigation between threads and main chat is seamless and intuitive
- ✅ Thread indicators show accurate reply counts and update in real-time
- ✅ Notifications work reliably for thread activity
- ✅ Feature performs well with large threads (100+ replies)
- ✅ Feature works reliably across network disruptions and app restarts
- ✅ Code is maintainable and well-tested
- ✅ Community admins can restrict thread creation to admins only

