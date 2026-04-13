using QML
using Test

qmlfile = joinpath(dirname(@__FILE__), "qml", "imageprovider.qml")

"""
    make_qimage_rgb888(rgb::NTuple{3, Integer}, width::Integer, height::Integer)
        -> (buf::Vector{UInt8}, bytes_per_line::Int)

Create a flat `Vector{UInt8}` containing pixel data for a solid-color image in
**QImage::Format_RGB888** (3 bytes/pixel in R, G, B order), laid out row-major.

Returns the buffer and `bytes_per_line` (stride) which you pass to `QImage`.

Notes:
- The buffer is tightly packed: `bytes_per_line == 3 * width`.
- Keep a Julia reference to `buf` alive for as long as Qt may read it,
  unless your C++ side deep-copies the image data.
"""
function make_qimage_rgb888(rgb::NTuple{3, Integer}, width::Integer, height::Integer)
  w = Int(width);  h = Int(height)
  (w > 0 && h > 0) || throw(ArgumentError("width and height must be positive"))

  r = UInt8(clamp(rgb[1], 0, 255))
  g = UInt8(clamp(rgb[2], 0, 255))
  b = UInt8(clamp(rgb[3], 0, 255))

  bytes_per_line = 3 * w
  buf = Vector{UInt8}(undef, h * bytes_per_line)

  # Build one scanline and copy it h times — fast and branch-free
  @inbounds begin
    row = Vector{UInt8}(undef, bytes_per_line)
    for x in 0:w-1
      i = 3x + 1
      row[i]   = r
      row[i+1] = g
      row[i+2] = b
    end
    for y in 0:h-1
      dest = y * bytes_per_line + 1
      copyto!(buf, dest, row, 1, bytes_per_line)
    end
  end

  return buf, bytes_per_line
end

function image_callback(id, requestedwidth, requestedheight)
  width = requestedwidth <= 0 ? 100 : requestedwidth
  height = requestedheight <= 0 ? 100 : requestedheight

  color = (0,0,0)
  if id[] == "yellow"
      color = (255,255,0)
  elseif id[] == "red"
      color = (255,0,0)
  end

  buf, stride = make_qimage_rgb888(color, width, height)
  image = QImage(pointer(buf), width, height, stride, QML.Format_RGB888)
  return deepcopy(image), width, height
end

function pixmap_callback(id, requestedwidth, requestedheight)
  width = requestedwidth <= 0 ? 100 : requestedwidth
  height = requestedheight <= 0 ? 100 : requestedheight

  pixmap = QPixmap(width, height)
  QML.fill(pixmap, QColor(id))

  return pixmap, width, height
end

imageprovider = ImageProvider(QML.Image, image_callback)
pixmapprovider = ImageProvider(QML.Pixmap, pixmap_callback)
engine = init_qmlapplicationengine()

addImageProvider(engine, "images", imageprovider)
addImageProvider(engine, "pixmaps", pixmapprovider)

loadqml(engine, qmlfile)
exec()

