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
  #これもっとまとめられないだろうか？
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

#これとgetChunkDataSizeの名称とまとめ方をどうにかしたい
proc get4BytesToInt(file: File): int =
  var buffer: array[4, uint8]
  discard file.readBytes(buffer, 0, 4) #何バイト取得できたか検証したほうがいい
  result = int(buffer[0].shl(24) + buffer[1].shl(16) + buffer[2].shl(8) + buffer[3])

proc getIHDRChunkDataSize(file: File): int =
  result = file.get4BytesToInt
  if result != 13:
    #quit より raise???
    quit("Chunk data size is not 13 byte", QuitFailure)

proc getPLTEChunkDataSize(file: File): int =
  result = file.get4BytesToInt
  if result mod 3 != 0:
    #quit より raise???
    quit("Chunk data size is not multiple of 3", QuitFailure)

proc isIHDR(buffer: array[4, uint8]): bool =
  #これもっとまとめられないだろうか？
  if buffer[0] != 0x49:
    return false
  if buffer[1] != 0x48:
    return false
  if buffer[2] != 0x44:
    return false
  if buffer[3] != 0x52:
    return false
  return true

proc isPLTE(buffer: array[4, uint8]): bool =
  #これもっとまとめられないだろうか？
  if buffer[0] != 0x50:
    return false
  if buffer[1] != 0x4C:
    return false
  if buffer[2] != 0x54:
    return false
  if buffer[3] != 0x45:
    return false
  return true

# chunkDataSizeとchunkTypeは外に出すべき
proc readImageHeaderChunk(file: File) =
  let chunkDataSize = file.getIHDRChunkDataSize
  echo fmt"chunk data size: {chunkDataSize}"
  var chunkType: array[4, uint8] #外で読んで判断したほうがいい希ガス
  discard file.readBytes(chunkType, 0, 4) #何バイト取得できたか検証したほうがいい
  echo fmt"chunk type: {char(chunkType[0])} {char(chunkType[1])} {char(chunkType[2])} {char(chunkType[3])}"
  if not chunkType.isIHDR:
    #quit より raise???
    quit("pngファイルシグネチャの後にIHDRがありません", QuitFailure)
  let width = file.get4BytesToInt
  let height = file.get4BytesToInt
  echo fmt"w:{width:>6}, h:{height:>6}"
  var buffer1bytesChunk: array[5, uint8]
  for i in 0..<5:
    discard file.readBuffer(buffer1bytesChunk[i].addr, 1) #何バイト取得できたか検証したほうがいい
  echo $buffer1bytesChunk
  let cyclicRedundancyCheck = file.get4BytesToInt
  echo fmt"CRC: {cyclicRedundancyCheck}, ({cyclicRedundancyCheck:#x})"

proc readPalette(file: File) =
  let chunkDataSize = file.getPLTEChunkDataSize
  echo fmt"chunk data size: {chunkDataSize}"
  var chunkType: array[4, uint8] #外で読んで判断したほうがいい希ガス
  discard file.readBytes(chunkType, 0, 4) #何バイト取得できたか検証したほうがいい
  echo fmt"chunk type: {char(chunkType[0])} {char(chunkType[1])} {char(chunkType[2])} {char(chunkType[3])}"
  if not chunkType.isPLTE:
    #quit より raise???
    quit("PLTEではありません", QuitFailure)
  #array[chunkDataSize, uint8] だとコンパイルできない
  var chunkData: seq[uint8] = @[]
  chunkData.setLen(chunkDataSize)
  discard file.readBytes(chunkData, 0, chunkDataSize)
  let cyclicRedundancyCheck = file.get4BytesToInt
  echo fmt"CRC: {cyclicRedundancyCheck}, ({cyclicRedundancyCheck:#x})"

proc loadImage(path: string) =
  block:
    let file: File = open(path, fmRead)
    defer:
      file.close()
    echo "file size is ", file.getFileSize
    if file.getFileSize < 45:
      #quit より raise???
      quit("ファイルの基本情報が足りていない", QuitFailure)
    var buffer: array[8, uint8]
    discard file.readBuffer(buffer.addr, 8)
    if not buffer.isPngImage:
      echo "file is not png format"
      return
    echo "this is png file!"
    echo "==== IHDR ===="
    file.readImageHeaderChunk
    echo "==== PLTE ===="
    file.readPalette


when isMainModule:
  echo "==== read start ===="
  var filePath = "./sample/read.png"
  if fileExists(filePath):
    loadImage(filePath)
  else:
    echo "file not exists"
  echo "===== read end ====="
