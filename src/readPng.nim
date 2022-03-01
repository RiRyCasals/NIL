import
  os,
  strformat,
  endians

#[ 画像を配列として読み込む手順（予定）http://www.snap-tck.com/room03/c02/cg/cg07_02.html
  1. pngであることの確認 -> PNGヘッダ
  2. png画像の基本情報を取得 -> IHDRチャンク
  3. パレット情報の取得 -> PLTEチャンク（カラー画像のときに存在？）
  4. 画像データの読み込み -> IDATチャンク
  5. 終端子の確認 -> IENDチャンク

  ## もっと細かく ##
  1. PNGファイルシグネチャの確認
    a. 8バイト取得
       i. 16進数で 89 50 4E 47 0D 0A 1A 0A なら次へ
      ii. それ以外なら終了
  2. IHDRチャンクの確認
    a. 4バイト取得: チャンクデータサイズ
      * 13バイト
    b. 4バイト取得: チャンクタイプ
      * 16進数で 49 48 44 52
        - 4バイト取得: 画像の幅
        - 4バイト取得: 画像の高さ
        - 1バイト取得: ビット深度（1, 2, 4, 8, 16）
        - 1バイト取得: カラータイプ（0, 2, 3, 4, 6）
        - 1バイト取得: 圧縮手法
        - 1バイト取得: フィルター手法
        - 1バイト取得: インターレース手法
        - 4バイト取得: CRC32（単調巡回検査）
  3. while: IENDに到達する か IENDを取得できずにファイル長を超える まで
    a. 4バイト取得: チャンクデータサイズ
    b. 4バイト取得: チャンクタイプ
      * 16進数で 50 4C 54 45 かつ チャンクデータサイズが3で割り切れる かつ IHDRのカラータイプが3 かつ IHDRのビット深度が1,2,4,8のいずれか なら PLTE として読み取りを行う
      * 16進数で 49 44 41 54 なら IDAT
      * 16進数で 49 45 4E 44 かつ チャンクデータサイズが0バイト なら IEND
]#

const PngSignature = 0x89504E470D0A1A0A
const IhdrType = 0x49484452
const PlteType = 0x504C5445
const IdatType = 0x49444154
const IendType = 0x49454E44

proc toBigEndian32(bufferPointer: pointer): int =
  #windowsとかでこのあたり違ってきそう
  bigEndian32(result.addr, bufferPointer)

proc toBigEndian64(bufferPointer: pointer): int =
  #windowsとかでこのあたり違ってきそう
  bigEndian64(result.addr, bufferPointer)

proc isPngImage(bufferPointer: pointer): bool =
  let bigEndianBuffer = toBigEndian64(bufferPointer)
  if bigEndianBuffer == PngSignature:
    return true
  return false

proc isIHDR(bufferPointer: pointer): bool =
  let bigEndianBuffer = toBigEndian32(bufferPointer)
  if bigEndianBuffer == IhdrType:
    return true
  return false

proc isPLTE(bufferPointer: pointer): bool =
  let bigEndianBuffer = toBigEndian32(bufferPointer)
  if bigEndianBuffer == PlteType:
    return true
  return false

proc isIDAT(bufferPointer: pointer): bool =
  let bigEndianBuffer = toBigEndian32(bufferPointer)
  if bigEndianBuffer == IdatType:
    return true
  return false

proc isIEND(bufferPointer: pointer): bool =
  let bigEndianBuffer = toBigEndian32(bufferPointer)
  if bigEndianBuffer == IendType:
    return true
  return false

proc get4BytesToInt(file: File): int =
  var buffer: array[4, uint8]
  let readLength = file.readBytes(buffer, 0, 4)
  if readLength != 4:
    quit("can not read 4 bytes", QuitFailure)
  #buffer[0].shl(24)だとoverflowする
  result = int(buffer[0]).shl(24) + int(buffer[1]).shl(16) + int(buffer[2]).shl(8) + int(buffer[3])

proc readPngSigneture(file: File) =
  var buffer: int
  let readLength = file.readBuffer(buffer.addr, 8)
  if readLength != 8:
    #quit より raise???
    quit("can not read 8 bytes", QuitFailure)
  if not isPngImage(buffer.addr):
    #quit より raise???
    quit("file is not png format", QuitFailure)

# chunkDataSizeとchunkTypeは外に出すべき
proc readIhdrChunk(file: File) =
  echo "==== IHDR ===="
  let chunkDataSize = file.get4BytesToInt
  if chunkDataSize != 13:
    quit("IHDR chunk data size is not 13 bytes", QuitFailure)
  echo fmt"chunk data size: {chunkDataSize}"
  #[
  var chunkType: array[4, uint8] #外で読んで判断したほうがいい希ガス
  discard file.readBytes(chunkType, 0, 4) #何バイト取得できたか検証したほうがいい
  echo fmt"chunk type: {char(chunkType[0])} {char(chunkType[1])} {char(chunkType[2])} {char(chunkType[3])}"
  ]#
  var chunkType: int
  discard file.readBuffer(chunkType.addr, 4)
  if not isIHDR(chunkType.addr):
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

proc readPlteChunk(file: File) =
  let chunkDataSize = file.get4BytesToInt
  if chunkDataSize mod 3 != 0:
    quit("PLTE chunk data size is not multiple of 3", QuitFailure)
  echo fmt"chunk data size: {chunkDataSize}"
  #[
  var chunkType: array[4, uint8] #外で読んで判断したほうがいい希ガス
  discard file.readBytes(chunkType, 0, 4) #何バイト取得できたか検証したほうがいい
  echo fmt"chunk type: {char(chunkType[0])} {char(chunkType[1])} {char(chunkType[2])} {char(chunkType[3])}"
  ]#
  var chunkType: int
  discard file.readBuffer(chunkType.addr, 4)
  if not isPLTE(chunkType.addr):
    #quit より raise???
    quit("PLTEではありません", QuitFailure)
  #array[chunkDataSize, uint8] だとコンパイルできない
  var chunkData: seq[uint8] = @[]
  chunkData.setLen(chunkDataSize)
  discard file.readBytes(chunkData, 0, chunkDataSize)
  let cyclicRedundancyCheck = file.get4BytesToInt
  echo fmt"CRC: {cyclicRedundancyCheck}, ({cyclicRedundancyCheck:#x})"

#seqを返す予定（IDATが複数の時，変換先で結合）
proc readIdatChunk(file: File) =
  let chunkDataSize = file.get4BytesToInt
  echo fmt"chunk data size: {chunkDataSize}"
  #[
  var chunkType: array[4, uint8] #外で読んで判断したほうがいい希ガス
  discard file.readBytes(chunkType, 0, 4) #何バイト取得できたか検証したほうがいい
  echo fmt"chunk type: {char(chunkType[0])} {char(chunkType[1])} {char(chunkType[2])} {char(chunkType[3])}"
  ]#
  var chunkType: int
  discard file.readBuffer(chunkType.addr, 4)
  if not isIDAT(chunkType.addr):
    #quit より raise???
    quit("IDATではありません", QuitFailure)
  #array[chunkDataSize, uint8] だとコンパイルできない
  var chunkData: seq[uint8] = @[]
  chunkData.setLen(chunkDataSize)
  discard file.readBytes(chunkData, 0, chunkDataSize)
  let cyclicRedundancyCheck = file.get4BytesToInt
  echo fmt"CRC: {cyclicRedundancyCheck}, ({cyclicRedundancyCheck:#x})"

proc readIendChunk(file: File) =
  let chunkDataSize = file.get4BytesToInt
  if chunkDataSize != 0:
    quit("IEND chunk data size is not 0 bytes", QuitFailure)
  #[
  var chunkType: array[4, uint8] #外で読んで判断したほうがいい希ガス
  discard file.readBytes(chunkType, 0, 4) #何バイト取得できたか検証したほうがいい
  echo fmt"chunk type: {char(chunkType[0])} {char(chunkType[1])} {char(chunkType[2])} {char(chunkType[3])}"
  ]#
  var chunkType: int
  discard file.readBuffer(chunkType.addr, 4)
  if not isIEND(chunkType.addr):
    #quit より raise???
    quit("IENDではありません", QuitFailure)
  let cyclicRedundancyCheck = file.get4BytesToInt
  echo fmt"CRC: {cyclicRedundancyCheck}, ({cyclicRedundancyCheck:#x})"

#画像データの2次元配列を返す予定
proc loadImage(path: string) =
  block:
    let file: File = open(path, fmRead)
    defer:
      file.close()
    let fileSize = file.getFileSize
    echo "file size is ", fileSize
    if fileSize < 45:
      #quit より raise???
      quit("ファイルの基本情報が足りていない", QuitFailure)
    file.readPngSigneture
    file.readIhdrChunk
    #IENDを引くかfileをすべて見終わるまでwhileで回す
    echo "==== PLTE ===="
    file.readPlteChunk
    echo "==== IDAT ===="
    file.readIdatChunk
    echo "==== IEND ===="
    file.readIendChunk

when isMainModule:
  echo "==== read start ===="
  var filePath = "./sample/read.png"
  if fileExists(filePath):
    loadImage(filePath)
  else:
    echo "file not exists"
  echo "===== read end ====="
