#!/bin/bash
set -e

# —— 安装多架构支持（若已安装可注释掉） —— #
# sudo apt update && sudo apt install -y gcc-multilib g++-multilib libc6-dev-i386

# —— 自动定位 Android NDK 根目录 —— #
NDK_BASE=/opt/android/ndk
NDK=$(ls -d $NDK_BASE/android-ndk-* 2>/dev/null | sort | head -n1)
if [ -z "$NDK" ] || [ ! -d "$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin" ]; then
  echo "Error: 未找到有效的 NDK 目录，请检查 /opt/android/ndk 下的安装。" >&2
  exit 1
fi
echo "🛠 使用 NDK: $NDK"

NDK_BIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin
API=21
OUTDIR=build

# —— 克隆 LuaJIT（如需指定镜像源可自行更改） —— #
if [ ! -d LuaJIT ]; then
  echo "===> Cloning LuaJIT v2.1.ROLLING..."
  git clone https://github.com/LuaJIT/LuaJIT.git
  cd LuaJIT
  git checkout v2.1
  cd ..
fi

cd LuaJIT
rm -rf $OUTDIR
mkdir -p $OUTDIR

build_arch(){
  ABI=$1
  echo -e "\n===> Building for $ABI..."

  case $ABI in
    armeabi-v7a)
      TARGET=armv7a-linux-androideabi
      HOST_CC="gcc -m32"
      ;;
    x86)
      TARGET=i686-linux-android
      HOST_CC="gcc -m32"
      ;;
    arm64-v8a)
      TARGET=aarch64-linux-android
      HOST_CC="gcc"
      ;;
    x86_64)
      TARGET=x86_64-linux-android
      HOST_CC="gcc"
      ;;
    *)
      echo "Unsupported ABI: $ABI"
      exit 1
      ;;
  esac

  make clean

  make \
    HOST_CC="$HOST_CC" \
    CROSS=$NDK_BIN/${TARGET}- \
    STATIC_CC="$NDK_BIN/clang --target=${TARGET}${API}" \
    DYNAMIC_CC="$NDK_BIN/clang --target=${TARGET}${API} -fPIC" \
    TARGET_LD="$NDK_BIN/clang --target=${TARGET}${API}" \
    TARGET_AR="$NDK_BIN/llvm-ar rcus" \
    TARGET_STRIP="$NDK_BIN/llvm-strip"

  mkdir -p $OUTDIR/$ABI
  cp src/libluajit.a $OUTDIR/$ABI/
}

for ABI in armeabi-v7a arm64-v8a x86 x86_64; do
  build_arch $ABI
done

echo -e "\n✅ 全部 ABI 编译完成：LuaJIT/$OUTDIR/"

