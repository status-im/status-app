# StatusQ

> An emerging reusable QML UI component library for Status applications.

## Usage

StatusQ introduces a module namespace that semantically groups components so they can be easily imported.
These modules are:

- [StatusQ.Core](https://github.com/status-im/StatusQ/blob/master/src/StatusQ/Core/qmldir)
- [StatusQ.Core.Theme](https://github.com/status-im/StatusQ/blob/master/src/StatusQ/Core/Theme/qmldir)
- [StatusQ.Core.Utils](https://github.com/status-im/StatusQ/blob/master/src/StatusQ/Core/Utils/qmldir)
- [StatusQ.Components](https://github.com/status-im/StatusQ/blob/master/src/StatusQ/Controls/qmldir)
- [StatusQ.Controls](https://github.com/status-im/StatusQ/blob/master/src/StatusQ/Components/qmldir)
- [StatusQ.Layout](https://github.com/status-im/StatusQ/blob/master/src/StatusQ/Layout/qmldir)
- [StatusQ.Platform](https://github.com/status-im/StatusQ/blob/master/src/StatusQ/Platform/qmldir)
- [StatusQ.Popups](https://github.com/status-im/StatusQ/blob/master/src/StatusQ/Popups/qmldir)

Provided components can be viewed and tested in the [sandbox application](#viewing-and-testing-components) that comes with this repository.
Other than that, modules and components can be used as expected.

Example:

```
import Status.Core 0.1
import Status.Controls 0.1

StatusInput {
  ...
}
```

### Font loading

The C++ `Fonts` singleton registers the bundled fonts using non-owning views of
the compiled resource data, avoiding the resource-read heap copy retained by Qt's
font database. FreeType also shares these bytes; other platform font backends may
make additional copies. Keep all entries in `src/assets/fonts/fonts.qrc` uncompressed
(`compression-algorithm="none"`); the loader rejects compressed resources.
The resource bytes must remain available for the lifetime of the font database.

## Viewing and testing components

To make viewing and testing components easy, we've added a sandbox application to this repository in which StatusQ components are being build. This is the first place where components see the light of the world and can be run in a proper application environment.

### Using Qt Creator

The easiest way to run the sandbox application is to simply open the provided `CMakeLists.txt` file using Qt Creator.

### Using command line interface

To run the sandbox from within a command line interface, run the following commands:

```
$ git clone https://github.com/status-im/StatusQ
$ cd StatusQ
$ git submodule update --init
$ ./scripts/build
```

Once that is done, the sandbox can be started with the generated executable:

```
$ ./build/sandbox/Sandbox
```
