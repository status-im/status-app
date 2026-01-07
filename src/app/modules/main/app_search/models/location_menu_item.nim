
import json, std/strformat
import base_item, location_menu_sub_model, location_menu_sub_item

type
  Item* = ref object of BaseItem
    subItems: SubModel

proc initItem*(value, text, image, icon: string, iconColor: string = ""): Item =
  result = Item()
  result.setup(value, text, image, icon, iconColor)
  result.subItems = newSubModel()

proc subItems*(self: Item): SubModel {.inline.} =
  self.subItems

proc `$`*(self: Item): string =
  result = fmt"""SearchMenuItem(
    value: {self.value},
    title: {self.text},
    imageSource: {self.image},
    iconName: {self.icon},
    iconColor: {self.iconColor},
    subItems:[
      {$self.subItems}
    ]"""

proc toJsonNode*(self: Item): JsonNode =
  result = %* {
    "value": self.value,
    "title": self.text,
    "imageSource": self.image,
    "iconName": self.icon,
    "iconColor": self.iconColor,
  }

proc setSubItems*(self: Item, subItems: seq[SubItem]) =
  self.subItems.setItems(subItems)

proc getSubItemForValue*(self: Item, value: string): SubItem =
  self.subItems.getItemForValue(value)
