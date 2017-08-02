# QML

[![Build Status](https://travis-ci.org/barche/QML.jl.svg?branch=master)](https://travis-ci.org/barche/QML.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/7edud4w38g8m17yw?svg=true)](https://ci.appveyor.com/project/barche/qml-jl)

This package provides an interface to [Qt5 QML](http://qt.io/). It uses the [`CxxWrap`](https://github.com/barche/CxxWrap.jl) package to expose C++ classes. Current functionality allows interaction between QML and Julia using basic numerical and string types, as well as display of PNG images and a very experimental OpenGL rendering element (see `example/gltriangle.jl`).

![QML plots example](example/plot.png?raw=true "Plots example")

![OpenGL example](example/gltriangle.gif?raw=true "OpenGL example, using GLAbstraction.jl")

## Installation
To install, type:
```julia
Pkg.add("QML")
```

On Linux and macOS, compilation should be automatic, with dependencies installed by the packagemanager or Homebrew.jl. On Windows, binaries are downloaded. To use a non-standard Qt, set the environment variable `QT_ROOT` to the base Qt directory (the one containing `lib` and `bin` on macOS and linux, or the directory containing `msvc2015_64` or `msvc2015` on Windows).

You can check that the correct Qt version is used using the `qt_prefix_path()` function.

### Raspberry Pi
Because of issues with LLVM library compatibility between the graphics driver on the Raspberry Pi and Julia, QML.jl will only work if you build Julia from source, using the system LLVM version 3.9. Install the `llvm-3.9-dev` package, and then build Julia with the following Make.user:

```
override LLVM_CONFIG=llvm-config-3.9
override USE_SYSTEM_LLVM=1
```

## Usage
### Running examples
To run the included examples, execute:
```julia
include(joinpath(Pkg.dir("QML"), "example", "runexamples.jl"))
```
The examples require some additional packages to be installed:
```julia
Pkg.add("ModernGL")
Pkg.add("GLVisualize")
Pkg.add("GeometryTypes")
Pkg.add("GR")
Pkg.add("TestImages")
Pkg.add("Plots")
Pkg.add("PyPlot")
Pkg.clone("https://github.com/BenLauwens/StatefulFunctions.jl.git")
```
And additionally,
* On Linux and Windows, `Pkg.add("ImageMagick")`
* On macOS, `Pkg.add("QuartzImageIO")`

### Loading a QML file
We support three methods of loading a QML file: `QQmlApplicationEngine`, `QQuickView` and `QQmlComponent`. These behave equivalently to the corresponding Qt classes.
#### QQmlApplicationEngine
The easiest way to run the QML file `main.qml` from the current directory is using the `@qmlapp` macro:
```julia
using QML
@qmlapp "main.qml"
exec()
```
The QML must have an `ApplicationWindow` as top component. It is also possible to default-construct the `QQmlApplicationEngine` and call `load` to load the QML separately:
```julia
qml_engine = init_qmlapplicationengine()
# ...
# set properties, ...
# ...
load(qml_engine, "main.qml")
```

This is useful to set context properties before loading the QML, for example.

Note we use `init_` functions rather than calling the constructor for the Qt type directly. The init methods have the advantage that cleanup (calling delete etc.) happens in C++ automatically. Calling the constructor directly requires manually finalizing the corresponding components in the correct order and has a high risk of causing crashes on exit.

#### QQuickView
The `QQuickView` creates a window, so it's not necessary to wrap the QML in `ApplicationWindow`. A QML file is loaded as follows:

```julia
qview = init_qquickview()
set_source(qview, "main.qml")
QML.show(qview)
exec()
```

#### QQmlComponent
Using `QQmlComponent` the QML code can be set from a Julia string wrapped in `QByteArray`:

```julia
qml_data = QByteArray("""
import ...

ApplicationWindow {
  ...
}
""")

qengine = init_qmlengine()
qcomp = QQmlComponent(qengine)
set_data(qcomp, qml_data, "")
create(qcomp, qmlcontext());

# Run the application
exec()
```

## Interacting with Julia
Interaction with Julia happens through the following mechanisms:
* Call Julia functions from QML
* Read and set context properties from Julia and QML
* Emit signals from Julia to QML
* Use data models

Note that Julia slots appear missing, but they are not needed since it is possible to directly connect a Julia function to a QML signal in the QML code (see the QTimer example below).

### Calling Julia functions
In Julia, functions are registered using the `@qmlfunction` macro:
```julia
my_function() = "Hello from Julia"
my_other_function(a, b) = "Hi from Julia"

@qmlfunction my_function my_other_function
```

The macro takes any number of function names as arguments

In QML, include the Julia API:
```qml
import org.julialang 1.0
```

Then call a Julia function in QML using:
```qml
Julia.my_function()
Julia.my_other_function(arg1, arg2)
```

### Context properties
The entry point for setting context properties is the root context of the engine, available using the `qmlcontext()` function. It is defined once the `@qmlapp` macro or one of the init functions has been called.
```julia
@qmlset qmlcontext().property_name = property_value
```

This sets the QML context property named `property_name` to value `julia_value`. Any time the `@qmlset` macro is called on such a property, QML is notified of the change and updates any dependent values.

The value of a property can be queried from Julia like this:
```julia
@qmlget qmlcontext().property_name
```

At application initialization, it is also possible to pass context properties as additional arguments to the `@qmlapp` macro:
```julia
my_prop = 2.
@qmlapp "main.qml" my_prop
```
This will initialize a context property named `my_prop` with the value 2.

#### Type conversion
Most fundamental types are converted implicitly. Mind that the default integer type in QML corresponds to `Int32` in Julia.

We also convert `QVariantMap`, exposing the indexing operator `[]` to access element by a string key. This mostly to deal with arguments passed to the QML `append` function in list models.

#### Composite types
Setting a composite type as a context property maps the type fields into a `JuliaObject`, which derives from `QQmlPropertyMap`. Example:

```julia
type JuliaTestType
  a::Int32
end

jobj = JuliaTestType(0.)
@qmlset qmlcontext().julia_object = jobj
@qmlset qmlcontext().julia_object.a = 2
@test @qmlget(root_ctx.julia_object.a) == 2
@test jobj.a == 2
```

Access from QML:
```qml
import QtQuick 2.0

Timer {
     interval: 0; running: true; repeat: false
     onTriggered: {
       julia_object.a = 1
       Qt.quit()
     }
 }
```

When passing a `JuliaObject` object from QML to a Julia function, it is automatically converted to the Julia value, so on the Julia side it can be manipulated as normal. To get the QML side to see the changes the `update` function must be called:

```julia
type JuliaTestType
  a::Int32
  i::InnerType
end

# passed as context property
julia_object2 = JuliaTestType(0, InnerType(0.0))

function setthree(x::JuliaTestType)
  x.a = 3
  x.i.x = 3.0
end

function testthree(a,x)
  @test a == 3
  @test x == 3.0
end
```

```qml
// ...
Julia.setthree(julia_object2)
julia_object2.update()
Julia.testthree(julia_object2.a, julia_object2.i.x)
// ...
```

### Emitting signals from Julia
Defining signals must be done in QML in the JuliaSignals block, following the instructions from the [QML manual](http://doc.qt.io/qt-5/qtqml-syntax-objectattributes.html#signal-attributes). Example signal with connection:
```qml
JuliaSignals {
  signal fizzBuzzFound(int fizzbuzzvalue)
  onFizzBuzzFound: lastFizzBuzz.text = fizzbuzzvalue
}
```

The above signal is emitted from Julia using simply:
```julia
@emit fizzBuzzFound(i)
```

**There must never be more than one JuliaSignals block in QML**

### Using data models
#### ListModel
The `ListModel` type allows using data in QML views such as `ListView` and `Repeater`, providing a two-way synchronization of the data. The [dynamiclist](http://doc.qt.io/qt-5/qtquick-views-listview-dynamiclist-qml.html) example from Qt has been translated to Julia in `example/dynamiclist.jl`. As can be seen from [this commit](https://github.com/barche/QML.jl/commit/5f3e64579180fb913c47d92a438466b67098ee52), the only required change was moving the model data from QML to Julia, otherwise the Qt-provided QML file is left unchanged.

A ListModel is constructed from a 1D Julia array. In Qt, each of the elements of a model has a series of roles, available as properties in the delegate that is used to display each item. The roles can be added using the `addrole` function, for example:
```julia
julia_array = ["A", 1, 2.2]
myrole(x::AbstractString) = lowercase(x)
myrole(x::Number) = Int(round(x))

array_model = ListModel(julia_array)
addrole(array_model, "myrole", myrole, setindex!)
```
adds the role named `myrole` to `array_model`, using the function `myrole` to access the value. The `setindex!` argument is a function used to set the value for that role from QML. This argument is optional, if it is not provided the role will be read-only. The arguments of this setter are `collection, new_value, key` as in the standard `setindex!` function.

To use the model from QML, it can be exposed as a context attribute, e.g:
```julia
@qmlapp qml_file array_model
```

And then in QML:
```qml
ListView {
  width: 200
  height: 125
  model: array_model
  delegate: Text { text: myrole }
}
```

If no roles are added, one default role named `string` is exposed, calling the Julia function `string` to convert whatever value in the array to a string.

If new elements need to be constructed from QML, a constructor can also be provided, using the `setconstructor` method, taking a `ListModel` and a Julia function as arguments, e.g. just setting identity to return the constructor argument:
```julia
setconstructor(array_model, identity)
```

In the dynamiclist example, the entries in the model are all "fruits", having the roles name, cost and attributes. In Julia, this can be encapsulated in a composite type:
```julia
type Fruit
  name::String
  cost::Float64
  attributes::ListModel
end
```

When an array composed only of `Fruit` elements is passed to a listmodel, setters and getters for the roles and the constructor are all passed to QML automatically, i.e. this will automatically expose the roles `name`, `cost` and `attributes`:
```julia
# Our initial data
fruitlist = [
  Fruit("Apple", 2.45, ListModel([Attribute("Core"), Attribute("Deciduous")])),
  Fruit("Banana", 1.95, ListModel([Attribute("Tropical"), Attribute("Seedless")])),
  Fruit("Cumquat", 3.25, ListModel([Attribute("Citrus")])),
  Fruit("Durian", 9.95, ListModel([Attribute("Tropical"), Attribute("Smelly")]))]

# Set a context property with our listmodel
@qmlset qmlcontext().fruitModel = ListModel(fruitlist)
```
See the full example for more details, including the addition of an extra constructor to deal with the nested `ListModel` for the attributes.

## Using QTimer
`QTimer` can be used to simulate running Julia code in the background. Excerpts from [`test/gui.jl`](test/gui.jl):

```julia
bg_counter = 0

function counter_slot()
  global bg_counter
  bg_counter += 1
  @qmlset qmlcontext().bg_counter = bg_counter
end

@qmlfunction counter_slot

timer = QTimer()
@qmlset qmlcontext().bg_counter = bg_counter
@qmlset qmlcontext().timer = timer
```

Use in QML like this:
```qml
import QtQuick 2.0
import QtQuick.Controls 1.0
import QtQuick.Layouts 1.0
import org.julialang 1.0

ApplicationWindow {
    title: "My Application"
    width: 480
    height: 640
    visible: true

    Connections {
      target: timer
      onTimeout: Julia.counter_slot()
    }

    ColumnLayout {
      spacing: 6
      anchors.centerIn: parent

      Button {
          Layout.alignment: Qt.AlignCenter
          text: "Start counting"
          onClicked: timer.start()
      }

      Text {
          Layout.alignment: Qt.AlignCenter
          text: bg_counter.toString()
      }

      Button {
          Layout.alignment: Qt.AlignCenter
          text: "Stop counting"
          onClicked: timer.stop()
      }
  }
}

```

Note that QML provides the infrastructure to connect to the `QTimer` signal through the `Connections` item.

## JuliaDisplay
QML.jl provides a custom QML type named `JuliaDisplay` that acts as a standard Julia multimedia `Display`. Currently, only the `image/png` mime type is supported. Example use in QML from the `plot` example:
 ```qml
 JuliaDisplay {
   id: jdisp
   Layout.fillWidth: true
   Layout.fillHeight: true
   onHeightChanged: root.do_plot()
   onWidthChanged: root.do_plot()
 }
 ```
 The function `do_plot` is defined in the parent QML component and calls the Julia plotting routine, passing the display as an argument:
 ```qml
 function do_plot()
 {
   if(jdisp === null)
     return;

   Julia.plotsin(jdisp, jdisp.width, jdisp.height, amplitude.value, frequency.value);
 }
 ```
 Of course the display can also be added using `pushdisplay!`, but passing by value can be more convenient when defining multiple displays in QML.

## Combination with the REPL
When launching the application using `exec`, execution in the REPL will block until the GUI is closed. If you want to continue using the REPL with an active QML gui, `exec_async` provides an alternative. This method keeps the REPL active and polls the QML interface periodically for events, using a timer in the Julia event loop. An example (requiring packages Plots.jl and PyPlot.jl) can be found in `example/repl-background.jl`, to be used as:
```julia
include("example/repl-background.jl")
plot([1,2],[3,4])
```
This should display the result of the plotting command in the QML window.
