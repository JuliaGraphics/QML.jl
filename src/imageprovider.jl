export ImageProvider, QImage, QPixmap, QColor, QSize, setcallback, addImageProvider

# Wrapper for the C++ type for easier construction and
# keeping a reference to the callback to prevent GC
mutable struct ImageProvider
  provider::JuliaImageProvider # The C++ object
  callback

  function ImageProvider(imagetype, callback)
    provider_cpp = JuliaImageProvider(imagetype)
    provider = new(provider_cpp)
    setcallback(provider, callback)
    return provider
  end
end

function setcallback(provider, callback)
  callback_imageresult(id, w, h) = ImageResult(callback(id, w, h)...)
  callback_c = @CxxWrap.safe_cfunction($callback_imageresult, Any, (ConstCxxRef{QString},Cint,Cint))
  set_callback(provider.provider, callback_c)
  provider.callback = callback_c
  return
end

Base.deepcopy(image::QImage) = QML.copy(image)

@cxxdereference addImageProvider(engine, id, provider::ImageProvider) = QML.addImageProvider(engine, id, CxxPtr(provider.provider))

ImageResult(image::QImage, width, height) = QML.ImageResult{QImage}(image, Int32(width), Int32(height))
ImageResult(image::QPixmap, width, height) = QML.ImageResult{QPixmap}(image, Int32(width), Int32(height))
