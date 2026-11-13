type
  ResolveProfileUrlsTaskArg = ref object of QObjectTaskArg
    urls: seq[string]

proc resolveProfileUrlsTask(encoded: string) {.gcsafe, nimcall.} =
  let arg = decode[ResolveProfileUrlsTaskArg](encoded)
  var profiles = newJObject()
  for url in arg.urls:
    try:
      let response = shared_urls.parseSharedUrl(url)
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
