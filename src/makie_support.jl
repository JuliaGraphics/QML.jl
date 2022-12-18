module MakieSupport

using ..GLMakie
using ..GLMakie.Colors
using ..GLMakie.FixedPointNumbers
using ..GLMakie.ModernGL
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

function GLMakie.ShaderAbstractions.native_switch_context!(ctx::QMLGLContext)
  if !ctx.valid
    try
      error("Attempt to bind invalid context $ctx")
    catch e
      Base.printstyled("ERROR: "; color=:red, bold=true)
      Base.showerror(stdout, e)
      Base.show_backtrace(stdout, Base.catch_backtrace())
    end
  end
  QML.bind(ctx.fbo)
end

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
  glscreen::QMLGLContext
  shader_cache::GLAbstraction.ShaderCache
  screen2scene::Dict{WeakRef, ScreenID}
  screens::Vector{ScreenArea}
  renderlist::Vector{Tuple{ZIndex, ScreenID, RenderObject}}
  postprocessors::Vector{GLMakie.PostProcessor}
  cache::Dict{UInt64, RenderObject}
  cache2plot::Dict{UInt32, AbstractPlot}
  framecache::Matrix{RGB{N0f8}}
  framebuffer::GLMakie.GLFramebuffer
  # render_tick::Observable{Nothing}
  # window_open::Observable{Bool}

  @cxxdereference function QMLScreen(fbo::QML.QOpenGLFramebufferObject)
    ctx = QMLGLContext(true, CxxPtr(fbo))
    GLMakie.ShaderAbstractions.switch_context!(ctx)
    fbosize = sizetuple(fbo)
    fb = GLMakie.GLFramebuffer(fbosize)
    shader_cache = GLAbstraction.ShaderCache()
    newscreen = new(
      ctx,
      shader_cache,
      Dict{WeakRef, ScreenID}(),
      ScreenArea[],
      Tuple{ZIndex, ScreenID, RenderObject}[],
      [
        enable_SSAO[] ? GLMakie.ssao_postprocessor(fb, shader_cache) : GLMakie.empty_postprocessor(),
        GLMakie.OIT_postprocessor(fb, shader_cache),
        enable_FXAA[] ? GLMakie.fxaa_postprocessor(fb, shader_cache) : GLMakie.empty_postprocessor(),
        to_qmlscreen_postprocessor(fb, shader_cache)
      ],
      Dict{UInt64, RenderObject}(),
      Dict{UInt32, AbstractPlot}(),
      Matrix{RGB{N0f8}}(undef, fbosize),
      fb,
      # Observable(nothing),
      # Observable(true),
    )
    finalizer(newscreen) do s
      empty!.((s.renderlist, s.screens, s.cache, s.screen2scene, s.cache2plot, s.postprocessors))
      return
    end
  end
end

function update_fbo!(screen, fbo)
  screen.glscreen.fbo = CxxPtr(fbo)
  GLMakie.ShaderAbstractions.switch_context!(screen.glscreen)
  fbosize = sizetuple(fbo)
  resize!(screen.framebuffer, fbosize)
  screen.framecache = Matrix{RGB{N0f8}}(undef, fbosize)
  return screen
end

Base.isopen(screen::QMLScreen) = true
GLMakie.GeometryBasics.widths(screen::QMLScreen) = sizetuple(screen.glscreen.fbo)

# From rendering.jl in GLMakie, with only slight adaptations
function GLMakie.render_frame(screen::QMLScreen; resize_buffers=true)
  w, h = sizetuple(screen.glscreen.fbo)
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
  GLAbstraction.render(screen) do robj
    return !Bool(robj[:transparency][]) && Bool(robj[:ssao][])
  end
  # SSAO
  screen.postprocessors[1].render(screen)

  # render with FXAA but no SSAO
  glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
  glEnable(GL_STENCIL_TEST)
  glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
  glStencilMask(0x00)
  # render all non ssao
  GLAbstraction.render(screen) do robj
    return !Bool(robj[:transparency][]) && !Bool(robj[:ssao][])
  end
  glDisable(GL_STENCIL_TEST)

  # TRANSPARENT RENDER
  # clear sums to 0
  glDrawBuffer(GL_COLOR_ATTACHMENT2)
  glClearColor(0, 0, 0, 0)
  glClear(GL_COLOR_BUFFER_BIT)
  # clear alpha product to 1
  glDrawBuffer(GL_COLOR_ATTACHMENT3)
  glClearColor(1, 1, 1, 1)
  glClear(GL_COLOR_BUFFER_BIT)
  # draw
  glDrawBuffers(3, [GL_COLOR_ATTACHMENT2, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT3])
  glEnable(GL_STENCIL_TEST)
  glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
  glStencilMask(0x00)
  # Render only transparent objects
  GLAbstraction.render(screen) do robj
      return Bool(robj[:transparency][])
  end
  glDisable(GL_STENCIL_TEST)

  # TRANSPARENT BLEND
  screen.postprocessors[2].render(screen)

  # FXAA
  screen.postprocessors[3].render(screen)

  # transfer everything to the screen
  screen.postprocessors[4].render(screen)
end

# Slightly adapted from GLMakie/postprocessing.jl/to_screen_postprocessor
function to_qmlscreen_postprocessor(framebuffer, shader_cache)
  # draw color buffer
  shader = LazyShader(
    shader_cache,
    GLMakie.loadshader("postprocessing/fullscreen.vert"),
    GLMakie.loadshader("postprocessing/copy.frag")
  )
  data = Dict{Symbol,Any}(
    :color_texture => framebuffer.buffers[:color]
  )
  pass = RenderObject(data, shader, GLMakie.PostprocessPrerender(), nothing)
  pass.postrenderfunction = () -> GLMakie.draw_fullscreen(pass.vertexarray.id)

  full_render = screen -> begin
    fb = screen.framebuffer
    w, h = sizetuple(screen.glscreen.fbo)
    # w, h = size(fb) # original from Makie

    QML.bind(screen.glscreen.fbo) # Transfer everything to the QMLScreen
    glViewport(0, 0, w, h)
    glClear(GL_COLOR_BUFFER_BIT)
    GLAbstraction.render(pass) # copy postprocess
  end
  return GLMakie.PostProcessor(GLMakie.GLAbstraction.RenderObject[pass], full_render)
end

function Base.empty!(screen::QMLScreen)
    empty!(screen.renderlist)
    empty!(screen.screen2scene)
    empty!(screen.screens)
end

function Base.display(screen::QMLScreen, scene::Scene)
  scene.events.window_area[] = Makie.IRect(0,0,sizetuple(screen.glscreen.fbo)...)
  empty!(screen)
  insertplots!(screen, scene)
  # Makie.update!(scene)
  GLMakie.render_frame(screen)
  return
end

function setup_screen(fbo)
  return QMLScreen(fbo)
end

function setup_screen(screen, fbo)
  update_fbo!(screen, fbo)
  return screen
end

function on_context_destroy()
  GLMakie.ShaderAbstractions.switch_context!()
  return
end

end
