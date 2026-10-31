import unittest

import app/core/eventemitter
import app/modules/main/browser_section/bookmark/controller as bookmark_controller
import app/modules/main/browser_section/bookmark/io_interface
import app_service/service/bookmarks/service as bookmark_service

type MockDelegate = ref object of io_interface.AccessInterface
  stored: seq[tuple[url, name, imageUrl: string]]
  deleted: seq[string]
  updated: seq[tuple[oldUrl, newUrl, newName, imageUrl: string]]

method onBoomarkStored*(self: MockDelegate, url, name, imageUrl: string) =
  self.stored.add (url, name, imageUrl)

method onBookmarkDeleted*(self: MockDelegate, url: string) =
  self.deleted.add url

method onBookmarkUpdated*(self: MockDelegate, oldUrl, newUrl, newName, newImageUrl: string) =
  self.updated.add (oldUrl, newUrl, newName, newImageUrl)

proc sampleBookmark(url, name, imageUrl: string): bookmark_service.BookmarkDto =
  bookmark_service.BookmarkDto(url: url, name: name, imageUrl: imageUrl)

suite "browser bookmark controller — bookmark service events":
  setup:
    let events = createEventEmitter()
    let delegate = MockDelegate()
    let ctrl = bookmark_controller.newController(delegate, events, nil)
    ctrl.init()

  test "bookmarkAdded forwards url, name and image to the delegate":
    events.emit(bookmark_service.SIGNAL_BOOKMARK_ADDED,
      bookmark_service.BookmarkArgs(
        bookmark: sampleBookmark("https://example.com", "Example", "https://img/icon.png")))

    check delegate.stored == @[
      (url: "https://example.com", name: "Example", imageUrl: "https://img/icon.png")]

  test "bookmarkRemoved forwards the url to the delegate":
    events.emit(bookmark_service.SIGNAL_BOOKMARK_REMOVED,
      bookmark_service.BookmarkRemovedArgs(url: "https://example.com/to-remove"))

    check delegate.deleted == @["https://example.com/to-remove"]

  test "bookmarkUpdated forwards fields from the dto to the delegate":
    events.emit(bookmark_service.SIGNAL_BOOKMARK_UPDATED,
      bookmark_service.BookmarkArgs(
        bookmark: sampleBookmark("https://new.example", "Renamed", "https://img/new.png")))

    check delegate.updated == @[
      (oldUrl: "https://new.example", newUrl: "https://new.example",
       newName: "Renamed", imageUrl: "https://img/new.png")]
