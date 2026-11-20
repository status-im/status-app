type
  ResolveProfileUrlsTaskArg = ref object of QObjectTaskArg
    urls: seq[string]

proc resolveProfileUrlsTask(encoded: string) {.gcsafe, nimcall.} =
  let arg = decode[ResolveProfileUrlsTaskArg](encoded)
  var profiles = newJObject()
  for url in arg.urls:
    try:
      var canonicalUrl = url
      for prefix in ["status-app://", "http://status.app/"]:
        if url.startsWith(prefix):
          canonicalUrl = "https://status.app/" & url[prefix.len .. ^1]
          break
      let response = shared_urls.parseSharedUrl(canonicalUrl)
      var contact = response.result.toUrlDataDto().contact
      if isCompressedPubKey(contact.publicKey):
        contact.publicKey = status_accounts.decompressPk(contact.publicKey).result
      profiles[url] = if contact.publicKey.len > 0:
        %* {"publicKey": contact.publicKey, "displayName": contact.displayName}
      else:
        newJNull()
    except CatchableError:
      # The UI leaves unavailable links as URLs. Allow a future request to retry.
      discard
  arg.finish($profiles)
