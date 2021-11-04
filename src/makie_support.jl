module MakieSupport

using ..GLMakie
using ..GLMakie.Colors
using ..GLMakie.FixedPointNumbers
using ..GLMakie.ModernGL
using ..GLMakie.StaticArrays
using ..GLMakie.LinearAlgebra
using QML
using CxxWrap

const GLAbstraction = GLMakie.GLAbstraction
using .GLAbstraction


const enable_SSAO = Ref(false)
const enable_FXAA = Ref(true)


mutable struct QMLGLContext
  valid::Bool
  fbo::CxxPtr{QML.QOpenGLFramebufferObject}
end

GLMakie.ShaderAbstractions.native_switch_context!(ctx::QMLGLContext) = QML.bind(ctx.fbo)

function GLMakie.ShaderAbstractions.native_context_alive(ctx::QMLGLContext)
  return ctx.valid
end

const ScreenID = GLMakie.ScreenID
const ZIndex = GLMakie.ZIndex
const RenderObject = GLMakie.RenderObject
const ScreenArea = GLMakie.ScreenArea

@cxxdereference function sizetuple(fbo::QML.QOpenGLFramebufferObject)
  fbosize = QML.size(fbo)
  return (Int(QML.width(fbosize)), Int(QML.height(fbosize)))
end

mutable struct QMLScreen <: GLMakie.GLScreen
  screen2scene::Dict{WeakRef, ScreenID}
  screens::Vector{ScreenArea}
  renderlist::Vector{Tuple{ZIndex, ScreenID, RenderObject}}
  postprocessors::Vector{GLMakie.PostProcessor}
  cache::Dict{UInt64, RenderObject}
  cache2plot::Dict{UInt16, AbstractPlot}
  framecache::Matrix{RGB{N0f8}}
  framebuffer::GLMakie.GLFramebuffer
  # render_tick::Observable{Nothing}
  # window_open::Observable{Bool}
  qmlfbo::QML.QOpenGLFramebufferObject

  @cxxdereference function QMLScreen(fbo::QML.QOpenGLFramebufferObject)
    fbosize = sizetuple(fbo)
    fb = GLMakie.GLFramebuffer(fbosize)
    newscreen = new(
      Dict{WeakRef, ScreenID}(),
      ScreenArea[],
      Tuple{ZIndex, ScreenID, RenderObject}[],
      [
        enable_SSAO[] ? GLMakie.ssao_postprocessor(fb) : GLMakie.empty_postprocessor(),
        enable_FXAA[] ? GLMakie.fxaa_postprocessor(fb) : GLMakie.empty_postprocessor(),
        to_qmlscreen_postprocessor(fb)
      ],
      Dict{UInt64, RenderObject}(),
      Dict{UInt16, AbstractPlot}(),
      Matrix{RGB{N0f8}}(undef, fbosize),
      fb,
      # Observable(nothing),
      # Observable(true),
      fbo
    )
    finalizer(newscreen) do s
      empty!.((s.renderlist, s.screens, s.cache, s.screen2scene, s.cache2plot, s.postprocessors))
      return
    end
  end
end

Base.isopen(screen::QMLScreen) = true
GLMakie.GeometryBasics.widths(screen::QMLScreen) = sizetuple(screen.qmlfbo)

# From rendering.jl in GLMakie, with only slight adaptations
function GLMakie.render_frame(screen::QMLScreen; resize_buffers=true)
  w, h = sizetuple(screen.qmlfbo)
  fb = screen.framebuffer
  if resize_buffers
    resize!(fb, (w,h))
  end

  # prepare stencil (for sub-scenes)
  glEnable(GL_STENCIL_TEST)
  glBindFramebuffer(GL_FRAMEBUFFER, fb.id[1]) # color framebuffer
  glDrawBuffers(length(fb.render_buffer_ids), fb.render_buffer_ids)
  glEnable(GL_STENCIL_TEST)
  glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
  glStencilMask(0xff)
  glClearStencil(0)
  glClearColor(0, 0, 0, 0)
  glClear(GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT | GL_COLOR_BUFFER_BIT)
  glDrawBuffer(fb.render_buffer_ids[1])
  GLMakie.setup!(screen)
  glDrawBuffers(length(fb.render_buffer_ids), fb.render_buffer_ids)

  # render with FXAA & SSAO
  glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE)
  glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
  glStencilMask(0x00)
  GLAbstraction.render(screen, true, true)

  # SSAO
  screen.postprocessors[1].render(screen)

  # render with FXAA but no SSAO
  glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
  glEnable(GL_STENCIL_TEST)
  glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
  glStencilMask(0x00)
  GLAbstraction.render(screen, true, false)
  glDisable(GL_STENCIL_TEST)

  # FXAA
  screen.postprocessors[2].render(screen)

  # no FXAA primary render
  glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
  glEnable(GL_STENCIL_TEST)
  glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
  glStencilMask(0x00)
  GLAbstraction.render(screen, false)
  glDisable(GL_STENCIL_TEST)

  # transfer everything to the screen
  screen.postprocessors[3].render(screen)
  return
end

# Slightly adapted from GLMakie/postprocessing.jl/to_screen_postprocessor
function to_qmlscreen_postprocessor(framebuffer)
  # draw color buffer
  shader = LazyShader(
    GLMakie.loadshader("postprocessing/fullscreen.vert"),
    GLMakie.loadshader("postprocessing/copy.frag")
  )
  data = Dict{Symbol, Any}(
    :color_texture => framebuffer.buffers[:color]
  )
  pass = RenderObject(data, shader, GLMakie.PostprocessPrerender(), nothing)
  pass.postrenderfunction = () -> GLMakie.draw_fullscreen(pass.vertexarray.id)

  full_render = screen -> begin
    fb = screen.framebuffer
    w, h = sizetuple(screen.qmlfbo)
    # w, h = size(fb) # original from Makie

    QML.bind(screen.qmlfbo) # Transfer everything to the QMLScreen
    glViewport(0, 0, w, h)
    glClear(GL_COLOR_BUFFER_BIT)
    GLAbstraction.render(pass) # copy postprocess
  end
  GLMakie.PostProcessor([pass], full_render)
end

function Base.empty!(screen::QMLScreen)
    empty!(screen.renderlist)
    empty!(screen.screen2scene)
    empty!(screen.screens)
end

function Base.display(screen::QMLScreen, scene::Scene)
  scene.events.window_area[] = Makie.IRect(0,0,sizetuple(screen.qmlfbo)...)
  empty!(screen)
  insertplots!(screen, scene)
  Makie.update!(scene)
  GLMakie.render_frame(screen)
  return
end

function setup_screen(fbo)
  try
    old_ctx = GLMakie.GLAbstraction.current_context()
    old_ctx.valid = false
  catch
  end
  GLMakie.ShaderAbstractions.switch_context!(QMLGLContext(true, fbo))
  return QMLScreen(fbo)
end

function on_context_destroy()
  GLMakie.ShaderAbstractions.switch_context!()
  return
end

end
