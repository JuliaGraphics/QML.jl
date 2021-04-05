using QML

# Represents the state related to a single emoji
mutable struct EmojiState
  emoji::String
  numclicks::Float64
  bgcolor::String
end

# Build a list of emoji
emoji = EmojiState[]
for (i,e) in enumerate(["😁", "😃", "😆", "😎", "😈", "☹", "🌚", "😤", "🐭"])
  push!(emoji, EmojiState(e,0, i%2 == 0 ? "lightgrey" : "darkgrey"))
end

# path to the QML file
qml_file = joinpath(dirname(@__FILE__), "qml", "grid.qml")

# create the app, with cols and emojiModel exposed as QML context properties
loadqml(qml_file, cols=3, emojiModel=ListModel(emoji))

# Start the GUI
exec()

# Print the click summary after exit
for e in emoji
  println("$(e.emoji) was clicked $(Int(e.numclicks)) times")
end