import
  os,
  strformat

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

proc get4BytesToInt(file: File): int =
  var buffer: array[4, uint8]
  discard file.readBytes(buffer, 0, 4)
  result = int(buffer[0].shl(24) + buffer[1].shl(16) + buffer[2].shl(8) + buffer[3])

#常に13らしいのでそこのチェックを入れる
proc getChunkDataSize(file: File): int =
  result = file.get4BytesToInt
  if result != 13:
    quit("Chunk data size is not 13 byte", QuitFailure)

proc isIHDR(buffer: array[4, uint8]): bool =
  if buffer[0] != 0x49:
    return false
  if buffer[1] != 0x48:
    return false
  if buffer[2] != 0x44:
    return false
  if buffer[3] != 0x52:
    return false
  return true

proc readImageHeaderChunk(file: File) =
  let chunkDataSize = file.getChunkDataSize
  echo fmt"chunk data size: {chunkDataSize}"
  var chunkType: array[4, uint8]
  discard file.readBytes(chunkType, 0, 4)
  echo fmt"chunk type: {chunkType[0]:#x} {chunkType[1]:#x} {chunkType[2]:#x} {chunkType[3]:#x}"
  if not chunkType.isIHDR:
    quit("pngファイルシグネチャの後にIHDRがありません", QuitFailure)
  let width = file.get4BytesToInt
  let height = file.get4BytesToInt
  echo fmt"w:{width:>6}, h:{height:>6}"

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
    file.readImageHeaderChunk


when isMainModule:
  echo "==== read start ===="
  var filePath = "./sample/read.png"
  if fileExists(filePath):
    loadImage(filePath)
  else:
    echo "file not exists"
  echo "===== read end ====="
