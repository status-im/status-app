import QtQuick
import QtTest

import StatusQ.Core

// The compiled shaders are in StatusQ's resources, where the components load
// them from. Runs offscreen too (CI), where the components' pixel tests skip.
Item {
    TestCase {
        name: "StatusQShaders"

        function test_shaderIsBuiltIntoStatusQ_data() {
            return [
                "edgefade.frag",
                "ripple.frag",
                "roundedimage.frag",
                "roundedrendersizedimage.frag",
                "roundedrendersizedimage.vert",
                "roundedrendersizedimageborder.frag",
                "skeletonmask.frag",
            ].map(name => ({ tag: name, path: `:/StatusQ/shaders/${name}.qsb` }))
        }

        function test_shaderIsBuiltIntoStatusQ(data) {
            verify(SystemUtils.fileExists(data.path), data.path)
        }
    }
}
