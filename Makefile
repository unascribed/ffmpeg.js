# Compile FFmpeg and all its dependencies to JavaScript.
# You need emsdk environment installed and activated, see:
# <https://kripken.github.io/emscripten-site/docs/getting_started/downloads.html>.

PRE_JS = build/pre.js
POST_JS_SYNC = build/post-sync.js
POST_JS_WORKER = build/post-worker.js

FILTERS = \
	aresample scale crop overlay rotate select volume \
	showwave showspectrum avectorscope mandelbrot
DEMUXERS = \
	matroska ogg avi mov flv mpegps image2 mp3 \
	concat rawvideo pcm_f32be pcm_f32le pcm_s16be \
	pcm_s16le gif
DECODERS = \
	libvpx_vp8 libvpx_vp9 theora mpeg2video mpeg4 h264 \
	hevc png mjpeg vorbis opus mp3 ac3 aac ass ssa srt \
	webvtt rawvideo pcm_f32be pcm_f32le pcm_s16be pcm_s16le \
	gif
MUXERS = \
	mp4 mp3 webm ogg image2 null pcm_f32be pcm_f32le \
	pcm_s16be pcm_s16le gif
ENCODERS = \
	libx264 libmp3lame aac libvpx_vp8 libvpx_vp9 libopus \
	mjpeg pcm_f32be pcm_f32le pcm_s16be pcm_s16le vorbis \
	gif

LIBASS_PC_PATH = ../freetype/dist/lib/pkgconfig:../fribidi/dist/lib/pkgconfig
LIBASS_DEPS = \
	build/fribidi/dist/lib/libfribidi.so \
	build/freetype/dist/lib/libfreetype.so


FFMPEG_BC = build/ffmpeg/ffmpeg.bc
FFMPEG_PC_PATH_ = \
	../x264/dist/lib/pkgconfig:\
	$(LIBASS_PC_PATH):\
	../libass/dist/lib/pkgconfig:\
	../opus/dist/lib/pkgconfig
FFMPEG_PC_PATH = $(subst : ,:,$(FFMPEG_PC_PATH_))
FFMPEG_SHARED_DEPS = \
	$(LIBASS_DEPS) \
	build/libass/dist/lib/libass.so \
	build/lame/dist/lib/libmp3lame.so \
	build/x264/dist/lib/libx264.so \
	build/opus/dist/lib/libopus.so \
	build/libvpx/dist/lib/libvpx.so

all: ffmpeg
ffmpeg: ffmpeg.js ffmpeg-worker.js

clean: clean-js \
	clean-freetype clean-fribidi clean-libass \
	clean-opus clean-libvpx clean-ffmpeg \
	clean-lame clean-x264
clean-js:
	rm -f -- ffmpeg*.js
clean-opus:
	-cd build/opus && rm -rf dist && make clean
clean-freetype:
	-cd build/freetype && rm -rf dist && make clean
clean-fribidi:
	-cd build/fribidi && rm -rf dist && make clean
clean-libass:
	-cd build/libass && rm -rf dist && make clean
clean-libvpx:
	-cd build/libvpx && rm -rf dist && make clean
clean-lame:
	-cd build/lame && rm -rf dist && make clean
clean-x264:
	-cd build/x264 && rm -rf dist && make clean
clean-ffmpeg:
	-cd build/ffmpeg && rm -f ffmpeg.bc && make clean

build/opus/configure:
	cd build/opus && ./autogen.sh

build/opus/dist/lib/libopus.so: build/opus/configure
	cd build/opus && \
	emconfigure ./configure \
		CFLAGS=-O3 \
		--prefix="$$(pwd)/dist" \
		--disable-static \
		--disable-doc \
		--disable-extra-programs \
		--disable-asm \
		--disable-rtcd \
		--disable-intrinsics \
		&& \
	emmake make -j12 && \
	emmake make install

build/freetype/builds/unix/configure:
	cd build/freetype && ./autogen.sh

# XXX(Kagami): host/build flags are used to enable cross-compiling
# (values must differ) but there should be some better way to achieve
# that: it probably isn't possible to build on x86 now.
build/freetype/dist/lib/libfreetype.so: build/freetype/builds/unix/configure
	cd build/freetype && \
	git reset --hard && \
	patch -p1 < ../freetype-asmjs.patch && \
	emconfigure ./configure \
		CFLAGS="-O3" \
		--prefix="$$(pwd)/dist" \
		--host=x86-none-linux \
		--build=x86_64 \
		--disable-static \
		\
		--without-zlib \
		--without-bzip2 \
		--without-png \
		--without-harfbuzz \
		&& \
	emmake make -j12 && \
	emmake make install

build/fribidi/configure:
	cd build/fribidi && ./bootstrap

build/fribidi/dist/lib/libfribidi.so: build/fribidi/configure
	cd build/fribidi && \
	git reset --hard && \
	patch -p1 < ../fribidi-make.patch && \
	emconfigure ./configure \
		CFLAGS=-O3 \
		NM=llvm-nm \
		--prefix="$$(pwd)/dist" \
		--disable-dependency-tracking \
		--disable-debug \
		--without-glib \
		&& \
	emmake make -j12 && \
	emmake make install

build/libass/configure:
	cd build/libass && ./autogen.sh

build/libass/dist/lib/libass.so: build/libass/configure $(LIBASS_DEPS)
	cd build/libass && \
	EM_PKG_CONFIG_PATH=$(LIBASS_PC_PATH) emconfigure ./configure \
		CFLAGS="-O3" \
		--prefix="$$(pwd)/dist" \
		--disable-static \
		--disable-enca \
		--disable-fontconfig \
		--disable-require-system-font-provider \
		--disable-harfbuzz \
		--disable-asm \
		&& \
	emmake make -j12 && \
	emmake make install

build/libvpx/dist/lib/libvpx.so:
	cd build/libvpx && \
	emconfigure ./configure \
		--prefix="$$(pwd)/dist" \
		--target=generic-gnu \
		--disable-dependency-tracking \
		--disable-multithread \
		--disable-runtime-cpu-detect \
		--enable-shared \
		--disable-static \
		\
		--disable-examples \
		--disable-docs \
		--disable-unit-tests \
		--disable-webm-io \
		--disable-libyuv \
		&& \
	emmake make -j12 && \
	emmake make install

build/lame/dist/lib/libmp3lame.so:
	cd build/lame && \
	git reset --hard && \
	patch -p1 < ../lame-configure.patch && \
	emconfigure ./configure \
		--prefix="$$(pwd)/dist" \
		--host=x86-none-linux \
		--disable-static \
		\
		--disable-gtktest \
		--disable-analyzer-hooks \
		--disable-decoder \
		--disable-frontend \
		&& \
	emmake make -j12 && \
	emmake make install

build/x264/dist/lib/libx264.so:
	cd build/x264 && \
	git reset --hard && \
	patch -p1 < ../x264-configure.patch && \
	emconfigure ./configure \
		--prefix="$$(pwd)/dist" \
		--extra-cflags="-Wno-unknown-warning-option" \
		--host=x86-none-linux \
		--disable-cli \
		--enable-shared \
		--disable-opencl \
		--disable-thread \
		--disable-asm \
		\
		--disable-avs \
		--disable-swscale \
		--disable-lavf \
		--disable-ffms \
		--disable-gpac \
		--disable-lsmash \
		&& \
	emmake make -j12 && \
	emmake make install

# TODO(Kagami): Emscripten documentation recommends to always use shared
# libraries but it's not possible in case of ffmpeg because it has
# multiple declarations of `ff_log2_tab` symbol. GCC builds FFmpeg fine
# though because it uses version scripts and so `ff_log2_tag` symbols
# are not exported to the shared libraries. Seems like `emcc` ignores
# them. We need to file bugreport to upstream. See also:
# - <https://kripken.github.io/emscripten-site/docs/compiling/Building-Projects.html>
# - <https://github.com/kripken/emscripten/issues/831>
# - <https://ffmpeg.org/pipermail/libav-user/2013-February/003698.html>
build/ffmpeg/ffmpeg.bc: $(FFMPEG_SHARED_DEPS)
	cd build/ffmpeg && \
	git reset --hard && \
	patch -p1 < ../ffmpeg-disable-arc4random.patch && \
	patch -p1 < ../ffmpeg-default-font.patch && \
	patch -p1 < ../ffmpeg-disable-monotonic.patch && \
	patch -p1 < ../ffmpeg-disable-lz.patch && \
	EM_PKG_CONFIG_PATH=$(FFMPEG_PC_PATH) emconfigure ./configure \
		--cc=emcc \
		--enable-cross-compile \
		--target-os=none \
		--arch=x86 \
		--disable-runtime-cpudetect \
		--disable-asm \
		--disable-fast-unaligned \
		--disable-pthreads \
		--disable-w32threads \
		--disable-os2threads \
		--disable-debug \
		--disable-stripping \
		\
		--disable-all \
		--enable-ffmpeg \
		--enable-avcodec \
		--enable-avformat \
		--enable-avutil \
		--enable-swresample \
		--enable-swscale \
		--enable-avfilter \
		--disable-network \
		--disable-d3d11va \
		--disable-dxva2 \
		--disable-vaapi \
		--disable-vda \
		--disable-vdpau \
		$(addprefix --enable-decoder=,$(DECODERS)) \
		$(addprefix --enable-demuxer=,$(DEMUXERS)) \
		--enable-protocol=file \
		$(addprefix --enable-filter=,$(FILTERS)) \
		--disable-bzlib \
		--disable-iconv \
		--disable-libxcb \
		--disable-lzma \
		--disable-sdl \
		--disable-securetransport \
		--disable-xlib \
		--enable-zlib \
		$(addprefix --enable-encoder=,$(ENCODERS)) \
		$(addprefix --enable-muxer=,$(MUXERS)) \
		--enable-gpl \
		--enable-filter=subtitles \
		--enable-libass \
		--enable-libmp3lame \
		--enable-libx264 \
		--enable-libopus \
		--enable-libvpx \
		--extra-cflags="-I../lame/dist/include -I../libvpx/dist/include -I/home/aesen/.emscripten_ports/zlib/zlib-version_1" \
		--extra-ldflags="-L../lame/dist/lib -L../libvpx/dist/lib" \
		&& \
	emmake make -j12 && \
	cp ffmpeg ffmpeg.bc

# Compile bitcode to JavaScript.
# NOTE(Kagami): Bump heap size to 64M, default 16M is not enough even
# for simple tests and 32M tends to run slower than 64M.
EMCC_COMMON_ARGS = \
	--closure 1 \
	-s TOTAL_MEMORY=67108864 \
	-s OUTLINING_LIMIT=20000 \
	-s USE_ZLIB=1 \
	-O3 --memory-init-file 0 \
	--pre-js $(PRE_JS) \
	-o $@

ffmpeg.js: $(FFMPEG_BC) $(PRE_JS) $(POST_JS_SYNC)
	emcc $(FFMPEG_BC) $(FFMPEG_SHARED_DEPS) \
		--post-js $(POST_JS_SYNC) \
		$(EMCC_COMMON_ARGS)

ffmpeg-worker.js: $(FFMPEG_BC) $(PRE_JS) $(POST_JS_WORKER)
	emcc $(FFMPEG_BC) $(FFMPEG_SHARED_DEPS) \
		--post-js $(POST_JS_WORKER) \
		$(EMCC_COMMON_ARGS)
