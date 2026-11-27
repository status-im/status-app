{.used.}

import contacts

export contacts

type
  ContactDetails* = object
    defaultDisplayName*: string
    optionalName*: string
    icon*: string
    isCurrentUser*: bool
    colorId*: int
    dto*: ContactsDto
    ## false for a placeholder the client made for a key status-go has not
    ## sent: it carries only the key's identity, no profile
    fromStatusGo*: bool
