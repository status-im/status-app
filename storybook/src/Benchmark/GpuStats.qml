import QtQml

/*
  The process' own resource use: GPU memory and GPU busy time from the DRM
  fdinfo (Linux, with a driver that reports per-client stats: i915, xe,
  amdgpu, ...), the resident set and the CPU time of all threads.

  Reading /proc goes through XMLHttpRequest, which needs
  QML_XHR_ALLOW_FILE_READ=1; without it every reading is NaN / null and
  `fileReadable` turns false.
*/
QtObject {
    id: root

    property bool fileReadable: true

    // one fd per DRM client: a client's fds all report the same numbers
    property var drmFds: null

    // Clock ticks per second of /proc/self/stat; USER_HZ is 100 on Linux.
    readonly property int clockTicks: 100

    function read(path) {
        if (!fileReadable)
            return ""
        try {
            const xhr = new XMLHttpRequest()
            xhr.open("GET", "file://" + path, false)
            xhr.send()
            return xhr.responseText || ""
        } catch (e) {
            return ""
        }
    }

    function rssKiB() {
        const status = read("/proc/self/status")
        if (!status) {
            fileReadable = false
            return NaN
        }
        const m = /VmRSS:\s+(\d+)/.exec(status)
        return m ? parseInt(m[1]) : NaN
    }

    // user + system CPU time of the whole process, in ms
    function cpuMs() {
        const stat = read("/proc/self/stat")
        if (!stat)
            return NaN
        // the fields after the parenthesised command name, which may hold spaces
        const fields = stat.slice(stat.lastIndexOf(")") + 2).split(" ")
        // utime and stime are fields 14 and 15, i.e. 11 and 12 after the name
        return (parseInt(fields[11]) + parseInt(fields[12])) * 1000 / clockTicks
    }

    function toKiB(value, unit) {
        const v = parseInt(value)
        switch (unit) {
        case "MiB": return v * 1024
        case "GiB": return v * 1024 * 1024
        case "KiB": return v
        default: return v / 1024 // plain bytes
        }
    }

    function discover() {
        drmFds = []
        const seen = {}
        for (let fd = 0; fd < 512; ++fd) {
            const info = read("/proc/self/fdinfo/" + fd)
            const m = /drm-client-id:\s*(\d+)/.exec(info)
            if (m && !seen[m[1]]) {
                seen[m[1]] = true
                drmFds.push(fd)
            }
        }
    }

    // { memKiB, engineNs }, or null where the driver reports nothing
    function gpu() {
        if (!fileReadable)
            return null
        if (drmFds === null)
            discover()
        if (drmFds.length === 0)
            return null

        let memKiB = 0
        let engineNs = 0
        for (const fd of drmFds) {
            const info = read("/proc/self/fdinfo/" + fd)
            const mem = /^drm-total-(\S+):\s+(\d+)\s*(\w*)/gm
            let m
            while ((m = mem.exec(info)) !== null)
                if (m[1].indexOf("stolen") < 0)
                    memKiB += toKiB(m[2], m[3])
            const engine = /^drm-engine-(render|gfx):\s+(\d+)/gm
            while ((m = engine.exec(info)) !== null)
                engineNs += parseInt(m[2])
        }
        return { memKiB, engineNs }
    }
}
