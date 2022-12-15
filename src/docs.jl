"""
    function content_item(quick_view::QQuickView)

Get the content item of a quick view. Equivalent to `QQuickWindow::contentItem`.

```jldoctest
julia> using QML

julia> using CxxWrap.CxxWrapCore: CxxPtr

julia> quick_view = mktempdir() do folder
          path = joinpath(folder, "main.qml")
          write(path, \"""
          import QtQuick
          import QtQuick.Controls
          Rectangle {
            Timer {
              running: true; repeat: false
              onTriggered: Qt.exit(0)
            }
          }
          \""")
          quick_view = init_qquickview()
          set_source(quick_view, QUrlFromLocalFile(path))
          @assert content_item(quick_view) isa CxxPtr{QQuickItem}
          exec()
        end
```
"""
content_item

"""
    function context_property(context::QQmlContext, item::AbstractString)

Get a context property. See the example for [`root_context`](@ref).
"""
context_property

"""
    function create(component::QQmlComponent, context::QQmlContext)

Equivalent to `QQmlComponent::create`. This creates a component defined by the QML code set
using `set_data`. It also makes sure the newly created object is parented to the given
`context`. See the example for [`set_data`](@ref).
"""
create

"""
    function engine(quick_view::QQuickView)

Equivalent to `QQuickView::engine`. If you would like to modify the context of a
[`QQuickView`](@ref), use `engine` to get an engine from the window, and then
[`root_context`](@ref) to get the context from the engine.

```jldoctest
julia> using QML

julia> mktempdir() do folder
          path = joinpath(folder, "main.qml")
          write(path, \"""
          import QtQuick
          import QtQuick.Controls
          Rectangle {
            Text {
              text: greeting
            }
            Timer {
              running: true; repeat: false
              onTriggered: Qt.exit(0)
            }
          }
          \""")
          quick_view = init_qquickview()
          context = root_context(engine(quick_view))
          set_context_property(context, "greeting", "Hello, World!")
          set_source(quick_view, QUrlFromLocalFile(path))
          QML.show(quick_view)
          exec()
        end
```
"""
engine

"""
    function exec()

Fill out a window. Use with a [`QQmlApplicationEngine`](@ref), [`QQuickView`](@ref), or
[`QQmlComponent`](@ref). Note that after calling `exec`, you will need to reregister
functions, e.g. with [`@qmlfunction`], if you want to `exec` again.
"""
exec

"""
    function exec_async()

Similar to [`exec`](@ref), but will not block the main process. This method keeps the REPL
active and polls the QML interface periodically for events, using a timer in the Julia event
loop.
"""
exec_async

"""
    function init_qmlengine()

Create a QML engine. You can modify the context of an engine using [`root_context`](@ref).
You can use an engine to create `QQmlComponent`s. See the example for [`set_data`](@ref).
Note that you can also get the engine for a `QQuickView` using [`engine`](@ref).
"""
init_qmlengine

"""
    function init_qquickview()

Create a [`QQuickView`](@ref).
"""
init_qquickview

"""
    struct JuliaDisplay

You can use `display` to send images to a JuliaDisplay. There is a corresponding QML block
called JuliaDisplay. Of course the display can also be added using `pushdisplay!`, but
passing by value can be more convenient when defining multiple displays in QML. See below
for syntax.

```jldoctest
julia> using QML

julia> using Plots: plot

julia> function simple_plot(julia_display::JuliaDisplay)
          x = 0:1:10
          display(julia_display, plot(x, x, show = false, size = (500, 500)))
          nothing
        end;

julia> @qmlfunction simple_plot

julia> mktempdir() do folder
          path = joinpath(folder, "main.qml")
          write(path, \"""
          import QtQuick
          import QtQuick.Controls
          import QtQuick.Layouts
          import org.julialang
          ApplicationWindow {
            visible: true
            Column {
              Button {
                text: "Plot"
                onClicked: Julia.simple_plot(julia_display)
              }
              JuliaDisplay {
                id: julia_display
                width: 500
                height: 500
              }
              Timer {
                running: true; repeat: false
                onTriggered: Qt.exit(0)
              }
            }
          }
          \""")
          loadqml(path)
          exec()
        end

```
"""
JuliaDisplay

"""
Module for building [Qt5 QML](http://doc.qt.io/qt-5/qtqml-index.html) graphical user interfaces for Julia programs.
Types starting with `Q` are equivalent of their Qt C++ counterpart, so, unless otherwise noted, they have no Julia docstring and we refer to
the [Qt documentation](http://doc.qt.io/qt-5/qtqml-index.html) for details instead.
"""
QML

"""
    function qmlcontext()

Create an empty context for QML. Required for [`create`](@ref).
"""
qmlcontext

"""
    function qmlfunction(function_name::String, a_function)

Register `a_function` using `function_name`. If you want to register a function under
it's own name, you can use [`@qmlfunction`](@ref). Note, however, that you can't use the
macro for registering functions from a non-exported module or registering functions wtih
`!` in the name.
"""
qmlfunction

"""
    function QByteArray(a_string::String)

Use to pass text to [`set_data`](@ref).
"""
QByteArray

"""
    struct QQmlApplicationEngine

One of 3 ways to interact with QML (the others being [`QQuickView`](@ref) and
[`QQmlComponent`](@ref). You can load a QML file to create an engine with [`load`](@ref).
Use [`exec`](@ref) to execute a file after it's been loaded.

The lifetime of the `QQmlApplicationEngine` is managed from C++ and it gets cleaned up when
the application  quits. This means it is not necessary to keep a reference to the engine to
prevent it from being garbage collected prematurely.

```jldoctest
julia> using QML

julia> mktempdir() do folder
          path = joinpath(folder, "main.qml")
          write(path, \"""
          import QtQuick
          import QtQuick.Controls
          ApplicationWindow {
            visible: true
            Text {
              text: greeting
            }
            Timer {
              running: true; repeat: false
              onTriggered: Qt.exit(0)
            }
          }
          \""")
          loadqml(path; greeting = "Hello, World!")
          exec()
        end
```
"""
QQmlApplicationEngine

"""
    struct QQmlComponent

One of 3 ways to interact with QML (the others being [`QQmlApplicationEngine`](@ref) and
[`QQuickView`](@ref). Make from an engine from e.g.[`init_qmlengine`](@ref).
Use [`set_data`](@ref) to set the QML code, [`create`](@ref) to create the window, and
[`exec`](@ref) to fill the window.

```jldoctest
julia> using QML

julia> component = QQmlComponent(init_qmlengine());

julia> set_data(component, QByteArray(\"""
          import QtQuick
          import QtQuick.Controls
          ApplicationWindow {
            visible: true
            Rectangle {
              Text {
                text: "Hello, World!"
              }
              Timer {
                running: true; repeat: false
                onTriggered: Qt.exit(0)
              }
            }
          }
        \"""), QUrl())

julia> create(component, qmlcontext())

julia> exec()
```
"""
QQmlComponent

"""
    function qt_prefix_path()

Equivalent to `QLibraryInfo::location(QLibraryInfo::PrefixPath)`. Useful to check whether
the intended Qt version is being used.

```jldoctest
julia> using QML

julia> isdir(qt_prefix_path())
true
```
"""
qt_prefix_path

"""
    struct QQuickView

One of 3 ways to interact with QML (the others being [`QQmlApplicationEngine`](@ref) and
[`QQmlComponent`](@ref). `QQuickView` creates a window, so it's not necessary to wrap the
QML in ApplicationWindow. Use [`init_qquickview`](@ref) to create a quick view,
[`set_source`](@ref) to set the source for the quick view, [`QML.show`](@ref) to view, and
[`exec`](@ref) to execute.

```jldoctest
julia> using QML

julia> mktempdir() do folder
          path = joinpath(folder, "main.qml")
          write(path, \"""
          import QtQuick
          import QtQuick.Controls
          Rectangle {
            Text {
              text: "Hello, World!"
            }
            Timer {
              running: true; repeat: false
              onTriggered: Qt.exit(0)
            }
          }
          \""")
          quick_view = init_qquickview()
          set_source(quick_view, QUrlFromLocalFile(path))
          QML.show(quick_view)
          exec()
        end
```
"""
QQuickView

"""
    struct QTimer

You can use `QTimer` to simulate running Julia in the background. Note that QML provides the
infrastructure to connect to the `QTimer` signal through the `Connections` item.

```jldoctest
julia> using QML

julia> counter = Ref(0);

julia> increment() = counter[] += 1;

julia> @qmlfunction increment

julia> mktempdir() do folder
          path = joinpath(folder, "main.qml")
          write(path, \"""
          import QtQuick
          import QtQuick.Controls
          import org.julialang
          ApplicationWindow {
              visible: true
              Connections {
                target: timer
                function onTimeout() {
                  Julia.increment()
                }
              }
              Button {
                  text: "Start counting"
                  onClicked: timer.start()
              }
              Timer { // unrelated, this is a timer to stop and continue testing
                running: true; repeat: false
                onTriggered: Qt.exit(0)
              }
          }
          \""")
          loadqml(path, timer=QTimer())
          exec()
        end
```
"""
QTimer

"""
    struct QUrl([filename::String])

Used to pass filenames to [`set_source`](@ref). Pass an empty url (no arguments) to
[`set_data`](@ref).
"""
QUrl

"""
    root_context(an_engine::QQmlEngine)

Get the context of `an_engine`. Equivalent to
[`QQmlEngine::rootContext`](http://doc.qt.io/qt-5/qqmlengine.html#rootContext). Use
[`set_context_property`](@ref) to modify the context. Use [`context_property`](@ref) to
get a particular property. Use to get the context of an engine created with
[`init_qmlengine`](@ref) before using [`set_data`](@ref) or from [`engine`](@ref).

```jldoctest
julia> using QML

julia> an_engine = init_qmlengine();

julia> context = root_context(an_engine);

julia> set_context_property(context, "greeting", "Hello, World!");

julia> context_property(context, "greeting")
QVariant of type QML.QString with value Hello, World!

julia> component = QQmlComponent(an_engine);

julia> set_data(component, QByteArray(\"""
          import QtQuick
          import QtQuick.Controls
          ApplicationWindow {
            visible: true
            Rectangle {
              Text {
                text: greeting
              }
              Timer {
                running: true; repeat: false
                onTriggered: Qt.exit(0)
              }
            }
          }
        \"""), QUrl())

julia> create(component, qmlcontext())

julia> exec()
```
"""
root_context

"""
    set_context_property(context::QQmlContext, name::String, value::Any)

Set properties. See [`root_context`](@ref) for an example.
"""
set_context_property

"""
    function set_data(component::QQmlComponent, data::QByteArray, file::QUrl)

Equivalent to `QQmlComponent::setData`. Use this to set the QML code for a
[`QQmlComponent`](@ref) from a Julia string literal wrapped in a [`QByteArray`](@ref). Also
requires an empty [`QUrl`](@ref). See [`QQmlComponent`](@ref) for an example.
"""
set_data

"""
    function set_source(window::QQuickView, file::QUrl)

Equivalent to `QQuickView::setSource`. See the example for [`init_qquickview`](@ref). The
file path should be a path wrapped with [`QUrl`](@ref).
"""
set_source

@doc """
     function QML.show()

Equivalent to `QQuickView::show`. See example for [`QQuickView`](@ref).
"""
show

"""
    function string(data::QByteArray)

Equivalent to `QByteArray::toString`. Use to convert a [`QByteArray`](@ref) back to a
string.

```jldoctest
julia> using QML

julia> string(QByteArray("Hello, World!"))
"Hello, World!"
```
"""
string
