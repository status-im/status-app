proc setupWcEvents*(self: Controller) =
  self.events.on(connector_service.SIGNAL_WC_SESSION_PROPOSAL) do(e: Args):
    try:
      let params = WCSessionProposalSignal(e)
      self.wcSessionProposal(params.requestId, params.uri, params.proposal)
    except Exception as ex:
      error "error processing SIGNAL_WC_SESSION_PROPOSAL", error=ex.msg, exceptionName=ex.name

  self.events.on(connector_service.SIGNAL_WC_SESSION_REQUEST) do(e: Args):
    try:
      let params = WCSessionRequestSignal(e)
      self.wcSessionRequest(params.topic, $params.requestId, params.requestJson)
    except Exception as ex:
      error "error processing SIGNAL_WC_SESSION_REQUEST", error=ex.msg, exceptionName=ex.name

  self.events.on(connector_service.SIGNAL_WC_SESSION_DELETE) do(e: Args):
    try:
      let params = WCSessionDeleteSignal(e)
      self.wcSessionDelete(params.topic, params.dappUrl)
    except Exception as ex:
      error "error processing SIGNAL_WC_SESSION_DELETE", error=ex.msg, exceptionName=ex.name

  self.events.on(connector_service.SIGNAL_WC_PAIR_RESULT) do(e: Args):
    try:
      let params = connector_service.WCAsyncResultArgs(e)
      let payload = params.payload.parseJson
      self.wcPairWalletConnectDone(
        payload{"ok"}.getBool(false),
        payload{"error"}.getStr("")
      )
    except Exception as ex:
      error "error processing SIGNAL_WC_PAIR_RESULT", error=ex.msg, exceptionName=ex.name

  self.events.on(connector_service.SIGNAL_WC_APPROVE_SESSION_RESULT) do(e: Args):
    try:
      let payload = connector_service.WCAsyncResultArgs(e).payload.parseJson
      self.wcApproveSessionDone(
        payload{"proposalId"}.getStr(""),
        payload{"sessionJson"}.getStr(""),
        payload{"error"}.getStr("")
      )
    except Exception as ex:
      error "error processing SIGNAL_WC_APPROVE_SESSION_RESULT", error=ex.msg, exceptionName=ex.name

  self.events.on(connector_service.SIGNAL_WC_REJECT_SESSION_RESULT) do(e: Args):
    try:
      let payload = connector_service.WCAsyncResultArgs(e).payload.parseJson
      self.wcRejectSessionDone(
        payload{"proposalId"}.getStr(""),
        payload{"error"}.getStr("")
      )
    except Exception as ex:
      error "error processing SIGNAL_WC_REJECT_SESSION_RESULT", error=ex.msg, exceptionName=ex.name

  self.events.on(connector_service.SIGNAL_WC_SESSION_REQUEST_ANSWER_RESULT) do(e: Args):
    try:
      let params = connector_service.WCAsyncResultArgs(e)
      let payload = params.payload.parseJson
      let sessionRequestId = payload{"sessionRequestId"}.getStr("")
      self.wcSessionRequestAnswerDone(
        payload{"topic"}.getStr(""),
        sessionRequestId,
        payload{"accept"}.getBool(false),
        payload{"error"}.getStr("")
      )
    except Exception as ex:
      error "error processing SIGNAL_WC_SESSION_REQUEST_ANSWER_RESULT", error=ex.msg, exceptionName=ex.name

  self.events.on(connector_service.SIGNAL_WC_EMIT_EVENT_RESULT) do(e: Args):
    try:
      let payload = connector_service.WCAsyncResultArgs(e).payload.parseJson
      self.wcEmitSessionEventDone(
        payload{"topic"}.getStr(""),
        payload{"name"}.getStr(""),
        payload{"error"}.getStr("")
      )
    except Exception as ex:
      error "error processing SIGNAL_WC_EMIT_EVENT_RESULT", error=ex.msg, exceptionName=ex.name

  self.events.on(connector_service.SIGNAL_WC_GET_ACTIVE_SESSIONS_RESULT) do(e: Args):
    try:
      let params = connector_service.WCAsyncResultArgs(e)
      let payload = params.payload.parseJson
      if params.requestId == self.latestGetActiveSessionsRequestId:
        self.wcGetActiveSessionsDone(
          payload{"sessionsJson"}.getStr("[]"),
          payload{"error"}.getStr("")
        )
    except Exception as ex:
      error "error processing SIGNAL_WC_GET_ACTIVE_SESSIONS_RESULT", error=ex.msg, exceptionName=ex.name

  self.events.on(connector_service.SIGNAL_WC_DISCONNECT_SESSION_RESULT) do(e: Args):
    try:
      let params = connector_service.WCAsyncResultArgs(e)
      let requestId = params.requestId
      defer: self.pendingDisconnectUrls.del(requestId)
      let payload = params.payload.parseJson
      let topic = payload{"topic"}.getStr("")
      let errorText = payload{"error"}.getStr("")
      let dappUrl = self.pendingDisconnectUrls.getOrDefault(requestId, "")
      self.wcDisconnectSessionDone(
        topic,
        dappUrl,
        errorText
      )
    except Exception as ex:
      error "error processing SIGNAL_WC_DISCONNECT_SESSION_RESULT", error=ex.msg, exceptionName=ex.name
