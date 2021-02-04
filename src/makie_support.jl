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
  cache::Dict{UInt64, RenderObject}
  cache2plot::Dict{UInt16, AbstractPlot}
  framecache::Tuple{Matrix{RGB{N0f8}}, Matrix{RGB{N0f8}}}
  framebuffer::GLMakie.GLFramebuffer
  qmlfbo::QML.QOpenGLFramebufferObject

  @cxxdereference function QMLScreen(fbo::QML.QOpenGLFramebufferObject)
    fbosize = sizetuple(fbo)
    newscreen = new(
      Dict{WeakRef, ScreenID}(),
      ScreenArea[],
      Tuple{ZIndex, ScreenID, RenderObject}[],
      Dict{UInt64, RenderObject}(),
      Dict{UInt16, AbstractPlot}(),
      (Matrix{RGB{N0f8}}(undef, fbosize), Matrix{RGB{N0f8}}(undef, reverse(fbosize))),
      GLMakie.GLFramebuffer(fbosize),
      fbo
    )
    finalizer(newscreen) do s
      empty!.((s.renderlist, s.screens, s.cache, s.screen2scene, s.cache2plot))
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
  glDrawBuffers(4, [
    GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1,
    GL_COLOR_ATTACHMENT2, GL_COLOR_ATTACHMENT3
  ])
  glEnable(GL_STENCIL_TEST)
  glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
  glStencilMask(0xff)
  glClearStencil(0)
  glClearColor(0,0,0,0)
  glClear(GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT | GL_COLOR_BUFFER_BIT)
  GLMakie.setup!(screen)

  # render with FXAA & SSAO
  glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE)
  glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
  glStencilMask(0x00)
  GLAbstraction.render(screen, true, true)

  # SSAO - calculate occlusion
  glDrawBuffer(GL_COLOR_ATTACHMENT4)  # occlusion buffer
  glViewport(0, 0, w, h)
  glClearColor(1, 1, 1, 1)            # 1 means no darkening
  glClear(GL_COLOR_BUFFER_BIT)

  for (screenid, scene) in screen.screens
    # update uniforms
    SSAO = scene.SSAO
    uniforms = fb.postprocess[1].uniforms
    uniforms[:projection][] = scene.camera.projection[]
    uniforms[:bias][] = Float32(to_value(get(SSAO, :bias, 0.025)))
    uniforms[:radius][] = Float32(to_value(get(SSAO, :radius, 0.5)))
    # use stencil to select one scene
    glStencilFunc(GL_EQUAL, screenid, 0xff)
    GLAbstraction.render(fb.postprocess[1])
  end

  # SSAO - blur occlusion and apply to color
  glDrawBuffer(GL_COLOR_ATTACHMENT0)  # color buffer
  for (screenid, scene) in screen.screens
    # update uniforms
    SSAO = scene.attributes.SSAO
    uniforms = fb.postprocess[2].uniforms
    uniforms[:blur_range][] = Int32(to_value(get(SSAO, :blur, 2)))

    # use stencil to select one scene
    glStencilFunc(GL_EQUAL, screenid, 0xff)
    GLAbstraction.render(fb.postprocess[2])
  end
  glDisable(GL_STENCIL_TEST)

  # render with FXAA but no SSAO
  glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
  glEnable(GL_STENCIL_TEST)
  glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
  glStencilMask(0x00)
  GLAbstraction.render(screen, true, false)
  glDisable(GL_STENCIL_TEST)

  # FXAA - calculate LUMA
  glBindFramebuffer(GL_FRAMEBUFFER, fb.id[2])
  glDrawBuffer(GL_COLOR_ATTACHMENT0)  # color_luma buffer
  glViewport(0, 0, w, h)
  # necessary with negative SSAO bias...
  glClearColor(1, 1, 1, 1)
  glClear(GL_COLOR_BUFFER_BIT)
  GLAbstraction.render(fb.postprocess[3])

  # FXAA - perform anti-aliasing
  glBindFramebuffer(GL_FRAMEBUFFER, fb.id[1])
  glDrawBuffer(GL_COLOR_ATTACHMENT0)  # color buffer
  # glViewport(0, 0, w, h) # not necessary
  GLAbstraction.render(fb.postprocess[4])

  # no FXAA primary render
  glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
  glEnable(GL_STENCIL_TEST)
  glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
  glStencilMask(0x00)
  GLAbstraction.render(screen, false)
  glDisable(GL_STENCIL_TEST)

  # transfer everything to the screen, which in QML is the QOpenGLFramebufferObject we are rendering to
  QML.bind(screen.qmlfbo)
  glViewport(0, 0, w, h)
  glClear(GL_COLOR_BUFFER_BIT)
  GLAbstraction.render(fb.postprocess[5]) # copy postprocess

  return
end

function Base.display(screen::QMLScreen, scene::Scene)
  scene.events.window_area[] = AbstractPlotting.IRect(0,0,sizetuple(screen.qmlfbo)...)
  empty!(screen)
  insertplots!(screen, scene)
  AbstractPlotting.update!(scene)
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
