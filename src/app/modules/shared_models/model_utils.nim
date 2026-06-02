import std/macros

template guardModelDataIndex*(index: untyped, count: int) =
  if not index.isValid:
    return
  if index.row < 0 or index.row >= count:
    return

template guardModelSetDataIndex*(index: untyped, row: int, count: int) =
  if not index.isValid:
    return false
  if row < 0 or row >= count:
    return false

template guardModelDataRole*[T](role: int, _: typedesc[T]) =
  if role < ord(low(T)) or role > ord(high(T)):
    return

template guardModelData*[T](index: untyped, count: int, role: int, _: typedesc[T]) =
  guardModelDataIndex(index, count)
  guardModelDataRole(role, T)

template guardModelSetDataRole*[T](role: int, _: typedesc[T]) =
  if role < ord(low(T)) or role > ord(high(T)):
    return false

# Macro that simplifies checking and updating values in a model
# IMPORTANT:
  # The model's items need to be in a `seq` called `items`
  # A `seq[int]` named `roles` needs to exist
  # The index of the item being checked must be named `ind`
macro updateRole*(propertyName: untyped, roleName: untyped): untyped =
  quote do:
    if self.items[ind].`propertyName` != `propertyName`:
      self.items[ind].`propertyName` = `propertyName`
      roles.add(ModelRole.`roleName`.int)

# Same thing as updateRole where you have a value to set that is not the same **exact** name as the propertyName
# Eg: updateRoleWithValue(name, Name, item.name)
macro updateRoleWithValue*(propertyName: untyped, roleName: untyped, value: untyped): untyped =
  quote do:
    if self.items[ind].`propertyName` != `value`:
      self.items[ind].`propertyName` = `value`
      roles.add(ModelRole.`roleName`.int)

# Like updateRole but skip the assignment when the incoming string value is
# empty AND the existing value is non-empty. Use for fields that are
# deterministic and cannot change once set
macro updateRolePreserveOnEmpty*(propertyName: untyped, roleName: untyped): untyped =
  quote do:
    if `propertyName`.len > 0 and self.items[ind].`propertyName` != `propertyName`:
      self.items[ind].`propertyName` = `propertyName`
      roles.add(ModelRole.`roleName`.int)