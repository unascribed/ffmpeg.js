#!/bin/bash
browserify ffmpeg-worker.js > /usr/share/nginx/html/ffmpeg/ffmpeg-worker.js
gzip -kf9 /usr/share/nginx/html/ffmpeg/ffmpeg-worker.js
brotli -kfZ /usr/share/nginx/html/ffmpeg/ffmpeg-worker.js
