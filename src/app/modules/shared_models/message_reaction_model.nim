import app/modules/shared_models/model_utils
import nimqml, tables, json, strutils, std/strformat

import message_reaction_item

type
  ModelRole {.pure.} = enum
    Emoji = UserRole + 1
    DidIReactWithThisEmoji
    NumberOfReactions
    JsonArrayOfUsersReactedWithThisEmoji

QtObject:
  type
    MessageReactionModel* = ref object of QAbstractListModel
      items: seq[MessageReactionItem]

  proc delete(self: MessageReactionModel)
  proc setup(self: MessageReactionModel)
  proc newMessageReactionModel*(): MessageReactionModel =
    new(result, delete)
    result.setup

  proc `$`*(self: MessageReactionModel): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""
      [{i}]:({$self.items[i]})
      """

  method rowCount(self: MessageReactionModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: MessageReactionModel): Table[int, string] =
    {
      ModelRole.Emoji.int:"emoji",
      ModelRole.DidIReactWithThisEmoji.int:"didIReactWithThisEmoji",
      ModelRole.NumberOfReactions.int:"numberOfReactions",
      ModelRole.JsonArrayOfUsersReactedWithThisEmoji.int: "jsonArrayOfUsersReactedWithThisEmoji"
    }.toTable

  method data(self: MessageReactionModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Emoji:
      result = newQVariant(item.emoji)
    of ModelRole.DidIReactWithThisEmoji:
      result = newQVariant(item.didIReactWithThisEmoji)
    of ModelRole.NumberOfReactions:
      result = newQVariant(item.numberOfReactions)
    of ModelRole.JsonArrayOfUsersReactedWithThisEmoji:
      # Would be good if we could return QVariant of array (seq) here, but it's not supported in our nimqml,
      # because of that we're returning json array as a string.
      result = newQVariant($item.jsonArrayOfUsersReactedWithThisEmoji)

  proc reactionItemWithEmojiExists(self: MessageReactionModel, emoji: string): bool =
    for it in self.items:
      if(it.emoji == emoji):
        return true
    return false

  proc getIndexOfTheItemWithEmoji(self: MessageReactionModel, emoji: string): int =
    for i in 0..<self.items.len:
      if(self.items[i].emoji == emoji):
        return i
    return -1

  proc shouldAddReaction*(self: MessageReactionModel, emoji: string, userPublicKey: string): bool =
    let ind = self.getIndexOfTheItemWithEmoji(emoji)
    if(ind == -1):
      return true
    return self.items[ind].shouldAddReaction(userPublicKey)

  proc getReactionId*(self: MessageReactionModel, emoji: string, userPublicKey: string): string =
    let ind = self.getIndexOfTheItemWithEmoji(emoji)
    if(ind == -1):
      return ""
    return self.items[ind].getReactionId(userPublicKey)

  # This function is used when we optimistically have added a reaction and we received the real reactionID asyncly
  # Returns false if it was not updated. Then we can add the reaction with the normal path
  proc updateReactionId*(self: MessageReactionModel, emoji: string, userPublicKey: string, reactionId: string): bool =
    let ind = self.getIndexOfTheItemWithEmoji(emoji)
    if ind == -1:
      return false

    # Just return the result. No need to fire dataChanged signal, because the reactionId is not used in QML side.
    return self.items[ind].updateReactionId(userPublicKey, reactionId)

  proc addReaction*(self: MessageReactionModel, emoji: string, didIReactWithThisEmoji: bool, userPublicKey: string,
    userDisplayName: string, reactionId: string) =
    if self.reactionItemWithEmojiExists(emoji):
      let ind = self.getIndexOfTheItemWithEmoji(emoji)
      if ind == -1:
        return
      self.items[ind].addReaction(didIReactWithThisEmoji, userPublicKey, userDisplayName, reactionId)
      let index = self.createIndex(ind, 0, nil)
      defer: index.delete
      self.dataChanged(index, index)
    else:
      let parentModelIndex = newQModelIndex()
      defer: parentModelIndex.delete

      var item = initMessageReactionItem(emoji)
      item.addReaction(didIReactWithThisEmoji, userPublicKey, userDisplayName, reactionId)

      self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
      self.items.add(item)
      self.endInsertRows()

  proc removeReaction*(self: MessageReactionModel, emoji: string, reactionId: string, didIRemoveThisReaction: bool) =
    let ind = self.getIndexOfTheItemWithEmoji(emoji)
    if(ind == -1):
      return
    self.items[ind].removeReaction(reactionId, didIRemoveThisReaction)

    if(self.items[ind].numberOfReactions() == 0):
      # remove item if there are no reactions for this emoji id
      let parentModelIndex = newQModelIndex()
      defer: parentModelIndex.delete

      self.beginRemoveRows(parentModelIndex, ind, ind)
      self.items.delete(ind)
      self.endRemoveRows()
    else:
      let index = self.createIndex(ind, 0, nil)
      defer: index.delete
      self.dataChanged(index, index)

  proc delete(self: MessageReactionModel) =
    self.QAbstractListModel.delete

  proc setup(self: MessageReactionModel) =
    self.QAbstractListModel.setup
