# ADR-0009: The curated directory is refreshed by the user, not at login

## Status
- **Accepted**
- **Date**: 2026-11-24

## Why

At login status-go fetched every curated community it did not have from store nodes, whether or not the
Communities Portal was ever opened (status-im/status-app#21528). On Android that cost the status-go process
about 33 MB at settle and kept store queries busy after every login, for a screen many users never open.

## Decision

- **Nothing fetches the directory at login.** status-go only reads what is stored; the app asks for a refresh
  (`wakuext_refreshCuratedCommunities`, status-im/status-go#8084) and follows its started/finished signals.
- **Only the user starts a refresh**: opening the portal (joining a refresh already running instead of starting
  another), pulling the grid, tapping the error pill, or Retry on desktop. No retry when the network returns,
  no periodic refresh.
- **A refresh runs to its end once started**, even if the user leaves the portal, so a slow fetch (tens of
  seconds) is not lost when the user stops waiting. It is stopped when the app goes to the background and
  restarted on return only if that interrupted it.
- **The only sign of a refresh that finished with the portal closed is a plain dot** on the portal entry, set
  when more communities are loaded than when the user left and cleared when the portal opens. No error is
  shown for it; the next open refreshes again and decides the error pill.

## Consequences

- The first portal open of a session is slower to fill: the first fetched card after about 13 s, the whole
  directory after about 45 s on a Samsung S21 FE, against about 5 s on master where the fetch had run at login.
- The status-go fetch cost (peak about +54 MB) moves from login to the first portal open. Leaving the portal no
  longer saves it.
- Entries that store nodes do not have are not asked for again for an hour.
