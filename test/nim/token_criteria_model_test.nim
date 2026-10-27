import unittest, json, tables

import nimqml

import app_service/common/types
import app_service/service/community/dto/community
import app/modules/shared_models/[token_criteria_model, token_permission_item]

proc roleForName(model: TokenCriteriaModel, name: string): int =
  for role, roleName in model.roleNames().pairs:
    if roleName == name:
      return role
  return -1

proc roleData(model: TokenCriteriaModel, row: int, roleName: string): QVariant =
  let role = roleForName(model, roleName)
  check role != -1
  if role == -1:
    return newQVariant()
  return model.data(model.createIndex(row, 0, nil), role)

suite "token criteria model":
  test "exposes the criterion's own name and decimals":
    let permission = %*{
      "id": "p1",
      "type": 1,
      "token_criteria": [{
        "type": 1,
        "symbol": "SNT",
        "name": "Status",
        "decimals": 18,
        "amountInWei": "10000000000000000000",
        "contract_addresses": {
          "1": "0x744D70FDBE2BA4CF95131626614A1763DF805B9E",
        },
      }],
    }

    let item = buildTokenPermissionItem(permission.toCommunityTokenPermissionDto, @[])
    let criteria = item.getTokenCriteria()

    check criteria.rowCount(nil) == 1
    check roleData(criteria, 0, "key").stringVal == "1-0x744d70fdbe2ba4cf95131626614a1763df805b9e"
    check roleData(criteria, 0, "symbol").stringVal == "SNT"
    check roleData(criteria, 0, "name").stringVal == "Status"
    check roleData(criteria, 0, "decimals").intVal == 18
    check roleData(criteria, 0, "amount").stringVal == "10000000000000000000"

suite "unresolved token key criterion":
  test "an asset keeps its own symbol, name and decimals":
    var criteria = (%*{
      "type": 1, "key": "1-0x744d70fdbe2ba4cf95131626614a1763df805b9e",
      "symbol": "SNT", "name": "Status", "decimals": 18, "amount": "10000000000000000000",
    }).toTokenCriteriaDto

    check criteria.applyUnresolvedTokenKey("1-0x744d70fdbe2ba4cf95131626614a1763df805b9e")
    check criteria.`type` == TokenType.ERC20
    check criteria.symbol == "SNT"
    check criteria.name == "Status"
    check criteria.decimals == 18
    check criteria.contractAddresses == {1: "0x744d70fdbe2ba4cf95131626614a1763df805b9e"}.toTable

  test "a collectible is identified by its contract only":
    var criteria = (%*{"type": 2, "symbol": "KITTY", "name": "Kitty", "amount": "1"}).toTokenCriteriaDto

    check criteria.applyUnresolvedTokenKey("10-0xabc")
    check criteria.`type` == TokenType.ERC721
    check criteria.symbol == ""
    check criteria.name == ""
    check criteria.decimals == 0
    check criteria.contractAddresses == {10: "0xabc"}.toTable

  test "an unparsable key is rejected":
    var criteria = (%*{"type": 1, "symbol": "SNT"}).toTokenCriteriaDto
    check not criteria.applyUnresolvedTokenKey("SNT")

suite "resolved token key criterion":
  proc legacyCriterion(): TokenCriteriaDto =
    (%*{
      "type": 1, "key": "1-0x744d70fdbe2ba4cf95131626614a1763df805b9e",
      "symbol": "", "name": "", "decimals": 0, "amount": "10000000000000000000",
    }).toTokenCriteriaDto

  test "fills a legacy criterion with the resolved token's data":
    var criteria = legacyCriterion()
    criteria.applyResolvedTokenData(name = "Status", symbol = "SNT", decimals = 18)

    check criteria.symbol == "SNT"
    check criteria.name == "Status"
    check criteria.decimals == 18

  test "the resolved token's name and symbol win":
    var criteria = (%*{
      "type": 1, "key": "1-0x744d70fdbe2ba4cf95131626614a1763df805b9e",
      "symbol": "OLD", "name": "Old", "decimals": 18, "amount": "10000000000000000000",
    }).toTokenCriteriaDto
    criteria.applyResolvedTokenData(name = "Status", symbol = "SNT", decimals = 18)

    check criteria.symbol == "SNT"
    check criteria.name == "Status"
    check criteria.decimals == 18

  test "an empty resolved name or symbol doesn't blank the criterion's":
    var criteria = (%*{
      "type": 1, "key": "1-0x744d70fdbe2ba4cf95131626614a1763df805b9e",
      "symbol": "SNT", "name": "Status", "decimals": 18, "amount": "10000000000000000000",
    }).toTokenCriteriaDto
    criteria.applyResolvedTokenData(name = "", symbol = "", decimals = 18)

    check criteria.symbol == "SNT"
    check criteria.name == "Status"

  test "the criterion's decimals stay, since its amount was scaled with them":
    var criteria = (%*{
      "type": 1, "key": "1-0x744d70fdbe2ba4cf95131626614a1763df805b9e",
      "symbol": "SNT", "name": "Status", "decimals": 6, "amount": "10000000",
    }).toTokenCriteriaDto
    criteria.applyResolvedTokenData(name = "Status", symbol = "SNT", decimals = 18)

    check criteria.decimals == 6
