import
  os

#[ 画像を配列として読み込む手順（予定）http://www.snap-tck.com/room03/c02/cg/cg07_02.html
  1. pngであることの確認 -> PNGヘッダ
  2. png画像の基本情報を取得 -> IHDRチャンク
  3. 画像データの読み込み -> IDATチャンク
  4. 終端子の確認 -> IENDチャンク
]#

proc isPngImage(buffer: array[8, uint8]): bool =
  if buffer[0] != 0x89:
    return false
  if buffer[1] != 0x50:
    return false
  if buffer[2] != 0x4E:
    return false
  if buffer[3] != 0x47:
    return false
  if buffer[4] != 0x0D:
    return false
  if buffer[5] != 0x0A:
    return false
  if buffer[6] != 0x1A:
    return false
  if buffer[7] != 0x0A:
    return false
  return true


proc loadImage(path: string) =
  block:
    let file: File = open(path, fmRead)
    defer:
      file.close()
    echo "file size is ", file.getFileSize
    if file.getFileSize < 45:
      echo "ファイルの基本情報が足りていない"
    var buffer: array[8, uint8]
    discard file.readBuffer(buffer.addr, 8)
    if not buffer.isPngImage:
      echo "file is not png format"
      return
    echo "this is png file!"


when isMainModule:
  echo "==== read start ===="
  var filePath = "./sample/read.png"
  if fileExists(filePath):
    loadImage(filePath)
  else:
    echo "file not exists"
  echo "===== read end ====="
