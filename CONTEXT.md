# Glossary

Terms with a precise meaning in this codebase. Use them exactly; if a new term
conflicts with one below, resolve the conflict here first.

## External intake

**Locked** — the app is running but no account is open: the user must enter
the password or use biometrics before anything handed in from outside is acted
on. There is no separate lock state for an open account.
_Avoid_: app lock, lock screen (as a feature distinct from login)

**Opened File** — a local file the operating system hands to Status through its
"Open with" mechanism, to be shown in a browser Tab. Distinct from Shared
Content, which goes to chats, and from a Download Record, which the browser
fetched itself.
_Avoid_: imported file, shared file

**Shared Content** — text, links or images the operating system hands to
Status through its Share menu, to be sent to chats.
_Avoid_: share intake (as a user-facing term)
