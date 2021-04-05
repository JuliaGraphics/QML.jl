# MUST disable threading in Qt
ENV["QSG_RENDER_LOOP"] = "basic"

using CxxWrap
using QML
using ModernGL, GeometryTypes

mutable struct Corner
    id::Int32
    cx::Float64
    cy::Float64
end

const corners = [Corner(1,0,0.5), Corner(2,0.5,-0.5), Corner(3,-0.5,-0.5)]

function render()
  # Draw a triangle. Code mostly from the tutorials in GLAbstraction.
  vao = Ref(GLuint(0))
  glGenVertexArrays(1, vao)
  glBindVertexArray(vao[])

  # The vertices of our triangle
  vertices = Point2f0[(c.cx, c.cy) for c in corners] # note Float32

  # Create the Vertex Buffer Object (VBO)
  vbo = Ref(GLuint(0))   # initial value is irrelevant, just allocate space
  glGenBuffers(1, vbo)
  glBindBuffer(GL_ARRAY_BUFFER, vbo[])
  glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW)

  # The vertex shader
  vertex_source = """
  #version 150

  in vec2 position;

  void main()
  {
      gl_Position = vec4(position, 0.0, 1.0);
  }
  """

  # The fragment shader
  fragment_source = """
  # version 150

  out vec4 outColor;

  void main()
  {
      outColor = vec4(1.0, 1.0, 1.0, 1.0);
  }
  """

  srctoptr(s) = convert(Ptr{UInt8}, pointer([convert(Ptr{GLchar}, pointer(s))]))

  # Compile the vertex shader
  vertex_shader = glCreateShader(GL_VERTEX_SHADER)
  glShaderSource(vertex_shader, 1, srctoptr(vertex_source), C_NULL)  # nicer thanks to GLAbstraction
  glCompileShader(vertex_shader)
  # Check that it compiled correctly
  status = Ref(GLint(0))
  glGetShaderiv(vertex_shader, GL_COMPILE_STATUS, status)
  if status[] != GL_TRUE
      buffer = Array(UInt8, 512)
      glGetShaderInfoLog(vertex_shader, 512, C_NULL, buffer)
      error(bytestring(buffer))
  end

  # Compile the fragment shader
  fragment_shader = glCreateShader(GL_FRAGMENT_SHADER)
  glShaderSource(fragment_shader, 1, srctoptr(fragment_source), C_NULL)
  glCompileShader(fragment_shader)
  # Check that it compiled correctly
  status = Ref(GLint(0))
  glGetShaderiv(fragment_shader, GL_COMPILE_STATUS, status)
  if status[] != GL_TRUE
      buffer = Array(UInt8, 512)
      glGetShaderInfoLog(fragment_shader, 512, C_NULL, buffer)
      error(bytestring(buffer))
  end

  # Connect the shaders by combining them into a program
  shader_program = glCreateProgram()
  glAttachShader(shader_program, vertex_shader)
  glAttachShader(shader_program, fragment_shader)
  glBindFragDataLocation(shader_program, 0, "outColor") # optional

  glLinkProgram(shader_program)
  glUseProgram(shader_program)

  # Link vertex data to attributes
  pos_attribute = glGetAttribLocation(shader_program, "position")
  glVertexAttribPointer(pos_attribute, length(eltype(vertices)),
                        GL_FLOAT, GL_FALSE, 0, C_NULL)
  glEnableVertexAttribArray(pos_attribute)

  # Set background
  glClearColor(0.4,0.4,1.0,1.)
  glEnable(GL_DEPTH_TEST)
  glDepthFunc(GL_LESS)
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

  # Render triangle
  glDrawArrays(GL_TRIANGLES, 0, length(vertices))
end

# Pass the triangle as a context property
loadqml(joinpath(dirname(@__FILE__), "qml", "gltriangle.qml"),
    cornersModel=ListModel(corners),
    render_triangle=@safe_cfunction(render, Cvoid, ()))
exec()
