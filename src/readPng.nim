import
  os,
  strformat,
  sequtils

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

type
  ImageHeader = object
    width: int
    height: int
    bitDepth:int
    colorType: int
    compressionMethod: int
    filterMethod: int
    interlaceMethod: int

const PngSignature1 = 0x89504E47
const PngSignature2 = 0x0D0A1A0A
const IhdrType = 0x49484452
const PlteType = 0x504C5445
const IdatType = 0x49444154
const IendType = 0x49454E44

proc isPngSigneture(pngSigneture1, pngSigneture2: int64): bool =
  if pngSigneture1 != PngSignature1 or pngSigneture2 != PngSignature2:
    return false
  return true

proc isIHDR(chunkTypeBuffer: int, chunkDataLength: int): bool =
  if chunkDataLength != 13:
    return false
  if chunkTypeBuffer != IhdrType:
    return false
  return true

proc isPLTE(chunkTypeBuffer: int, chunkDataLength, colorType: int): bool =
  if colorType != 3 or chunkDataLength mod 3 != 0:
    return false
  if chunkTypeBuffer != PlteType:
    return false
  return true

proc isIDAT(chunkTypeBuffer: int): bool =
  if chunkTypeBuffer != IdatType:
    return false
  return true

proc isIEND(chunkTypeBuffer: int, chunkDataLength: int): bool =
  if chunkDataLength != 0:
    return false
  if chunkTypeBuffer != IendType:
    return false
  return true

proc toInt(buffer: array[4, uint8]): int=
  for i, element in buffer:
    result += int(element).shl(8*(3-i))
  
proc get4BytesToInt(file: File): int =
  var buffer: array[4, uint8]
  let readLength = file.readBytes(buffer, 0, 4)
  if readLength != 4:
    quit("can not read 4 bytes", QuitFailure)
  result = buffer.toInt

proc readCrc(file: File): int =
  result = file.get4BytesToInt #データ破損の確認用

proc readIhdrChunk(file: File): ImageHeader =
  echo "==== IHDR ===="
  var imageHeader: ImageHeader
  imageHeader.width = file.get4BytesToInt
  imageHeader.height = file.get4BytesToInt
  discard file.readBuffer(imageHeader.bitDepth.addr, 1) #何バイト取得できたか検証したほうがいい
  discard file.readBuffer(imageHeader.colorType.addr, 1) #何バイト取得できたか検証したほうがいい
  discard file.readBuffer(imageHeader.compressionMethod.addr, 1) #何バイト取得できたか検証したほうがいい
  discard file.readBuffer(imageHeader.filterMethod.addr, 1) #何バイト取得できたか検証したほうがいい
  discard file.readBuffer(imageHeader.interlaceMethod.addr, 1) #何バイト取得できたか検証したほうがいい
  let cyclicRedundancyCheck = file.readCrc
  return imageHeader

proc readPlteChunk(file: File, chunkDataLength: int): seq[uint8] =
  echo "==== PLTE ===="
  #array[chunkDataSize, uint8] だとコンパイルできない
  var palette: seq[uint8] = @[]
  palette.setLen(chunkDataLength)
  let readLength = file.readBytes(palette, 0, chunkDataLength)
  if readLength != chunkDataLength:
    quit("can not read PLTE chunk data", QuitFailure)
  let cyclicRedundancyCheck = file.readCrc
  return palette

proc readIdatChunk(file: File, chunkDataLength: int): seq[uint8] =
  echo "==== IDAT ===="
  #array[chunkDataSize, uint8] だとコンパイルできない
  var image: seq[uint8] = @[]
  image.setLen(chunkDataLength)
  let readLength = file.readBytes(image, 0, chunkDataLength)
  if readLength != chunkDataLength:
    quit("can not read PLTE chunk data", QuitFailure)
  let cyclicRedundancyCheck = file.readCrc
  return image


proc loadImage(path: string): seq[uint8] =
  block:
    let
      file = open(path, fmRead)
      fileSize = file.getFileSize
    defer:
      file.close()
    let
      pngSigneture1 = file.get4BytesToInt
      pngSigneture2 = file.get4BytesToInt
    if not isPngSigneture(pngSigneture1, pngSigneture2):
      #quit より raise???
      quit("this is not png file", QuitFailure)
    var
      chunkDataLength = file.get4BytesToInt
      chunkType = file.get4BytesToInt
    if not isIHDR(chunkType, chunkDataLength):
      #quit より raise???
      quit("this is not IHDR chunk", QuitFailure)
    let imageHeader = file.readIhdrChunk
    var palette, image: seq[uint8] = @[]
    while file.getFilePos <= fileSize: #fileSizeを超えてreadBufferやreadBytesはされない
      chunkDataLength = file.get4BytesToInt
      chunkType = file.get4BytesToInt
      if isPLTE(chunkType, chunkDataLength, imageHeader.colorType):
        palette = readPlteChunk(file, chunkDataLength)
      elif isIDAT(chunkType):
        image = concat(image, readIdatChunk(file, chunkDataLength))
      elif isIEND(chunkType, chunkDataLength):
        echo "==== IEND ===="
        break
      else:
        var devnul: int8
        discard file.readBuffer(devnul.addr, chunkDataLength)
        discard file.readCrc
    return image

when isMainModule:
  echo "==== read start ===="
  var filePath = "./sample/read.png"
  var image: seq[uint8] = @[]
  if fileExists(filePath):
    image = loadImage(filePath)
  else:
    echo "file not exists"
  echo "===== read end ====="
  echo $image
