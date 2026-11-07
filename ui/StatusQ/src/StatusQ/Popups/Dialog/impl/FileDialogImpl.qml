import QtQuick.Dialogs

// Loaded by URL from StatusFileDialog / StatusSaveFileDialog on the first open(), so
// QtQuick.Dialogs (and its Qt Quick fallback implementation) is not loaded before a picker is used
FileDialog {}
