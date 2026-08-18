import std/[algorithm, locks, os, strutils, tables, times]

const
  DefaultLogFamilyMaxFiles* = 10
  MaxLogFamilyMaxFiles* = 50

  # Only Android runs status-go in a separate long-lived process (StatusGoService)
  StatusGoRunsOutOfProcess* = defined(android)

type
  LogCleanupMode* = enum
    ClearClosedLogs,
    RemoveExpiredLogs

  LogCleanupResult* = object
    deletedCount*: int
    failedCount*: int
    skippedCount*: int

  LogMigrationResult* = object
    movedCount*: int
    failedCount*: int
    skippedCount*: int

  LogFileEntry = object
    path: string
    lastWriteTime: Time

var cleanupLock: Lock
var logCleanupStartedAt = getTime()

initLock(cleanupLock)

proc initializeLogCleanup*(processStartedAt: Time) =
  logCleanupStartedAt = processStartedAt

proc logCleanupProcessStartedAt*(): Time =
  logCleanupStartedAt

proc isDataLogFile(path: string): bool =
  let lower = path.toLowerAscii()
  lower.endsWith(".log") or lower.endsWith(".log.gz")

func isDigits(s: string, first, last: int): bool =
  for i in first .. last:
    if s[i] notin {'0'..'9'}:
      return false
  true

# Check if a string is a valid session timestamp in the format "YYYY-MM-DDTHH-MM-SS" followed by "Z" or ".mmm"
func isSessionTimestamp(s: string): bool =
  if s.len != 20 and s.len != 23:
    return false
  if not (s.isDigits(0, 3) and s[4] == '-' and s.isDigits(5, 6) and s[7] == '-' and
      s.isDigits(8, 9) and s[10] == 'T' and s.isDigits(11, 12) and s[13] == '-' and
      s.isDigits(14, 15) and s[16] == '-' and s.isDigits(17, 18)):
    return false
  if s.len == 20:
    return s[19] == 'Z'
  return s[19] == '.' and s.isDigits(20, 22)

# Splits a log file name into its stem and extension (".log" or ".log.gz")
func splitLogName(fileName: string): tuple[stem, ext: string] =
  var name = extractFilename(fileName)
  var ext = ""
  if name.toLowerAscii().endsWith(".gz"):
    ext = name[^3..^1]
    name.setLen(name.len - 3)
  if name.toLowerAscii().endsWith(".log"):
    ext = name[^4..^1] & ext
    name.setLen(name.len - 4)
  (name, ext)

func isAppLogStem(stem: string): bool =
  stem.len == 19 and stem.startsWith("app_") and stem[12] == '_' and
    stem.isDigits(4, 11) and stem.isDigits(13, 18)

func sessionTimestampSuffixLen(stem: string): int =
  for tsLen in [20, 23]:
    if stem.len > tsLen + 1 and stem[stem.len - tsLen - 1] == '-' and
        isSessionTimestamp(stem[stem.len - tsLen .. ^1]):
      return tsLen
  return 0

# Detemines the log family of a log file (pre_login, 0x12..cdef, api, app...  anything else is its own single-file family)
proc logFamily*(fileName: string): string =
  let (stem, _) = splitLogName(fileName)
  let tsLen = sessionTimestampSuffixLen(stem)
  if tsLen > 0:
    return stem[0 .. stem.len - tsLen - 2]
  if isAppLogStem(stem):
    return "app"
  return stem

# Canonical names (pre_login.log, 0x….log, keycard.log, ...) are the live logs, differ from timestamped archives
# and per-start app_* client logs.
proc isCanonicalLogName*(fileName: string): bool =
  let (stem, _) = splitLogName(fileName)
  sessionTimestampSuffixLen(stem) == 0 and not isAppLogStem(stem)

func isStatusGoOwnedLogStem(stem: string): bool =
  # pre_login/api/geth plus the per-profile truncated keyUID ("0x12..3456")
  stem in ["pre_login", "api", "geth"] or
    (stem.startsWith("0x") and stem.contains(".."))

# Canonical log files written by status-go. When status-go runs in a separate long-lived process (Android),
# these can be actively written even though their mtime predates this (UI) process' start, so the mtime guard is not a valid
# liveness test for them. All other log files are owned by this process, where the mtime guard is sufficient.
proc isStatusGoOwnedCanonicalLogName*(fileName: string): bool =
  let (stem, _) = splitLogName(fileName)
  sessionTimestampSuffixLen(stem) == 0 and isStatusGoOwnedLogStem(stem)

proc collectLogFiles(directory: string, recursive: bool,
    entries: var seq[LogFileEntry], result: var LogCleanupResult) =
  if not dirExists(directory):
    return

  try:
    for kind, path in walkDir(directory):
      case kind
      of pcFile:
        if isDataLogFile(path):
          try:
            let fileInfo = getFileInfo(path, followSymlink = false)
            if fileInfo.kind == pcFile:
              entries.add(LogFileEntry(path: path, lastWriteTime: fileInfo.lastWriteTime))
            else:
              inc result.skippedCount
          except OSError:
            inc result.failedCount
      of pcDir:
        if recursive:
          collectLogFiles(path, recursive, entries, result)
      else:
        discard
  except OSError:
    inc result.failedCount

proc removeLogFile(path: string, result: var LogCleanupResult) =
  try:
    if tryRemoveFile(path):
      inc result.deletedCount
    elif fileExists(path):
      inc result.failedCount
  except OSError:
    if fileExists(path):
      inc result.failedCount

# Clears log files from the logs dir and data dir, based on the mode and maxFilesPerFamily.
# Files written since process start are always kept and don't count against the cap;
# when status-go runs out of process (Android), its canonical (live-name) files are
# kept too, since their mtime says nothing about whether they are still in use.
proc cleanupLogFiles*(logsDir, dataDir: string, processStartedAt: Time, mode: LogCleanupMode,
  maxFilesPerFamily: int = DefaultLogFamilyMaxFiles,
  protectStatusGoCanonical: bool = StatusGoRunsOutOfProcess): LogCleanupResult =
  acquire(cleanupLock)
  defer:
    release(cleanupLock)

  let cap = clamp(maxFilesPerFamily, 1, MaxLogFamilyMaxFiles)

  var entries: seq[LogFileEntry]
  collectLogFiles(logsDir, recursive = false, entries, result)
  collectLogFiles(dataDir, recursive = true, entries, result)

  var closed: seq[LogFileEntry]
  for entry in entries:
    if entry.lastWriteTime >= processStartedAt or
        (protectStatusGoCanonical and isStatusGoOwnedCanonicalLogName(entry.path)):
      inc result.skippedCount
    else:
      closed.add(entry)

  if mode == ClearClosedLogs:
    for entry in closed:
      removeLogFile(entry.path, result)
    return

  closed.sort(proc(a, b: LogFileEntry): int =
    cmp(b.lastWriteTime, a.lastWriteTime))

  var familyCounts = initCountTable[string]()
  for entry in closed:
    let family = logFamily(entry.path)
    if familyCounts.getOrDefault(family) < cap:
      familyCounts.inc(family)
      inc result.skippedCount
    else:
      removeLogFile(entry.path, result)

# Calculates the total size of log files in the logs dir and data dir.
proc logsTotalSizeBytes*(logsDir, dataDir: string): int64 =
  var collectResult: LogCleanupResult
  var entries: seq[LogFileEntry]
  collectLogFiles(logsDir, recursive = false, entries, collectResult)
  collectLogFiles(dataDir, recursive = true, entries, collectResult)
  for entry in entries:
    try:
      result += getFileSize(entry.path)
    except OSError, IOError:
      discard

# Matches status-go's session-archive (= lumberjack backup) suffix so that the renamed files keep grouping into
# the right retention family.
proc archiveTimestamp(t: Time): string =
  t.utc.format("yyyy-MM-dd'T'HH-mm-ss") & "." &
    align($(t.nanosecond div 1_000_000), 3, '0')

proc collisionFreeArchivePath(targetDir, family, ext: string, mtime: Time): string =
  for offsetMs in 0 ..< 1000:
    let ts = archiveTimestamp(mtime + initDuration(milliseconds = offsetMs))
    let candidate = joinPath(targetDir, family & "-" & ts & ext)
    if not fileExists(candidate):
      return candidate
  ""

# Moves closed log files from the status-go data dir into the logs dir.
# status-go-owned canonical (live-name) files are moved only when `migrateStatusGoCanonicalNames` is set - i.e. when status-go
# runs inside this process and provably hasn't started yet (desktop, iOS);
# On Android the status-go service outlives the UI process and may still be writing them.
# Canonical files are renamed to a timestamped archive name so they can't collide with the new live file;
# name collisions likewise get a collision-free archive name so nothing is left behind.
# Moving preserves modification times, so per-family retention ordering survives the move.
proc migrateLegacyLogFiles*(dataDir, logsDir: string, processStartedAt: Time,
    migrateStatusGoCanonicalNames: bool = not StatusGoRunsOutOfProcess): LogMigrationResult =
  acquire(cleanupLock)
  defer:
    release(cleanupLock)

  if not dirExists(dataDir):
    return

  var collectResult: LogCleanupResult
  var entries: seq[LogFileEntry]
  collectLogFiles(dataDir, recursive = true, entries, collectResult)
  result.failedCount = collectResult.failedCount
  result.skippedCount = collectResult.skippedCount

  for entry in entries:
    if entry.lastWriteTime >= processStartedAt:
      inc result.skippedCount
      continue
    let name = extractFilename(entry.path)
    let canonical = isCanonicalLogName(name)
    if canonical and not migrateStatusGoCanonicalNames and
        isStatusGoOwnedCanonicalLogName(name):
      inc result.skippedCount
      continue
    var target = joinPath(logsDir, name)
    if canonical or fileExists(target):
      let (_, ext) = splitLogName(name)
      target = collisionFreeArchivePath(logsDir, logFamily(name), ext,
        entry.lastWriteTime)
      if target == "":
        inc result.failedCount
        continue
    try:
      moveFile(entry.path, target)
      inc result.movedCount
    except OSError, IOError:
      inc result.failedCount
