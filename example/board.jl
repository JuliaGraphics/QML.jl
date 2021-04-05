using QML

# Represents the state related to a single emoji
mutable struct EmojiState
  emoji::String
  numclicks::Float64
  bgcolor::String
  ex::Float64
  ey::Float64
end

# Build a list of emoji, positioned randomly
emoji = EmojiState[]
randpos() = rand()*0.8+0.1
for (i,e) in enumerate(["😁", "😃", "😆", "😎", "😈", "☹", "🌚", "😤", "🐭"])
  push!(emoji, EmojiState(e,0, i%2 == 0 ? "lightgrey" : "darkgrey", randpos(), randpos()))
end
emojiModel = ListModel(emoji) # passed to QML

cols = 3

# path to the QML file
qml_file = joinpath(dirname(@__FILE__), "qml", "board.qml")

# create the app, with cols and emojiModel exposed as QML context properties
loadqml(qml_file,cols=cols,emojiModel=emojiModel)

# Start the GUI
exec()

# Print the click summary after exit
for e in emoji
  println("$(e.emoji) was clicked $(Int(e.numclicks)) times")
end