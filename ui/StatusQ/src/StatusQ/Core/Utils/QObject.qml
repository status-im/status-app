pragma ComponentBehavior: Bound

import QtQml

// Simple utility allowing to declare children within QtObject without having
// to assigne them to properties, like `QtObject { ListModel {} }`
QtObject {
    default property list<QtObject> children
}
