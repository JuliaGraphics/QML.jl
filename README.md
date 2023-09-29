# QML

[![Latest](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaGraphics.github.io/QML.jl/dev)
[![CodeCov](https://codecov.io/gh/JuliaGraphics/QML.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaGraphics/QML.jl)
[![test-linux](https://github.com/JuliaGraphics/QML.jl/workflows/test-linux/badge.svg)](https://github.com/JuliaGraphics/QML.jl/actions?query=workflow%3Atest-linux)
[![test-win-mac](https://github.com/JuliaGraphics/QML.jl/workflows/test-win-mac/badge.svg)](https://github.com/JuliaGraphics/QML.jl/actions?query=workflow%3Atest-win-mac)

This package provides an interface to [Qt6 QML](http://qt.io/) (and to Qt5 for older versions). It uses the [`CxxWrap`](https://github.com/JuliaInterop/CxxWrap.jl) package to expose C++ classes. Current functionality allows interaction between QML and Julia using [Observables](https://github.com/JuliaGizmos/Observables.jl), JuliaItemModels and function calling. There is also a generic Julia display, as well as specialized integration for image drawing, GR plots and Makie.

![QML demo](docs/src/qml.gif?raw=true "QML demo")

## Installation
Installation on Linux, Mac and Windows should be as easy as: (in pkg mode, hit `]` in the Julia REPL):

```
add QML
```

## Documentation
See https://JuliaGraphics.github.io/QML.jl/dev

## Examples
A set of examples is available in the repository at https://github.com/barche/QmlJuliaExamples

## Basic usage

### Running examples
To run the examples, execute the following code block in the Julia REPL.

```julia
# Alternatively, execute the git command directly in the shell or download the zip file
import LibGit2
isdir("QmlJuliaExamples") || LibGit2.clone("https://github.com/barche/QmlJuliaExamples.git", "QmlJuliaExamples")
cd("QmlJuliaExamples/basic") # or images, opengl or plots instead of the basic subdirectory

# As an alternative to next three lines,
# 1) Start Julia with `julia --project`
# 2) Run `instantiate` from the pkg shell.
using Pkg
Pkg.activate(".")
Pkg.instantiate()

readdir() # Print list of example files
include("gui.jl") # Or any of the files in the directory
```


### Loading a QML file
We support three methods of loading a QML file: `QQmlApplicationEngine`, `QQuickView` and `QQmlComponent`. These behave equivalently to the corresponding Qt classes.
#### QQmlApplicationEngine
The easiest way to run the QML file `main.qml` from the current directory is using the `load` function, which will create and return a `QQmlApplicationEngine` and load the supplied QML file:
```julia
using QML
load("main.qml")
exec()
```

The lifetime of the `QQmlApplicationEngine` is managed from C++ and it gets cleaned up when the application quits. This means it is not necessary to keep a reference to the engine to prevent it from being garbage collected prematurely.

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
In Julia, functions are registered using the `qmlfunction` function:
```julia
my_function() = "Hello from Julia"
my_other_function(a, b) = "Hi from Julia"

qmlfunction("my_function", my_function)
qmlfunction("my_other_function", my_other_function)
```

For convenience, there is also a macro that registers any number of functions that are in scope and will have the same name in QML as in Julia:
```julia
@qmlfunction my_function my_other_function
```

However, the macro cannot be used in the case of non-exported functions from a different module or in case the function contains a `!` character.

In QML, include the Julia API:
```qml
import org.julialang
```

Then call a Julia function in QML using:
```qml
Julia.my_function()
Julia.my_other_function(arg1, arg2)
```

### Context properties
Context properties are set using the context object method. To dynamically add properties from Julia, a `QQmlPropertyMap` is used, setting e.g. a property named `a`:
```julia
propmap = QML.QQmlPropertyMap()
propmap["a"] = 1
```

This sets the QML context property named `property_name` to value `julia_value`.

The value of a property can be queried from Julia like this:
```julia
@test propmap["a"] == 1
```

To pass these properties to the QML side, the property map can be the second argument to `load`:
```julia
load(qml_file, propmap)
```

There is also a shorthand notation using keywords:
```julia
load(qml_file, a=1, b=2)
```
This will create context properties `a` and `b`, initialized to `1` and `2`.

#### Observable properties
When an [`Observable`](https://github.com/JuliaGizmos/Observables.jl) is set in a `QQmlPropertyMap`, bi-directional change notification is enabled. For example, using the Julia code:
```julia
using QML
using Observables

const qml_file = "observable.qml"
const input = Observable(1.0)
const output = Observable(0.0)

on(output) do x
  println("Output changed to ", x)
end

load(qml_file, input=input, output=output)
exec_async() # run from REPL for async execution
```

In QML we add a slider for the input and display the output, which is twice the input (computed in QML here):
```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
  id: root
  title: "Observables"
  width: 512
  height: 200
  visible: true

  ColumnLayout {
    spacing: 6
    anchors.fill: parent

    Slider {
      value: input
      Layout.alignment: Qt.AlignCenter
      Layout.fillWidth: true
      minimumValue: 0.0
      maximumValue: 100.0
      stepSize: 1.0
      tickmarksEnabled: true
      onValueChanged: {
        input = value;
        output = 2*input;
      }
    }

    Text {
      Layout.alignment: Qt.AlignCenter
      text: output
      font.pixelSize: 0.1*root.height
    }
  }

}
```

Moving the slider will print the output on Julia. The input can also be set from the REPL using e.g. `input[] = 3.0`, and the slider will move accordingly and call QML to compute the output, which can be queried using `output[]`.

#### Type conversion
Most fundamental types are converted implicitly. Mind that the default integer type in QML corresponds to `Int32` in Julia.

We also convert `QVariantMap`, exposing the indexing operator `[]` to access element by a string key. This mostly to deal with arguments passed to the QML `append` function in list models.

### Emitting signals from Julia
Defining signals must be done in QML in the JuliaSignals block, following the instructions from the [QML manual](https://doc.qt.io/qt-6/qtqml-syntax-objectattributes.html#signal-attributes). Example signal with connection:
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
#### JuliaItemModel
The `JuliaItemModel` type allows using data in QML views such as `ListView` and `Repeater`, providing a two-way synchronization of the data. The (now removed from Qt) dynamiclist example from Qt has been translated to Julia in the [`dynamiclist.jl`](https://github.com/barche/QmlJuliaExamples/blob/master/dynamiclist.jl) example. As can be seen from [this commit](https://github.com/JuliaGraphics/QML.jl/commit/5f3e64579180fb913c47d92a438466b67098ee52#diff-2a0ca16de100fb8512e0f95c563c9f56c5d5844a756a6e3c8f2bd88476e264a5), the only required change was moving the model data from QML to Julia, otherwise the Qt-provided QML file is left unchanged.

A JuliaItemModel is constructed from a 1D Julia array. In Qt, each of the elements of a model has a series of roles, available as properties in the delegate that is used to display each item. The roles can be added using the `addrole!` function, for example:
```julia
julia_array = ["A", 1, 2.2]
myrole(x::AbstractString) = lowercase(x)
myrole(x::Number) = Int(round(x))

array_model = JuliaItemModel(julia_array)
addrole!(array_model, "myrole", myrole, setindex!)
```
adds the role named `myrole` to `array_model`, using the function `myrole` to access the value. The `setindex!` argument is a function used to set the value for that role from QML. This argument is optional, if it is not provided the role will be read-only. The arguments of this setter are `collection, new_value, key` as in the standard `setindex!` function.

To use the model from QML, it can be exposed as a context attribute, e.g:
```julia
load(qml_file, array_model=array_model)
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

If no roles are added, the `Qt::DisplayRole` is exposed calling the Julia function `string` to convert whatever value in the array to a string.

In the dynamiclist example, the entries in the model are all "fruits", having the roles name, cost and attributes. In Julia, this can be encapsulated in a composite type:
```julia
mutable struct Fruit
  name::String
  cost::Float64
  attributes::JuliaItemModel
end
```

When an array composed only of `Fruit` elements is passed to a JuliaItemModel, setters and getters for the roles and the constructor are all passed to QML automatically, i.e. this will automatically expose the roles `name`, `cost` and `attributes`:
```julia
# Our initial data
fruitlist = [
  Fruit("Apple", 2.45, JuliaItemModel([Attribute("Core"), Attribute("Deciduous")])),
  Fruit("Banana", 1.95, JuliaItemModel([Attribute("Tropical"), Attribute("Seedless")])),
  Fruit("Cumquat", 3.25, JuliaItemModel([Attribute("Citrus")])),
  Fruit("Durian", 9.95, JuliaItemModel([Attribute("Tropical"), Attribute("Smelly")]))]

# Set a context property with our JuliaItemModel
propmap["fruitModel"] = JuliaItemModel(fruitlist)
```
See the full example for more details, including the addition of an extra constructor to deal with the nested `JuliaItemModel` for the attributes.

## Using QTimer
`QTimer` can be used to simulate running Julia code in the background. Excerpts from [`test/gui.jl`](test/gui.jl):

```julia
const bg_counter = Observable(0)

function counter_slot()
  global bg_counter
  bg_counter[] += 1
end

@qmlfunction counter_slot

load(qml_file, timer=QTimer(), bg_counter=bg_counter)
```

Use in QML like this:
```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.julialang

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

## JuliaCanvas

QML.jl provides a custom QML type named `JuliaCanvas` which presents a canvas to be painted via a julia callback function.  This approach avoids the MIME content encoding overhead of the JuliaDisplay approach.

Example use in QML from the `canvas` example:
 ```qml
 JuliaCanvas {
   id: circle_canvas
   paintFunction: paint_cfunction
   Layout.fillWidth: true
   Layout.fillHeight: true
   Layout.minimumWidth: 100
   Layout.minimumHeight: 100
 }
 ```
 The callback function `paint_cfunction` is defined in julia:
 ```julia

 # fix callback arguments (TODO: macro this?)
 function paint_circle(buffer::Array{UInt32, 1},
                       width32::Int32,
                       height32::Int32)
    width::Int = width32
    height::Int = height32
    buffer = reshape(buffer, width, height)
    buffer = reinterpret(ARGB32, buffer)
    paint_circle(buffer)
end

# callback to paint circle
function paint_circle(buffer)
    width, height = size(buffer)
    for x in 1:width
        for y in 1:height
            # paint here..., e.g.
            buffer[x,y] = ARGB32(1, 0, 0, 1) #red
        end
    end
 end

 load(qmlfile,
      #...
      paint_cfunction = CxxWrap.@safe_cfunction(paint_circle, Cvoid, (Array{UInt32,1}, Int32, Int32))
 )
```
Note that the canvas buffer is allocated (and freed) in the C++ code.  A new unitialized buffer is allocated for each frame (this could change).

At the moment, only the 32-bit QImage::Format_RGB32 (alpha, red, green, blue) image format is supported.

See the example for details on emitting an update signal from julia to force redrawing the JuliaCanvas.

----
**NOTE**

Set 

```julia
ENV["QSG_RENDER_LOOP"] = "basic"
```

at the top of your Julia file to avoid crashes or infinite loops when using JuliaCanvas.

----

## Combination with the REPL
When launching the application using `exec`, execution in the REPL will block until the GUI is closed. If you want to continue using the REPL with an active QML gui, `exec_async` provides an alternative. This method keeps the REPL active and polls the QML interface periodically for events, using a timer in the Julia event loop. An example (requiring packages Plots.jl and PyPlot.jl) can be found in [`repl-background.jl`](https://github.com/barche/QmlJuliaExamples/blob/master/repl-background.jl), to be used as:
```julia
include("repl-background.jl")
plot([1,2],[3,4])
```
This should display the result of the plotting command in the QML window.

For further examples, see the [`documentation`](https://JuliaGraphics.github.io/QML.jl/dev).

## Breaking changes

### Upgrade from v0.6 to v0.7
* Julia 1.6 minimal requirement

### Upgrade from v0.4 to v0.6
* Signals in `JuliaSignals` must have arguments of type `var`
* Role indices are 1-based now on the Julia side
* The interface of some functions has changed because of the way CxxWrap handles references and pointers more strictly now
* No more automatic conversion from `String` to `QUrl`, use the `QUrl("mystring")` constructor
* Setting a `QQmlPropertyMap` as context object is not supported as of Qt 5.12

### Upgrade from v0.6 to v0.8

This moves the package to Qt 6. Aside from this, the JuliaItemModel was changed extensively, refer to the [test](https://github.com/JuliaGraphics/QML.jl/blob/main/test/tableview.jl) and [examples](https://github.com/barche/QmlJuliaExamples/blob/master/basic/tableview.jl) to see how to use it.
